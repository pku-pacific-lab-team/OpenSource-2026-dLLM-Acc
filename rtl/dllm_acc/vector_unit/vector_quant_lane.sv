//-----------------------------------------------------------------------------
// File: vector_quant_lane.sv
// Date Created: 2026-04-04
// Description: Quantization lane for vector unit. Implements shared-scale
//              BF16-to-INT4/INT8 quantization and per-element top-k tracking.
//-----------------------------------------------------------------------------

module vector_quant_lane #(
    parameter integer VLEN         = 16,
    parameter integer ELEM_WIDTH   = 16,
    parameter integer FUNC_WIDTH   = 9,
    parameter integer SCALAR_WIDTH = 32
) (
    input logic clk_i,
    input logic rst_ni,

    // Lane contract
    input  logic valid_i,
    output logic ready_o,
    output logic done_o,

    // Operands
    input logic [      VLEN-1:0][ELEM_WIDTH-1:0] vec_op_i,
    input logic [FUNC_WIDTH-1:0]                 func_i,

    // Result
    output logic [        VLEN-1:0][ELEM_WIDTH-1:0] vec_result_o,
    output logic                                    vec_write_o,
    output logic [SCALAR_WIDTH-1:0]                 scalar_result_o,
    output logic                                    scalar_write_o
);

    // func bit encoding
    // func_i[0]: format -- 0 = INT4, 1 = INT8
    // func_i[1]: top-k feed enable -- 0 = disabled, 1 = enabled
    // func_i[2]: top-k readout / clear mode (standalone, no quantization)
    // func_i[3]: top-k period-end trigger (standalone, no quantization)

    typedef enum logic [3:0] {
        QUANT_IDLE,
        QUANT_MAX1,
        QUANT_MAX2,
        QUANT_SCALE,
        QUANT_EXEC,
        QUANT_TOPK_FEED,
        QUANT_READOUT,
        QUANT_READOUT_WAIT,
        QUANT_READOUT_CAP,
        QUANT_CLEAR,
        QUANT_CHECK,
        QUANT_CHECK_WAIT,
        QUANT_DONE
    } quant_state_t;

    localparam integer RECIP_GAIN_FRAC_BITS = 8;
    localparam integer RECIP_GAIN_WIDTH = 8;
    localparam integer TOPK_WAIT_CYCLES = 5;

    quant_state_t state_d, state_q;

    logic                                          accept_req;
    logic                                          quant_mode;
    logic                                          topk_feed_en;
    logic                                          topk_check_en;
    logic                                          int8_fmt;
    logic                                          quant_mode_q;
    logic                                          topk_feed_en_q;
    logic                                          topk_check_en_q;
    logic                                          int8_fmt_q;
    logic                                          topk_vld;
    logic                                          topk_rd_en;
    logic                                          topk_clear;
    logic                                          topk_period_end;
    logic   [                 2:0]                 topk_check_cnt_q;
    logic   [            VLEN-1:0][ELEM_WIDTH-1:0] vec_req_q;
    logic   [            VLEN-1:0][ELEM_WIDTH-1:0] vec_result_d;
    logic   [            VLEN-1:0][ELEM_WIDTH-1:0] vec_result_q;
    logic   [    SCALAR_WIDTH-1:0]                 scalar_result_d;
    logic   [    SCALAR_WIDTH-1:0]                 scalar_result_q;
    logic   [      ELEM_WIDTH-1:0]                 quant_max_abs_d;
    logic   [      ELEM_WIDTH-1:0]                 quant_max_abs_q;
    logic   [      ELEM_WIDTH-1:0]                 quant_scale_d;
    logic   [      ELEM_WIDTH-1:0]                 quant_scale_q;
    logic   [RECIP_GAIN_WIDTH-1:0]                 quant_gain_d;
    logic   [RECIP_GAIN_WIDTH-1:0]                 quant_gain_q;
    logic   [            VLEN-1:0][ELEM_WIDTH-1:0] quant_vec_exec;
    logic   [            VLEN-1:0][           3:0] topk_input;
    logic   [                 3:0]                 topk_ac_out                              [VLEN-1:0] [3:0];
    logic                                          topk_vld_out                             [VLEN-1:0];

    // Max-abs reduction tree signals
    logic   [            VLEN-1:0][ELEM_WIDTH-1:0] max_tree_l0;  // level 0: abs + NaN clamp
    logic   [          VLEN/2-1:0][ELEM_WIDTH-1:0] max_tree_l1;  // level 1: 16 -> 8
    logic   [          VLEN/4-1:0][ELEM_WIDTH-1:0] max_tree_l2;  // level 2: 8 -> 4
    logic   [          VLEN/4-1:0][ELEM_WIDTH-1:0] max_tree_l2_q;  // level 2: registered
    logic   [          VLEN/8-1:0][ELEM_WIDTH-1:0] max_tree_l3;  // level 3: 4 -> 2

    integer                                        max_tree_iter;
    integer                                        quant_elem_iter;
    integer                                        topk_input_iter;
    integer                                        topk_pack_iter;
    genvar topk_inst_iter;

    // -------------------------------------------------------------------------
    // Request decode
    // -------------------------------------------------------------------------

    assign accept_req   = valid_i && ready_o;
    assign quant_mode   = !func_i[2] && !func_i[3];
    assign topk_feed_en = quant_mode && func_i[1];
    assign topk_check_en = func_i[3];
    assign int8_fmt     = func_i[0];

    function automatic logic [7:0] bf16_exp_clamped(input logic [ELEM_WIDTH-1:0] value_i);
        begin
            if (value_i[14:7] == 8'hff) begin
                bf16_exp_clamped = 8'hfe;
            end else begin
                bf16_exp_clamped = value_i[14:7];
            end
        end
    endfunction

    function automatic logic bf16_is_zeroish(input logic [ELEM_WIDTH-1:0] value_i);
        begin
            bf16_is_zeroish = (value_i[14:7] == 8'h00);
        end
    endfunction

    function automatic logic [7:0] bf16_sig8(input logic [ELEM_WIDTH-1:0] value_i);
        begin
            if (bf16_is_zeroish(value_i)) begin
                bf16_sig8 = '0;
            end else begin
                bf16_sig8 = {1'b1, value_i[6:0]};
            end
        end
    endfunction

    function automatic logic [ELEM_WIDTH-1:0] bf16_abs_bits(input logic [ELEM_WIDTH-1:0] value_i);
        begin
            bf16_abs_bits = {1'b0, value_i[14:0]};
        end
    endfunction

    function automatic integer lead_one_idx16(input logic [15:0] value_i);
        integer idx;
        begin
            lead_one_idx16 = -1;
            for (idx = 15; idx >= 0; idx = idx - 1) begin
                if (value_i[idx]) begin
                    lead_one_idx16 = idx;
                    break;
                end
            end
        end
    endfunction

    function automatic logic [ELEM_WIDTH-1:0] quant_scale_from_max_abs(input logic [ELEM_WIDTH-1:0] max_abs_i, input logic int8_fmt_i);
        logic   [ 7:0] qmax;
        integer        lead_idx;
        integer        exp_out;
        logic   [ 7:0] max_exp;
        logic   [ 7:0] max_sig;
        logic   [15:0] div_q;
        logic   [ 7:0] sig_norm;
        begin
            if (bf16_is_zeroish(max_abs_i)) begin
                quant_scale_from_max_abs = '0;
            end else begin
                qmax    = int8_fmt_i ? 127 : 7;
                max_exp = bf16_exp_clamped(max_abs_i);
                max_sig = bf16_sig8(max_abs_i);
                div_q   = ((16'(max_sig) << 7) + (16'(qmax) >> 1)) / 16'(qmax);

                if (div_q == '0) begin
                    quant_scale_from_max_abs = '0;
                end else begin
                    lead_idx = lead_one_idx16(div_q);
                    exp_out  = int'(max_exp) + lead_idx - 14;

                    if (lead_idx > 7) begin
                        sig_norm = 8'(div_q >> (lead_idx - 7));
                    end else begin
                        sig_norm = 8'(div_q << (7 - lead_idx));
                    end

                    if (exp_out <= 0) begin
                        quant_scale_from_max_abs = '0;
                    end else if (exp_out >= 8'hff) begin
                        quant_scale_from_max_abs = {1'b0, 8'hfe, 7'h7f};
                    end else begin
                        quant_scale_from_max_abs = {1'b0, 8'(exp_out), sig_norm[6:0]};
                    end
                end
            end
        end
    endfunction

    function automatic logic [RECIP_GAIN_WIDTH-1:0] quant_gain_from_max_abs(input logic [ELEM_WIDTH-1:0] max_abs_i, input logic int8_fmt_i);
        logic [                 7:0] qmax;
        logic [                 7:0] max_sig;
        logic [RECIP_GAIN_WIDTH-1:0] gain_q;
        begin
            if (bf16_is_zeroish(max_abs_i)) begin
                quant_gain_from_max_abs = '0;
            end else begin
                qmax                    = int8_fmt_i ? 127 : 7;
                max_sig                 = bf16_sig8(max_abs_i);
                gain_q                  = RECIP_GAIN_WIDTH'(((16'(qmax) << RECIP_GAIN_FRAC_BITS) + (16'(max_sig) >> 1)) / 16'(max_sig));
                quant_gain_from_max_abs = gain_q;
            end
        end
    endfunction

    function automatic logic [ELEM_WIDTH-1:0] quantize_elem(input logic [ELEM_WIDTH-1:0] value_i, input logic [ELEM_WIDTH-1:0] max_abs_i,
                                                            input logic [RECIP_GAIN_WIDTH-1:0] gain_q_i, input logic int8_fmt_i);
        logic        [           7:0] qmax;
        integer                       shift_amt;
        integer                       total_shift;
        logic                         value_sign;
        logic        [ELEM_WIDTH-1:0] value_abs;
        logic        [           7:0] value_exp;
        logic        [           7:0] max_exp;
        logic        [           7:0] value_sig;
        logic        [          31:0] scaled_product;
        logic        [          31:0] rounded_product;
        logic        [          15:0] magnitude;
        logic signed [ELEM_WIDTH-1:0] signed_code;
        begin
            value_sign = value_i[15];
            value_abs  = bf16_abs_bits(value_i);

            if (bf16_is_zeroish(value_abs) || bf16_is_zeroish(max_abs_i) || (gain_q_i == '0)) begin
                quantize_elem = '0;
            end else begin
                qmax      = int8_fmt_i ? 127 : 7;
                value_exp = bf16_exp_clamped(value_abs);
                max_exp   = bf16_exp_clamped(max_abs_i);
                value_sig = bf16_sig8(value_abs);
                shift_amt = int'(max_exp) - int'(value_exp);
                if (shift_amt < 0) begin
                    shift_amt = 0;
                end

                if (shift_amt >= 24) begin
                    magnitude = '0;
                end else begin
                    scaled_product = 32'(16'(value_sig) * 16'(gain_q_i));
                    total_shift    = RECIP_GAIN_FRAC_BITS + shift_amt;
                    if (total_shift >= 31) begin
                        magnitude = '0;
                    end else if (total_shift == 0) begin
                        magnitude = 16'(scaled_product);
                    end else begin
                        rounded_product = scaled_product + (32'd1 << (total_shift - 1));
                        magnitude       = 16'(rounded_product >> total_shift);
                    end
                end

                if (magnitude > 16'(qmax)) begin
                    magnitude = 16'(qmax);
                end

                if (magnitude == '0) begin
                    quantize_elem = '0;
                end else begin
                    if (value_sign) begin
                        signed_code = -$signed(ELEM_WIDTH'(magnitude));
                    end else begin
                        signed_code = $signed(ELEM_WIDTH'(magnitude));
                    end
                    quantize_elem = ELEM_WIDTH'($unsigned(signed_code));
                end
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // Lane control
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q          <= QUANT_IDLE;
            quant_mode_q     <= 1'b0;
            topk_feed_en_q   <= 1'b0;
            topk_check_en_q  <= 1'b0;
            int8_fmt_q       <= 1'b0;
            vec_req_q        <= '0;
            max_tree_l2_q    <= '0;
            quant_max_abs_q  <= '0;
            quant_scale_q    <= '0;
            quant_gain_q     <= '0;
            topk_check_cnt_q <= '0;
        end else begin
            state_q <= state_d;

            if (state_q == QUANT_CHECK_WAIT || state_q == QUANT_READOUT_WAIT)
                topk_check_cnt_q <= topk_check_cnt_q + 3'd1;
            else
                topk_check_cnt_q <= '0;

            if (accept_req) begin
                vec_req_q       <= vec_op_i;
                quant_mode_q    <= quant_mode;
                topk_feed_en_q  <= topk_feed_en;
                topk_check_en_q <= topk_check_en;
                int8_fmt_q      <= int8_fmt;
            end

            if (state_q == QUANT_MAX1) begin
                max_tree_l2_q <= max_tree_l2;
            end

            if (state_q == QUANT_MAX2) begin
                quant_max_abs_q <= quant_max_abs_d;
            end

            if (state_q == QUANT_SCALE) begin
                quant_scale_q <= quant_scale_d;
                quant_gain_q  <= quant_gain_d;
            end
        end
    end

    always_comb begin
        state_d         = state_q;
        topk_vld        = 1'b0;
        topk_rd_en      = 1'b0;
        topk_clear       = 1'b0;
        topk_period_end = 1'b0;

        case (state_q)
            QUANT_IDLE: begin
                if (accept_req) begin
                    if (topk_check_en) begin
                        state_d = QUANT_CHECK;
                    end else if (quant_mode) begin
                        state_d = QUANT_MAX1;
                    end else begin
                        state_d = QUANT_READOUT;
                    end
                end
            end

            QUANT_MAX1: begin
                state_d = QUANT_MAX2;
            end

            QUANT_MAX2: begin
                state_d = QUANT_SCALE;
            end

            QUANT_SCALE: begin
                state_d = QUANT_EXEC;
            end

            QUANT_EXEC: begin
                state_d = topk_feed_en_q ? QUANT_TOPK_FEED : QUANT_DONE;
            end

            QUANT_TOPK_FEED: begin
                // Pipeline stage: ingest from registered vec_result_q to break the quantize_elem -> topk_HIT setup path.
                topk_vld = 1'b1;
                state_d  = QUANT_DONE;
            end

            QUANT_READOUT: begin
                topk_period_end = 1'b1;
                topk_rd_en      = 1'b1;
                state_d         = QUANT_READOUT_WAIT;
            end

            QUANT_READOUT_WAIT: begin
                topk_period_end = 1'b1;
                topk_rd_en      = 1'b1;
                if (topk_check_cnt_q == TOPK_WAIT_CYCLES[2:0]) begin
                    state_d = QUANT_READOUT_CAP;
                end
            end

            QUANT_READOUT_CAP: begin
                topk_period_end = 1'b1;
                topk_rd_en      = 1'b1;
                state_d         = QUANT_CLEAR;
            end

            QUANT_CLEAR: begin
                topk_clear = 1'b1;
                state_d    = QUANT_DONE;
            end

            QUANT_CHECK: begin
                topk_period_end = 1'b1;
                state_d         = QUANT_CHECK_WAIT;
            end

            QUANT_CHECK_WAIT: begin
                topk_period_end = 1'b1;
                if (topk_check_cnt_q == TOPK_WAIT_CYCLES[2:0]) begin
                    state_d = QUANT_DONE;
                end
            end

            QUANT_DONE: begin
                state_d = QUANT_IDLE;
            end

            default: begin
                state_d = QUANT_IDLE;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Quantization and readout result state
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i) begin
        vec_result_q    <= vec_result_d;
        scalar_result_q <= scalar_result_d;
    end

    // -------------------------------------------------------------------------
    // Max-abs reduction tree (explicit pipelined structure)
    // -------------------------------------------------------------------------

    always_comb begin
        // Level 0: absolute value + NaN-clamp (parallel, all 16 elements)
        for (max_tree_iter = 0; max_tree_iter < VLEN; max_tree_iter = max_tree_iter + 1) begin
            max_tree_l0[max_tree_iter][15]   = 1'b0;
            max_tree_l0[max_tree_iter][14:7] = (vec_req_q[max_tree_iter][14:7] == 8'hFF) ? 8'hFE : vec_req_q[max_tree_iter][14:7];
            max_tree_l0[max_tree_iter][6:0]  = vec_req_q[max_tree_iter][6:0];
        end

        // Level 1: 16 -> 8 pairwise unsigned max
        for (max_tree_iter = 0; max_tree_iter < VLEN / 2; max_tree_iter = max_tree_iter + 1) begin
            max_tree_l1[max_tree_iter] = (max_tree_l0[2*max_tree_iter] > max_tree_l0[2*max_tree_iter+1]) ? max_tree_l0[2*max_tree_iter] : max_tree_l0[2*max_tree_iter+1];
        end

        // Level 2: 8 -> 4 pairwise unsigned max
        for (max_tree_iter = 0; max_tree_iter < VLEN / 4; max_tree_iter = max_tree_iter + 1) begin
            max_tree_l2[max_tree_iter] = (max_tree_l1[2*max_tree_iter] > max_tree_l1[2*max_tree_iter+1]) ? max_tree_l1[2*max_tree_iter] : max_tree_l1[2*max_tree_iter+1];
        end

        // --- Pipeline register boundary (max_tree_l2 -> max_tree_l2_q) ---

        // Level 3: 4 -> 2 pairwise unsigned max (from registered l2)
        for (max_tree_iter = 0; max_tree_iter < VLEN / 8; max_tree_iter = max_tree_iter + 1) begin
            max_tree_l3[max_tree_iter] = (max_tree_l2_q[2*max_tree_iter] > max_tree_l2_q[2*max_tree_iter+1]) ? max_tree_l2_q[2*max_tree_iter] : max_tree_l2_q[2*max_tree_iter+1];
        end

        // Level 4: 2 -> 1 final max
        quant_max_abs_d = (max_tree_l3[0] > max_tree_l3[1]) ? max_tree_l3[0] : max_tree_l3[1];
    end

    always_comb begin
        quant_scale_d   = quant_scale_from_max_abs(quant_max_abs_q, int8_fmt_q);
        quant_gain_d    = quant_gain_from_max_abs(quant_max_abs_q, int8_fmt_q);
        quant_vec_exec  = '0;
        vec_result_d    = vec_result_q;
        scalar_result_d = scalar_result_q;

        if (state_q == QUANT_EXEC) begin
            scalar_result_d = {{SCALAR_WIDTH - ELEM_WIDTH{1'b0}}, quant_scale_q};
            for (quant_elem_iter = 0; quant_elem_iter < VLEN; quant_elem_iter = quant_elem_iter + 1) begin
                quant_vec_exec[quant_elem_iter] = quantize_elem(vec_req_q[quant_elem_iter], quant_max_abs_q, quant_gain_q, int8_fmt_q);
                vec_result_d[quant_elem_iter]   = quant_vec_exec[quant_elem_iter];
            end
        end

        if (state_q == QUANT_READOUT_CAP) begin
            scalar_result_d = '0;
            for (topk_pack_iter = 0; topk_pack_iter < VLEN; topk_pack_iter = topk_pack_iter + 1) begin
                vec_result_d[topk_pack_iter] = {
                    topk_ac_out[topk_pack_iter][3], topk_ac_out[topk_pack_iter][2], topk_ac_out[topk_pack_iter][1], topk_ac_out[topk_pack_iter][0]
                };
            end
        end
    end

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------

    assign ready_o         = (state_q == QUANT_IDLE);
    assign done_o          = (state_q == QUANT_DONE);
    assign vec_write_o     = done_o && !topk_check_en_q;
    assign scalar_write_o  = done_o && quant_mode_q;
    assign vec_result_o    = vec_result_q;
    assign scalar_result_o = scalar_result_q;

    // -------------------------------------------------------------------------
    // Per-element top-k tracker array
    // -------------------------------------------------------------------------

    always_comb begin
        topk_input = '0;
        for (topk_input_iter = 0; topk_input_iter < VLEN; topk_input_iter = topk_input_iter + 1) begin
            if (int8_fmt_q) begin
                topk_input[topk_input_iter] = vec_result_q[topk_input_iter][7:4];
            end else begin
                topk_input[topk_input_iter] = vec_result_q[topk_input_iter][3:0];
            end
        end
    end

    generate
        for (topk_inst_iter = 0; topk_inst_iter < VLEN; topk_inst_iter = topk_inst_iter + 1) begin : gen_topk
            topk_wrapper i_topk_wrapper (
                .rst_n       (rst_ni),
                .clk         (clk_i),
                .A_i         (topk_input[topk_inst_iter]),
                .clear_i     (topk_clear),
                .vld_in_i    (topk_vld),
                .period_end_i(topk_period_end),
                .rd_en_i     (topk_rd_en),
                .AC_out_o    (topk_ac_out[topk_inst_iter]),
                .vld_out_o   (topk_vld_out[topk_inst_iter])
            );
        end
    endgenerate

endmodule

