//-----------------------------------------------------------------------------
// File: sfu_tile_classifier.sv
// Date Created: 2026-04-11
// Description: SFU tile classifier. Tracks BF16 exponent spread across sparse
//              dequant-result pulses and emits one INT4/INT8 decision per core.
//
//              2-stage pipeline:
//                Stage 1: exponent extraction, zero masking, 16-input max/min
//                         reduction trees -> registered into s1_*_q
//                Stage 2: per-core context comparison, spread computation,
//                         threshold check, decision -> existing context/decision
//                         registers
//-----------------------------------------------------------------------------

module sfu_tile_classifier #(
    parameter integer VLEN       = 16,
    parameter integer ELEM_WIDTH = 16
) (
    input  logic                            clk_i,
    input  logic                            rst_ni,
    input  logic                            clear_i,
    input  logic                            valid_i,
    input  logic [VLEN-1:0][ELEM_WIDTH-1:0] dequant_result_i,
    input  logic [     1:0]                 core_idx_i,
    input  logic                            last_token_i,
    input  logic [     7:0]                 spread_threshold_i,
    output logic [     3:0]                 tile_decision_o,
    output logic [     3:0]                 tile_decision_valid_o
);

    localparam integer NUM_CORES = 4;
    localparam integer EXP_WIDTH = 8;
    localparam logic [EXP_WIDTH-1:0] MAX_EXP_RESET_VAL = 8'h00;
    localparam logic [EXP_WIDTH-1:0] MIN_EXP_RESET_VAL = 8'hff;

    // Stage 1 combinational signals
    logic [VLEN-1:0][EXP_WIDTH-1:0] elem_exp;
    logic [VLEN-1:0]                elem_is_zero;
    logic [VLEN-1:0][EXP_WIDTH-1:0] elem_max_masked;
    logic [VLEN-1:0][EXP_WIDTH-1:0] elem_min_masked;

    // Balanced binary max reduction tree (4 levels for VLEN=16)
    logic [EXP_WIDTH-1:0] max_l1 [VLEN/2];   // 16 -> 8
    logic [EXP_WIDTH-1:0] max_l2 [VLEN/4];   // 8  -> 4
    logic [EXP_WIDTH-1:0] max_l3 [VLEN/8];   // 4  -> 2
    logic [EXP_WIDTH-1:0] vec_max;            // 2  -> 1

    // Balanced binary min reduction tree
    logic [EXP_WIDTH-1:0] min_l1 [VLEN/2];
    logic [EXP_WIDTH-1:0] min_l2 [VLEN/4];
    logic [EXP_WIDTH-1:0] min_l3 [VLEN/8];
    logic [EXP_WIDTH-1:0] vec_min;

    // Stage 1 pipeline registers
    logic [EXP_WIDTH-1:0] s1_vec_max_q;
    logic [EXP_WIDTH-1:0] s1_vec_min_q;
    logic [          1:0] s1_core_idx_q;
    logic                 s1_last_token_q;
    logic                 s1_valid_q;

    // Stage 2 signals and per-core context registers
    logic [NUM_CORES-1:0][EXP_WIDTH-1:0] max_exp_d, max_exp_q;
    logic [NUM_CORES-1:0][EXP_WIDTH-1:0] min_exp_d, min_exp_q;
    logic [NUM_CORES-1:0] decision_d, decision_q;
    logic [NUM_CORES-1:0] decision_valid_d, decision_valid_q;

    logic [EXP_WIDTH-1:0] new_max;
    logic [EXP_WIDTH-1:0] new_min;
    logic [EXP_WIDTH-1:0] spread;
    logic                 next_decision;

    // -------------------------------------------------------------------------
    // Stage 1: exponent extraction, zero masking, balanced binary reductions
    // -------------------------------------------------------------------------

    always_comb begin
        // Exponent extraction and zero masking
        for (int i = 0; i < VLEN; i++) begin
            elem_exp[i]        = dequant_result_i[i][14:7];
            elem_is_zero[i]    = (elem_exp[i] == MAX_EXP_RESET_VAL);
            elem_max_masked[i] = elem_is_zero[i] ? MAX_EXP_RESET_VAL : elem_exp[i];
            elem_min_masked[i] = elem_is_zero[i] ? MIN_EXP_RESET_VAL : elem_exp[i];
        end

        // Max reduction tree (balanced binary): 16 -> 8 -> 4 -> 2 -> 1
        for (int i = 0; i < VLEN / 2; i++) begin
            max_l1[i] = (elem_max_masked[2*i] >= elem_max_masked[2*i+1]) ? elem_max_masked[2*i] : elem_max_masked[2*i+1];
        end
        for (int i = 0; i < VLEN / 4; i++) begin
            max_l2[i] = (max_l1[2*i] >= max_l1[2*i+1]) ? max_l1[2*i] : max_l1[2*i+1];
        end
        for (int i = 0; i < VLEN / 8; i++) begin
            max_l3[i] = (max_l2[2*i] >= max_l2[2*i+1]) ? max_l2[2*i] : max_l2[2*i+1];
        end
        vec_max = (max_l3[0] >= max_l3[1]) ? max_l3[0] : max_l3[1];

        // Min reduction tree (balanced binary): 16 -> 8 -> 4 -> 2 -> 1
        for (int i = 0; i < VLEN / 2; i++) begin
            min_l1[i] = (elem_min_masked[2*i] <= elem_min_masked[2*i+1]) ? elem_min_masked[2*i] : elem_min_masked[2*i+1];
        end
        for (int i = 0; i < VLEN / 4; i++) begin
            min_l2[i] = (min_l1[2*i] <= min_l1[2*i+1]) ? min_l1[2*i] : min_l1[2*i+1];
        end
        for (int i = 0; i < VLEN / 8; i++) begin
            min_l3[i] = (min_l2[2*i] <= min_l2[2*i+1]) ? min_l2[2*i] : min_l2[2*i+1];
        end
        vec_min = (min_l3[0] <= min_l3[1]) ? min_l3[0] : min_l3[1];
    end

    // -------------------------------------------------------------------------
    // Stage 1 pipeline registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            s1_valid_q <= 1'b0;
        end else if (clear_i) begin
            s1_valid_q <= 1'b0;
        end else begin
            s1_valid_q <= valid_i;
            if (valid_i) begin
                s1_vec_max_q    <= vec_max;
                s1_vec_min_q    <= vec_min;
                s1_core_idx_q   <= core_idx_i;
                s1_last_token_q <= last_token_i;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2: context comparison and decision logic
    // -------------------------------------------------------------------------

    assign new_max       = (max_exp_q[s1_core_idx_q] >= s1_vec_max_q) ? max_exp_q[s1_core_idx_q] : s1_vec_max_q;
    assign new_min       = (min_exp_q[s1_core_idx_q] <= s1_vec_min_q) ? min_exp_q[s1_core_idx_q] : s1_vec_min_q;
    assign spread        = new_max - new_min;
    assign next_decision = (new_max == MAX_EXP_RESET_VAL) ? 1'b0 : (spread <= spread_threshold_i) ? 1'b0 : 1'b1;

    // -------------------------------------------------------------------------
    // Per-core context and decision registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            max_exp_q        <= '0;
            min_exp_q        <= {NUM_CORES{MIN_EXP_RESET_VAL}};
            decision_q       <= '0;
            decision_valid_q <= '0;
        end else begin
            max_exp_q        <= max_exp_d;
            min_exp_q        <= min_exp_d;
            decision_q       <= decision_d;
            decision_valid_q <= decision_valid_d;
        end
    end

    always_comb begin
        max_exp_d        = max_exp_q;
        min_exp_d        = min_exp_q;
        decision_d       = decision_q;
        decision_valid_d = decision_valid_q;

        if (clear_i) begin
            max_exp_d        = '0;
            min_exp_d        = {NUM_CORES{MIN_EXP_RESET_VAL}};
            decision_d       = '0;
            decision_valid_d = '0;
        end else if (s1_valid_q) begin
            if (s1_last_token_q) begin
                max_exp_d[s1_core_idx_q]        = MAX_EXP_RESET_VAL;
                min_exp_d[s1_core_idx_q]        = MIN_EXP_RESET_VAL;
                decision_d[s1_core_idx_q]       = next_decision;
                decision_valid_d[s1_core_idx_q] = 1'b1;
            end else begin
                max_exp_d[s1_core_idx_q] = new_max;
                min_exp_d[s1_core_idx_q] = new_min;
            end
        end
    end

    assign tile_decision_o       = decision_q;
    assign tile_decision_valid_o = decision_valid_q;

endmodule
