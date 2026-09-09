//-----------------------------------------------------------------------------
// File: bf16_dequant.sv
// Date Created: 2026-04-04
// Description: Simplified 3-stage pipelined dequantization cell for the SFU.
//              Accepts a signed integer payload in a 16-bit container and a
//              BF16 scale, producing a BF16 dequantized result.
//              Supports INT12 and INT16 payloads via the runtime dequant_type_i
//              signal (0 = INT12, 1 = INT16).
//-----------------------------------------------------------------------------

module bf16_dequant (
    input  logic        clk_i,
    input  logic        en_i,
    input  logic        dequant_type_i,  // 0: INT12 (sign-extend from bit 11)
                                         // 1: INT16 (full 16-bit signed)
    input  logic [15:0] quant_i,
    input  logic [15:0] scale_i,
    output logic [15:0] dequant_o
);

    //-------------------------------------------------------------------------
    // Datapath sizing
    //-------------------------------------------------------------------------
    localparam integer EXP_WIDTH = 8;
    localparam integer FRAC_WIDTH = 7;
    localparam integer GUARD_WIDTH = 3;
    localparam integer SIG_WIDTH = 1 + FRAC_WIDTH + GUARD_WIDTH;
    localparam integer PROD_WIDTH = 2 * SIG_WIDTH;
    localparam integer EXP_SUM_WIDTH = EXP_WIDTH + 1;
    localparam integer CONTAINER_WIDTH = 16;

    // Stage 1 registers: unpacked scale, normalized integer magnitude, and sign.
    logic stage1_result_sign_d, stage1_result_sign_q;
    logic stage1_zero_d, stage1_zero_q;
    logic stage1_saturate_d, stage1_saturate_q;
    logic [EXP_SUM_WIDTH-1:0] stage1_exp_sum_d, stage1_exp_sum_q;
    logic [SIG_WIDTH-1:0] stage1_int_sig_d, stage1_int_sig_q;
    logic [SIG_WIDTH-1:0] stage1_scale_sig_d, stage1_scale_sig_q;

    // Stage 2 registers: significand product and exponent sum.
    logic stage2_result_sign_d, stage2_result_sign_q;
    logic stage2_zero_d, stage2_zero_q;
    logic stage2_saturate_d, stage2_saturate_q;
    logic [EXP_SUM_WIDTH-1:0] stage2_exp_sum_d, stage2_exp_sum_q;
    logic [PROD_WIDTH-1:0] stage2_sig_prod_d, stage2_sig_prod_q;

    // Stage 3 register: packed BF16 result.
    logic [15:0] stage3_dequant_d, stage3_dequant_q;

    //-------------------------------------------------------------------------
    // Helper functions
    //-------------------------------------------------------------------------
    function automatic integer lead_one_idx(input logic [CONTAINER_WIDTH-1:0] value_i);
        integer idx;
        begin
            lead_one_idx = -1;
            for (idx = CONTAINER_WIDTH - 1; idx >= 0; idx = idx - 1) begin
                if (value_i[idx]) begin
                    lead_one_idx = idx;
                    break;
                end
            end
        end
    endfunction

    function automatic [SIG_WIDTH-1:0] normalized_int_sig(input logic [CONTAINER_WIDTH-1:0] value_i);
        integer lead_idx;
        begin
            lead_idx = lead_one_idx(value_i);
            if (lead_idx < 0) begin
                normalized_int_sig = '0;
            end else if (lead_idx >= (SIG_WIDTH - 1)) begin
                normalized_int_sig = SIG_WIDTH'(value_i >> (lead_idx - (SIG_WIDTH - 1)));
            end else begin
                normalized_int_sig = SIG_WIDTH'(value_i << ((SIG_WIDTH - 1) - lead_idx));
            end
        end
    endfunction

    function automatic [SIG_WIDTH-1:0] bf16_sig(input logic [14:0] value_i);
        if (value_i[14:7] == 8'h00) begin
            bf16_sig = '0;
        end else begin
            bf16_sig = {1'b1, value_i[6:0], {GUARD_WIDTH{1'b0}}};
        end
    endfunction

    //-------------------------------------------------------------------------
    // Stage 1: unpack BF16 scale and normalize the signed integer payload
    // stored in a 16-bit container. dequant_type_i selects the payload width:
    //   0 = INT12: sign-extend from bit 11
    //   1 = INT16: full 16-bit signed value
    //-------------------------------------------------------------------------
    always_comb begin
        logic signed [CONTAINER_WIDTH-1:0] quant_signed;
        logic        [CONTAINER_WIDTH-1:0] quant_abs;
        logic                              scale_sign;
        logic                              quant_sign;
        logic                              scale_zero;
        logic                              scale_special;
        logic        [                3:0] quant_lead_idx;

        if (dequant_type_i) begin
            // INT16: full 16-bit signed
            quant_signed = signed'(quant_i);
        end else begin
            // INT12: sign-extend from bit 11
            quant_signed = signed'({{4{quant_i[11]}}, quant_i[11:0]});
        end
        quant_sign    = quant_signed[CONTAINER_WIDTH-1];
        scale_sign    = scale_i[15];
        scale_zero    = (scale_i[14:7] == 8'h00);
        scale_special = (scale_i[14:7] == 8'hff);
        if (quant_sign) begin
            quant_abs = $unsigned(-quant_signed);
        end else begin
            quant_abs = $unsigned(quant_signed);
        end
        quant_lead_idx = 4'(lead_one_idx(quant_abs));

        if (en_i) begin
            stage1_result_sign_d = quant_sign ^ scale_sign;
            stage1_zero_d        = (quant_abs == '0) || scale_zero;
            stage1_saturate_d    = (quant_abs != '0) && scale_special;
            stage1_exp_sum_d     = scale_i[14:7] + EXP_SUM_WIDTH'(quant_lead_idx);
            stage1_int_sig_d     = normalized_int_sig(quant_abs);
            stage1_scale_sig_d   = bf16_sig(scale_i[14:0]);
        end else begin
            stage1_result_sign_d = 1'b0;
            stage1_zero_d        = 1'b1;
            stage1_saturate_d    = 1'b0;
            stage1_exp_sum_d     = '0;
            stage1_int_sig_d     = '0;
            stage1_scale_sig_d   = '0;
        end
    end

    // Stage 1 register boundary.
    always_ff @(posedge clk_i) begin
        stage1_result_sign_q <= stage1_result_sign_d;
        stage1_zero_q        <= stage1_zero_d;
        stage1_saturate_q    <= stage1_saturate_d;
        stage1_exp_sum_q     <= stage1_exp_sum_d;
        stage1_int_sig_q     <= stage1_int_sig_d;
        stage1_scale_sig_q   <= stage1_scale_sig_d;
    end

    //-------------------------------------------------------------------------
    // Stage 2: multiply the normalized integer and BF16 significands.
    //-------------------------------------------------------------------------
    always_comb begin
        stage2_result_sign_d = stage1_result_sign_q;
        stage2_zero_d        = stage1_zero_q;
        stage2_saturate_d    = stage1_saturate_q;
        stage2_exp_sum_d     = stage1_exp_sum_q;
        stage2_sig_prod_d    = stage1_int_sig_q * stage1_scale_sig_q;
    end

    // Stage 2 register boundary.
    always_ff @(posedge clk_i) begin
        stage2_result_sign_q <= stage2_result_sign_d;
        stage2_zero_q        <= stage2_zero_d;
        stage2_saturate_q    <= stage2_saturate_d;
        stage2_exp_sum_q     <= stage2_exp_sum_d;
        stage2_sig_prod_q    <= stage2_sig_prod_d;
    end

    //-------------------------------------------------------------------------
    // Stage 3: normalize the product and repack the BF16 result.
    //-------------------------------------------------------------------------
    always_comb begin
        logic [EXP_SUM_WIDTH-1:0] norm_exp_sum;
        logic                     carry_out;
        logic [   FRAC_WIDTH-1:0] frac_bits;

        norm_exp_sum = stage2_exp_sum_q;
        carry_out    = stage2_sig_prod_q[PROD_WIDTH-1];
        frac_bits    = stage2_sig_prod_q[PROD_WIDTH-3-:FRAC_WIDTH];

        if (stage2_zero_q || (stage2_sig_prod_q == '0)) begin
            stage3_dequant_d = '0;
        end else if (stage2_saturate_q) begin
            stage3_dequant_d = {stage2_result_sign_q, 8'hfe, 7'h7f};
        end else begin
            if (carry_out) begin
                norm_exp_sum = stage2_exp_sum_q + EXP_SUM_WIDTH'(1);
                frac_bits    = stage2_sig_prod_q[PROD_WIDTH-2-:FRAC_WIDTH];
            end

            if (norm_exp_sum >= EXP_SUM_WIDTH'(8'hff)) begin
                stage3_dequant_d = {stage2_result_sign_q, 8'hfe, 7'h7f};
            end else begin
                stage3_dequant_d = {stage2_result_sign_q, norm_exp_sum[EXP_WIDTH-1:0], frac_bits};
            end
        end
    end

    // Final output register.
    always_ff @(posedge clk_i) begin
        stage3_dequant_q <= stage3_dequant_d;
    end

    assign dequant_o = stage3_dequant_q;

endmodule
