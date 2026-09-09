//-----------------------------------------------------------------------------
// File: bf16_adder.sv
// Date Created: 2026-03-20
// Description: Simplified 3-stage pipelined BF16 adder cell.
//-----------------------------------------------------------------------------

module bf16_adder (
    input  logic        clk_i,
    input  logic        en_i,
    input  logic [15:0] a_i,
    input  logic [15:0] b_i,
    output logic [15:0] sum_o
);

    //-------------------------------------------------------------------------
    // Datapath sizing
    //-------------------------------------------------------------------------
    localparam integer EXP_WIDTH = 8;
    localparam integer FRAC_WIDTH = 7;
    localparam integer GUARD_WIDTH = 3;
    localparam integer SIG_WIDTH = 1 + FRAC_WIDTH + GUARD_WIDTH;
    localparam integer SIG_SUM_WIDTH = SIG_WIDTH + 1;

    // Stage 1 registers: larger operand selection and aligned smaller significand.
    logic stage1_sign_large_d, stage1_sign_large_q;
    logic stage1_same_sign_d, stage1_same_sign_q;
    logic [EXP_WIDTH-1:0] stage1_exp_large_d, stage1_exp_large_q;
    logic [SIG_WIDTH-1:0] stage1_sig_large_d, stage1_sig_large_q;
    logic [SIG_WIDTH-1:0] stage1_sig_small_d, stage1_sig_small_q;

    // Stage 2 registers: add/subtract result before normalization.
    logic stage2_sign_d, stage2_sign_q;
    logic stage2_same_sign_d, stage2_same_sign_q;
    logic [EXP_WIDTH-1:0] stage2_exp_d, stage2_exp_q;
    logic [SIG_SUM_WIDTH-1:0] stage2_sig_d, stage2_sig_q;

    // Stage 3 register: final packed BF16 result.
    logic [15:0] stage3_sum_d, stage3_sum_q;

    //-------------------------------------------------------------------------
    // Helper functions
    //-------------------------------------------------------------------------
    function automatic [SIG_WIDTH-1:0] bf16_sig(input logic [14:0] value_i);
        if (value_i[14:7] == 8'h00) begin
            bf16_sig = '0;
        end else begin
            bf16_sig = {1'b1, value_i[6:0], {GUARD_WIDTH{1'b0}}};
        end
    endfunction

    function automatic [SIG_WIDTH-1:0] shift_right_sat(input logic [SIG_WIDTH-1:0] value_i, input logic [EXP_WIDTH-1:0] shift_i);
        if (shift_i >= EXP_WIDTH'(SIG_WIDTH)) begin
            shift_right_sat = '0;
        end else begin
            shift_right_sat = value_i >> shift_i;
        end
    endfunction

    function automatic integer lead_shift(input logic [SIG_WIDTH-1:0] value_i);
        integer idx;
        begin
            lead_shift = SIG_WIDTH;
            for (idx = SIG_WIDTH - 1; idx >= 0; idx = idx - 1) begin
                if (value_i[idx]) begin
                    lead_shift = SIG_WIDTH - 1 - idx;
                    break;
                end
            end
        end
    endfunction

    //-------------------------------------------------------------------------
    // Stage 1: unpack BF16, pick the larger-magnitude operand, and align the
    // smaller significand to the larger exponent.
    //-------------------------------------------------------------------------
    always_comb begin
        logic                 a_sign;
        logic                 b_sign;
        logic [EXP_WIDTH-1:0] a_exp;
        logic [EXP_WIDTH-1:0] b_exp;
        logic [SIG_WIDTH-1:0] a_sig;
        logic [SIG_WIDTH-1:0] b_sig;
        logic                 a_ge_b;
        logic [EXP_WIDTH-1:0] exp_diff;

        a_sign   = a_i[15];
        b_sign   = b_i[15];
        a_exp    = (a_i[14:7] == 8'hff) ? 8'hfe : a_i[14:7];
        b_exp    = (b_i[14:7] == 8'hff) ? 8'hfe : b_i[14:7];
        a_sig    = bf16_sig(a_i[14:0]);
        b_sig    = bf16_sig(b_i[14:0]);

        a_ge_b   = (a_exp > b_exp) || ((a_exp == b_exp) && (a_sig >= b_sig));
        exp_diff = a_ge_b ? (a_exp - b_exp) : (b_exp - a_exp);

        if (en_i) begin
            stage1_same_sign_d = (a_sign == b_sign);
            if (a_ge_b) begin
                stage1_sign_large_d = a_sign;
                stage1_exp_large_d  = a_exp;
                stage1_sig_large_d  = a_sig;
                stage1_sig_small_d  = shift_right_sat(b_sig, exp_diff);
            end else begin
                stage1_sign_large_d = b_sign;
                stage1_exp_large_d  = b_exp;
                stage1_sig_large_d  = b_sig;
                stage1_sig_small_d  = shift_right_sat(a_sig, exp_diff);
            end
        end else begin
            stage1_sign_large_d = 1'b0;
            stage1_same_sign_d  = 1'b0;
            stage1_exp_large_d  = '0;
            stage1_sig_large_d  = '0;
            stage1_sig_small_d  = '0;
        end
    end

    // Stage 1 register boundary.
    always_ff @(posedge clk_i) begin
        stage1_sign_large_q <= stage1_sign_large_d;
        stage1_same_sign_q  <= stage1_same_sign_d;
        stage1_exp_large_q  <= stage1_exp_large_d;
        stage1_sig_large_q  <= stage1_sig_large_d;
        stage1_sig_small_q  <= stage1_sig_small_d;
    end

    //-------------------------------------------------------------------------
    // Stage 2: add for equal-sign inputs, subtract for opposite-sign inputs.
    //-------------------------------------------------------------------------
    always_comb begin

        stage2_sign_d      = stage1_sign_large_q;
        stage2_same_sign_d = stage1_same_sign_q;
        stage2_exp_d       = stage1_exp_large_q;
        if (stage1_same_sign_q) begin
            stage2_sig_d = {1'b0, stage1_sig_large_q} + {1'b0, stage1_sig_small_q};
        end else begin
            stage2_sig_d = {1'b0, stage1_sig_large_q} - {1'b0, stage1_sig_small_q};
        end
    end

    // Stage 2 register boundary.
    always_ff @(posedge clk_i) begin
        stage2_sign_q      <= stage2_sign_d;
        stage2_same_sign_q <= stage2_same_sign_d;
        stage2_exp_q       <= stage2_exp_d;
        stage2_sig_q       <= stage2_sig_d;
    end

    //-------------------------------------------------------------------------
    // Stage 3: normalize the significand and repack the simplified BF16 result.
    //-------------------------------------------------------------------------
    always_comb begin
        logic   [EXP_WIDTH-1:0] norm_exp;
        logic   [SIG_WIDTH-1:0] norm_sig;
        integer                 norm_shift;

        norm_exp   = stage2_exp_q;
        norm_sig   = stage2_sig_q[SIG_WIDTH-1:0];
        norm_shift = 0;

        if (stage2_sig_q == '0) begin
            stage3_sum_d = '0;
        end else begin
            if (stage2_same_sign_q && stage2_sig_q[SIG_WIDTH]) begin
                norm_sig = stage2_sig_q[SIG_WIDTH:1];
                norm_exp = stage2_exp_q + EXP_WIDTH'(1);
            end else if (!stage2_same_sign_q) begin
                norm_shift = lead_shift(stage2_sig_q[SIG_WIDTH-1:0]);
                if ((norm_shift >= SIG_WIDTH) || (stage2_exp_q <= norm_shift[EXP_WIDTH-1:0])) begin
                    norm_sig = '0;
                    norm_exp = '0;
                end else begin
                    norm_sig = stage2_sig_q[SIG_WIDTH-1:0] << norm_shift;
                    norm_exp = stage2_exp_q - EXP_WIDTH'(norm_shift);
                end
            end

            if ((norm_sig == '0) || (norm_exp == '0)) begin
                stage3_sum_d = '0;
            end else if (norm_exp >= 8'hff) begin
                stage3_sum_d = {stage2_sign_q, 8'hfe, 7'h7f};
            end else begin
                stage3_sum_d = {stage2_sign_q, norm_exp, norm_sig[FRAC_WIDTH+GUARD_WIDTH-1:GUARD_WIDTH]};
            end
        end
    end

    // Final output register.
    always_ff @(posedge clk_i) begin
        stage3_sum_q <= stage3_sum_d;
    end

    assign sum_o = stage3_sum_q;

endmodule
