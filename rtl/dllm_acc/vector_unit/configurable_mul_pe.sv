//-----------------------------------------------------------------------------
// File: configurable_mul_pe.sv
// Description: Mode-switchable processing element containing exactly 4
//              int4x4_mul instances. Mode-dependent input muxing and output
//              combination reconfigures the same 4 multipliers for:
//
//              BF16_MUL  (mode=2'b00): unsigned INT8xINT8 mantissa multiply
//                4 unsigned 4x4 partial products + shift-and-add:
//                prod = a_hi*b_hi*256 + (a_hi*b_lo + a_lo*b_hi)*16 + a_lo*b_lo
//
//              INT4x8    (mode=2'b01): 2x signed INT4(wgt) x INT8(act) MAC
//                Multipliers paired as {mul0,mul1} and {mul2,mul3}.
//                Each pair: wgt * act_hi * 16 + wgt * act_lo + correction
//
//              INT4x4    (mode=2'b10): 4x signed INT4(wgt) x INT4(act) MAC
//                4 independent signed 4x4 products, summed into accumulator.
//
//              16-bit signed accumulator for INT modes.
//-----------------------------------------------------------------------------

module configurable_mul_pe (
    input logic clk_i,
    input logic rst_ni,

    input logic [1:0] mode_i,  // 00=BF16, 01=INT4x8, 10=INT4x4

    // BF16 mode inputs (unsigned 8-bit significands)
    input logic [7:0] bf16_a_sig_i,
    input logic [7:0] bf16_b_sig_i,

    // INT mode inputs (packed)
    input logic [15:0] int_wgt_i,  // packed INT4 weights
    input logic [15:0] int_act_i,  // packed INT4 or INT8 activations

    input logic acc_clear_i,
    input logic acc_en_i,

    output logic        [15:0] bf16_prod_o,
    output logic signed [15:0] acc_o
);

    logic        [ 3:0][ 3:0] mul_a;
    logic        [ 3:0][ 3:0] mul_b;
    logic        [ 3:0]       mul_unsigned_mode;
    logic        [ 3:0][ 7:0] mul_prod;

    logic signed [15:0]       int4x4_sum;
    logic        [ 1:0][15:0] int4x8_pair;
    logic signed [11:0]       pair0_correction;
    logic signed [11:0]       pair1_correction;
    logic signed [15:0]       int4x8_sum;
    logic signed [15:0] acc_d, acc_q;
    logic signed [15:0] mac_result;

    // -------------------------------------------------------------------------
    // The 4 physical multipliers
    // -------------------------------------------------------------------------

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_mul
            int4x4_mul i_mul (
                .a_i            (mul_a[i]),
                .b_i            (mul_b[i]),
                .unsigned_mode_i(mul_unsigned_mode[i]),
                .prod_o         (mul_prod[i])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Input muxing
    // -------------------------------------------------------------------------

    always_comb begin
        mul_a             = '0;
        mul_b             = '0;
        mul_unsigned_mode = '0;

        case (mode_i)
            2'b00: begin
                // BF16: unsigned 8x8 decomposed into 4 unsigned 4x4.
                mul_a[0]          = bf16_a_sig_i[7:4];
                mul_b[0]          = bf16_b_sig_i[7:4];
                mul_a[1]          = bf16_a_sig_i[7:4];
                mul_b[1]          = bf16_b_sig_i[3:0];
                mul_a[2]          = bf16_a_sig_i[3:0];
                mul_b[2]          = bf16_b_sig_i[7:4];
                mul_a[3]          = bf16_a_sig_i[3:0];
                mul_b[3]          = bf16_b_sig_i[3:0];
                mul_unsigned_mode = '1;
            end
            2'b01: begin
                // INT4x8: two signed INT4 x INT8 pairs.
                mul_a[0] = int_wgt_i[3:0];
                mul_b[0] = int_act_i[7:4];
                mul_a[1] = int_wgt_i[3:0];
                mul_b[1] = int_act_i[3:0];
                mul_a[2] = int_wgt_i[7:4];
                mul_b[2] = int_act_i[15:12];
                mul_a[3] = int_wgt_i[7:4];
                mul_b[3] = int_act_i[11:8];
            end
            default: begin
                // INT4x4: four independent signed INT4 x INT4 products.
                mul_a[0] = int_wgt_i[3:0];
                mul_b[0] = int_act_i[3:0];
                mul_a[1] = int_wgt_i[7:4];
                mul_b[1] = int_act_i[7:4];
                mul_a[2] = int_wgt_i[11:8];
                mul_b[2] = int_act_i[11:8];
                mul_a[3] = int_wgt_i[15:12];
                mul_b[3] = int_act_i[15:12];
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Output combination
    // -------------------------------------------------------------------------

    always_comb begin
        bf16_prod_o      = '0;
        int4x4_sum       = '0;
        int4x8_pair      = '0;
        pair0_correction = '0;
        pair1_correction = '0;
        int4x8_sum       = '0;

        // BF16: pp_hh*256 + (pp_hl + pp_lh)*16 + pp_ll
        bf16_prod_o      = {mul_prod[0], 8'b0} + {4'b0, mul_prod[1], 4'b0} + {4'b0, mul_prod[2], 4'b0} + {8'b0, mul_prod[3]};

        int4x4_sum       = 16'($signed(mul_prod[0])) + 16'($signed(mul_prod[1])) + 16'($signed(mul_prod[2])) + 16'($signed(mul_prod[3]));

        pair0_correction = int_act_i[3] ? (12'($signed(int_wgt_i[3:0])) <<< 4) : 12'sd0;
        int4x8_pair[0]   = 16'((16'($signed(mul_prod[0])) <<< 4) + 16'($signed(mul_prod[1])) + 16'($signed(pair0_correction)));

        pair1_correction = int_act_i[11] ? (12'($signed(int_wgt_i[7:4])) <<< 4) : 12'sd0;
        int4x8_pair[1]   = 16'((16'($signed(mul_prod[2])) <<< 4) + 16'($signed(mul_prod[3])) + 16'($signed(pair1_correction)));

        int4x8_sum       = $signed(int4x8_pair[0]) + $signed(int4x8_pair[1]);
    end

    // -------------------------------------------------------------------------
    // Accumulator
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            acc_q <= 16'sd0;
        end else if (acc_clear_i) begin
            acc_q <= 16'sd0;
        end else if (acc_en_i) begin
            acc_q <= acc_d;
        end
    end

    always_comb begin
        mac_result = 16'sd0;
        acc_d      = acc_q;

        case (mode_i)
            2'b01: mac_result = int4x8_sum;
            2'b10: mac_result = int4x4_sum;
            default: begin
            end
        endcase

        acc_d = acc_q + mac_result;
    end

    assign acc_o = acc_q;

endmodule
