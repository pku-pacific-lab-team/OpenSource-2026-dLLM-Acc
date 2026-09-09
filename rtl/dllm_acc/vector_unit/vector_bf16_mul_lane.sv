//-----------------------------------------------------------------------------
// File: vector_bf16_mul_lane.sv
// Description: VLEN-wide BF16 element-wise multiplier lane for vector_unit.
//              Each element uses a configurable_mul_pe in BF16 mode for the
//              mantissa multiply (unsigned INT8x8 via 4x int4x4). These same
//              PEs are reused in PE array mode for INT4x4/INT4x8 MAC.
//
//              BF16 Multiply Algorithm (4-stage pipeline):
//                Stage 1: Unpack sign, exponent, 8-bit significand. Zero detect.
//                Stage 2: 4x int4x4_mul partial products (registered).
//                Stage 3: Shift-and-add of partial products + exponent sum.
//                Stage 4: Normalize and pack BF16 result.
//
//              Binary operation: vec_result = vec_op0 * vec_op1 (per-element).
//              No scalar result output.
//-----------------------------------------------------------------------------

module vector_bf16_mul_lane #(
    parameter integer VLEN       = 16,
    parameter integer ELEM_WIDTH = 16
) (
    input  logic                            clk_i,
    input  logic                            rst_ni,
    input  logic                            valid_i,
    input  logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_op0_i,
    input  logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_op1_i,
    output logic                            ready_o,
    output logic                            done_o,
    output logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_result_o,
    output logic                            vec_write_o,

    // PE array interface: expose PEs for INT mode reuse
    // When pe_array_mode_i != 2'b00, the PEs operate in INT mode and
    // BF16 mul lane outputs are invalid.
    input  logic        [     1:0]       pe_array_mode_i,
    input  logic        [VLEN-1:0][15:0] pe_array_wgt_i,
    input  logic        [VLEN-1:0][15:0] pe_array_act_i,
    input  logic                         pe_array_acc_clear_i,
    input  logic                         pe_array_acc_en_i,
    output logic signed [VLEN-1:0][15:0] pe_array_acc_o
);

    localparam integer EXP_WIDTH = 8;
    localparam integer FRAC_WIDTH = 7;
    localparam integer LATENCY = 4;

    logic       busy_q;
    logic [2:0] count_q;
    logic       en_pulse;
    logic       done_pulse;

    assign ready_o    = !busy_q;
    assign en_pulse   = valid_i && !busy_q;
    assign done_pulse = busy_q && (count_q == 3'(LATENCY - 1));

    // -------------------------------------------------------------------------
    // Lane control
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            busy_q  <= 1'b0;
            count_q <= '0;
        end else if (en_pulse) begin
            busy_q  <= 1'b1;
            count_q <= 3'd1;
        end else if (busy_q) begin
            if (count_q == 3'(LATENCY - 1)) begin
                busy_q  <= 1'b0;
                count_q <= '0;
            end else begin
                count_q <= count_q + 3'd1;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            done_o      <= 1'b0;
            vec_write_o <= 1'b0;
        end else begin
            done_o      <= done_pulse;
            vec_write_o <= done_pulse;
        end
    end

    // -------------------------------------------------------------------------
    // BF16 helper functions
    // -------------------------------------------------------------------------

    function automatic [EXP_WIDTH-1:0] bf16_exp(input logic [15:0] val);
        bf16_exp = (val[14:7] == 8'hFF) ? 8'hFE : val[14:7];
    endfunction

    function automatic logic bf16_is_zero(input logic [15:0] val);
        bf16_is_zero = (val[14:7] == 8'h00);
    endfunction

    function automatic [7:0] bf16_sig8(input logic [15:0] val);
        bf16_sig8 = (val[14:7] == 8'h00) ? 8'h00 : {1'b1, val[6:0]};
    endfunction

    // -------------------------------------------------------------------------
    // Pipeline registers
    // -------------------------------------------------------------------------

    // Stage 1 -> 2: unpack results
    logic [VLEN-1:0]                 s1_sign_q;
    logic [VLEN-1:0][ EXP_WIDTH-1:0] s1_exp_a_q;
    logic [VLEN-1:0][ EXP_WIDTH-1:0] s1_exp_b_q;
    logic [VLEN-1:0][           7:0] s1_sig_a_q;
    logic [VLEN-1:0][           7:0] s1_sig_b_q;
    logic [VLEN-1:0]                 s1_zero_q;

    // Stage 2 -> 3: partial products (from PE's 4x int4x4_mul, combinational)
    logic [VLEN-1:0]                 s2_sign_q;
    logic [VLEN-1:0][ EXP_WIDTH-1:0] s2_exp_a_q;
    logic [VLEN-1:0][ EXP_WIDTH-1:0] s2_exp_b_q;
    logic [VLEN-1:0][          15:0] s2_prod_q;  // captured bf16_prod_o
    logic [VLEN-1:0]                 s2_zero_q;

    // Stage 3 -> 4: recombined product + exponent sum
    logic [VLEN-1:0]                 s3_sign_q;
    logic [VLEN-1:0][ EXP_WIDTH+1:0] s3_exp_sum_q;  // 10-bit: distinguishes underflow (negative) from overflow (>=255)
    logic [VLEN-1:0][          15:0] s3_prod_q;
    logic [VLEN-1:0]                 s3_zero_q;

    // Stage 4: final output
    logic [VLEN-1:0][ELEM_WIDTH-1:0] s4_result_q;

    // Combinational PE output
    logic [VLEN-1:0][          15:0] pe_bf16_prod;

    genvar i;
    generate
        for (i = 0; i < VLEN; i = i + 1) begin : gen_mul_pe
            logic [ EXP_WIDTH+1:0] s4_norm_exp;  // 10-bit
            logic [FRAC_WIDTH-1:0] s4_norm_frac;
            logic [ELEM_WIDTH-1:0] s4_result_d;

            // ---- Configurable PE instance ----
            configurable_mul_pe i_pe (
                .clk_i       (clk_i),
                .rst_ni      (rst_ni),
                .mode_i      (pe_array_mode_i),
                .bf16_a_sig_i(s1_sig_a_q[i]),
                .bf16_b_sig_i(s1_sig_b_q[i]),
                .int_wgt_i   (pe_array_wgt_i[i]),
                .int_act_i   (pe_array_act_i[i]),
                .acc_clear_i (pe_array_acc_clear_i),
                .acc_en_i    (pe_array_acc_en_i),
                .bf16_prod_o (pe_bf16_prod[i]),
                .acc_o       (pe_array_acc_o[i])
            );

            // ---- Stage 1: Unpack BF16 operands ----
            always_ff @(posedge clk_i) begin
                if (en_pulse) begin
                    s1_sign_q[i]  <= vec_op0_i[i][15] ^ vec_op1_i[i][15];
                    s1_exp_a_q[i] <= bf16_exp(vec_op0_i[i]);
                    s1_exp_b_q[i] <= bf16_exp(vec_op1_i[i]);
                    s1_sig_a_q[i] <= bf16_sig8(vec_op0_i[i]);
                    s1_sig_b_q[i] <= bf16_sig8(vec_op1_i[i]);
                    s1_zero_q[i]  <= bf16_is_zero(vec_op0_i[i]) || bf16_is_zero(vec_op1_i[i]);
                end
            end

            // ---- Stage 2: Register partial products from PE ----
            // PE's bf16_prod_o is combinational from s1_sig registers through
            // 4x int4x4_mul + input mux. This stage registers those results,
            // isolating the multiply from the shift-and-add.
            always_ff @(posedge clk_i) begin
                s2_sign_q[i]  <= s1_sign_q[i];
                s2_exp_a_q[i] <= s1_exp_a_q[i];
                s2_exp_b_q[i] <= s1_exp_b_q[i];
                s2_prod_q[i]  <= pe_bf16_prod[i];
                s2_zero_q[i]  <= s1_zero_q[i];
            end

            // ---- Stage 3: Exponent sum (shift-and-add already done in PE) ----
            // The PE already combines the 4 partial products into bf16_prod_o
            // via shift-and-add (combinational). Stage 2 registered that result.
            // This stage computes the exponent sum.
            always_ff @(posedge clk_i) begin
                s3_sign_q[i]    <= s2_sign_q[i];
                s3_exp_sum_q[i] <= {2'b0, s2_exp_a_q[i]} + {2'b0, s2_exp_b_q[i]} - 10'd127;
                s3_prod_q[i]    <= s2_prod_q[i];
                s3_zero_q[i]    <= s2_zero_q[i];
            end

            // ---- Stage 4: Normalize and pack ----
            always_ff @(posedge clk_i) begin
                s4_result_q[i] <= s4_result_d;
            end

            always_comb begin
                s4_norm_exp  = s3_exp_sum_q[i];
                s4_norm_frac = s3_prod_q[i][13:7];
                s4_result_d  = '0;

                if (!s3_zero_q[i]) begin
                    // sig_a and sig_b both have implicit leading 1 at bit 7.
                    // Product range: [0x4000, 0xFE01]. Bit 15 indicates whether
                    // the product needs a 1-bit right shift (exponent increment).
                    if (s3_prod_q[i][15]) begin
                        s4_norm_exp  = s3_exp_sum_q[i] + 10'd1;
                        s4_norm_frac = s3_prod_q[i][14:8];
                    end

                    if (s4_norm_exp[9] || s4_norm_exp == 10'd0) begin
                        // Underflow (negative exponent or zero) -> flush to zero
                        s4_result_d = '0;
                    end else if (s4_norm_exp >= 10'd255) begin
                        // Overflow -> saturate to max finite
                        s4_result_d = {s3_sign_q[i], 8'hFE, 7'h7F};
                    end else begin
                        s4_result_d = {s3_sign_q[i], s4_norm_exp[EXP_WIDTH-1:0], s4_norm_frac};
                    end
                end
            end
        end
    endgenerate

    assign vec_result_o = s4_result_q;

endmodule
