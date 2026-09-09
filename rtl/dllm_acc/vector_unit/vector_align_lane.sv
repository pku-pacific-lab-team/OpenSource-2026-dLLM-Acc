//-----------------------------------------------------------------------------
// File: vector_align_lane.sv
// Date Created: 2026-03-19
// Description: Exponent alignment lane for vector unit.
//-----------------------------------------------------------------------------
module vector_align_lane #(
    parameter integer VLEN         = 16,
    parameter integer ELEM_WIDTH   = 16,
    parameter integer SCALAR_WIDTH = 32
) (
    input  logic                                    clk_i,
    input  logic                                    rst_ni,
    input  logic                                    valid_i,
    input  logic [        VLEN-1:0][ELEM_WIDTH-1:0] vec_op_i,
    output logic                                    ready_o,
    output logic                                    done_o,
    output logic [        VLEN-1:0][ELEM_WIDTH-1:0] vec_result_o,
    output logic                                    vec_write_o,
    output logic [SCALAR_WIDTH-1:0]                 scalar_result_o,
    output logic                                    scalar_write_o
);

    typedef enum logic [1:0] {
        ALIGN_IDLE,
        ALIGN_WAIT_STAGE1,
        ALIGN_DONE
    } align_state_t;

    align_state_t align_state_d, align_state_q;
    logic accept_req;

    logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_stage1_d, vec_stage1_q;
    logic [7:0] max_exp_stage1_d, max_exp_stage1_q;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_result_d, vec_result_q;
    logic [SCALAR_WIDTH-1:0] scalar_result_d, scalar_result_q;
    integer stage1_elem_idx;
    integer stage2_elem_idx;

    assign accept_req = valid_i && ready_o;

    function automatic logic [ELEM_WIDTH-1:0] aligned_mantissa(input logic [ELEM_WIDTH-1:0] value_i, input logic [7:0] target_exp_i);
        logic        sign_bit;
        logic [ 7:0] exp_bits;
        logic [ 6:0] frac_bits;
        logic [15:0] mantissa_mag;
        logic [ 7:0] exp_diff;
        logic [15:0] aligned_mag;
        begin
            sign_bit  = value_i[15];
            exp_bits  = value_i[14:7];
            frac_bits = value_i[6:0];

            if (exp_bits == '0) begin
                aligned_mantissa = '0;
            end else begin
                mantissa_mag = {1'b1, frac_bits, 8'b0};
                exp_diff     = target_exp_i - exp_bits;
                if (exp_diff >= 8'(ELEM_WIDTH)) begin
                    aligned_mag = '0;
                end else begin
                    aligned_mag = mantissa_mag >> exp_diff;
                end

                if (aligned_mag == '0) begin
                    aligned_mantissa = '0;
                end else if (sign_bit) begin
                    aligned_mantissa = ELEM_WIDTH'($unsigned(-signed'(aligned_mag)));
                end else begin
                    aligned_mantissa = aligned_mag;
                end
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // Stage 1 capture
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i) begin
        vec_stage1_q     <= vec_stage1_d;
        max_exp_stage1_q <= max_exp_stage1_d;
    end

    always_comb begin
        vec_stage1_d     = vec_stage1_q;
        max_exp_stage1_d = max_exp_stage1_q;

        if (accept_req) begin
            vec_stage1_d     = vec_op_i;
            max_exp_stage1_d = '0;
            for (stage1_elem_idx = 0; stage1_elem_idx < VLEN; stage1_elem_idx = stage1_elem_idx + 1) begin
                if (vec_op_i[stage1_elem_idx][14:7] > max_exp_stage1_d) begin
                    max_exp_stage1_d = vec_op_i[stage1_elem_idx][14:7];
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2 alignment and result packaging
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i) begin
        vec_result_q    <= vec_result_d;
        scalar_result_q <= scalar_result_d;
    end

    always_comb begin
        vec_result_d    = vec_result_q;
        scalar_result_d = scalar_result_q;

        if (align_state_q == ALIGN_WAIT_STAGE1) begin
            scalar_result_d = {{SCALAR_WIDTH - 8{1'b0}}, max_exp_stage1_q};
            for (stage2_elem_idx = 0; stage2_elem_idx < VLEN; stage2_elem_idx = stage2_elem_idx + 1) begin
                vec_result_d[stage2_elem_idx] = aligned_mantissa(vec_stage1_q[stage2_elem_idx], max_exp_stage1_q);
            end
        end
    end

    // -------------------------------------------------------------------------
    // Lane control
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            align_state_q <= ALIGN_IDLE;
        end else begin
            align_state_q <= align_state_d;
        end
    end

    always_comb begin
        align_state_d = align_state_q;

        case (align_state_q)
            ALIGN_IDLE: begin
                if (accept_req) begin
                    align_state_d = ALIGN_WAIT_STAGE1;
                end
            end
            ALIGN_WAIT_STAGE1: begin
                align_state_d = ALIGN_DONE;
            end
            ALIGN_DONE: begin
                align_state_d = ALIGN_IDLE;
            end
            default: begin
                align_state_d = ALIGN_IDLE;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------

    assign ready_o         = (align_state_q == ALIGN_IDLE);
    assign done_o          = (align_state_q == ALIGN_DONE);
    assign vec_result_o    = vec_result_q;
    assign vec_write_o     = done_o;
    assign scalar_result_o = scalar_result_q;
    assign scalar_write_o  = done_o;
endmodule
