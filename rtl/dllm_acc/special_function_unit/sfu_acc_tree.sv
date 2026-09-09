//-----------------------------------------------------------------------------
// File: sfu_acc_tree.sv
// Description: 2-level BF16 addition tree for deferred accumulation.
//              Takes N_INPUTS (must be 4) vectors and produces their sum.
//              Level 1: two parallel adds. Level 2: one add of partials.
//              Reuses sfu_acc_lane instances with acc_clear_i=0 (pure add).
//-----------------------------------------------------------------------------

module sfu_acc_tree #(
    parameter integer VLEN       = 16,
    parameter integer ELEM_WIDTH = 16,
    parameter integer N_INPUTS   = 4
) (
    input  logic clk_i,
    input  logic rst_ni,

    input  logic                                                valid_i,
    output logic                                                ready_o,
    output logic                                                done_o,
    input  logic [N_INPUTS-1:0][VLEN-1:0][ELEM_WIDTH-1:0]      operands_i,
    output logic [              VLEN-1:0][ELEM_WIDTH-1:0]       result_o
);

    initial begin
        if (N_INPUTS != 4)
            $fatal(1, "sfu_acc_tree: only N_INPUTS=4 is supported (got %0d)", N_INPUTS);
    end

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------

    typedef enum logic [2:0] {
        TREE_IDLE,
        TREE_WAIT_L1,
        TREE_L2_LAUNCH,
        TREE_WAIT_L2,
        TREE_DONE
    } tree_state_t;

    tree_state_t state_d, state_q;

    // -------------------------------------------------------------------------
    // Lane signals
    // -------------------------------------------------------------------------

    // Level-1 lanes (parallel)
    logic                            l1_0_valid, l1_0_ready, l1_0_done;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] l1_0_result;

    logic                            l1_1_valid, l1_1_ready, l1_1_done;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] l1_1_result;

    // Level-2 lane
    logic                            l2_valid, l2_ready, l2_done;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] l2_result;

    // Partial results from L1
    logic [VLEN-1:0][ELEM_WIDTH-1:0] partial_01_d, partial_01_q;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] partial_23_d, partial_23_q;

    // Final result captured from L2
    logic [VLEN-1:0][ELEM_WIDTH-1:0] final_result_d, final_result_q;

    // Done accumulation for L1 (handles potential 1-cycle offset)
    logic [1:0] l1_done_seen_d, l1_done_seen_q;

    // -------------------------------------------------------------------------
    // Lane instantiations
    // -------------------------------------------------------------------------

    sfu_acc_lane #(
        .VLEN      (VLEN),
        .ELEM_WIDTH(ELEM_WIDTH)
    ) i_lane_l1_0 (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .valid_i     (l1_0_valid),
        .ready_o     (l1_0_ready),
        .done_o      (l1_0_done),
        .acc_clear_i (1'b0),
        .op_a_i      (operands_i[0]),
        .op_b_i      (operands_i[1]),
        .acc_result_o(l1_0_result)
    );

    sfu_acc_lane #(
        .VLEN      (VLEN),
        .ELEM_WIDTH(ELEM_WIDTH)
    ) i_lane_l1_1 (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .valid_i     (l1_1_valid),
        .ready_o     (l1_1_ready),
        .done_o      (l1_1_done),
        .acc_clear_i (1'b0),
        .op_a_i      (operands_i[2]),
        .op_b_i      (operands_i[3]),
        .acc_result_o(l1_1_result)
    );

    sfu_acc_lane #(
        .VLEN      (VLEN),
        .ELEM_WIDTH(ELEM_WIDTH)
    ) i_lane_l2 (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .valid_i     (l2_valid),
        .ready_o     (l2_ready),
        .done_o      (l2_done),
        .acc_clear_i (1'b0),
        .op_a_i      (partial_01_q),
        .op_b_i      (partial_23_q),
        .acc_result_o(l2_result)
    );

    // -------------------------------------------------------------------------
    // Output
    // -------------------------------------------------------------------------

    assign result_o = final_result_q;

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q        <= TREE_IDLE;
            l1_done_seen_q <= '0;
            final_result_q <= '0;
        end else begin
            state_q        <= state_d;
            l1_done_seen_q <= l1_done_seen_d;
            final_result_q <= final_result_d;
        end
    end

    always_ff @(posedge clk_i) begin
        partial_01_q <= partial_01_d;
        partial_23_q <= partial_23_d;
    end

    // -------------------------------------------------------------------------
    // L1 done detection with accumulation
    // -------------------------------------------------------------------------

    logic both_l1_done;
    logic [1:0] l1_done_merged;

    assign l1_done_merged = l1_done_seen_q | {l1_1_done, l1_0_done};
    assign both_l1_done   = &l1_done_merged;

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------

    always_comb begin
        state_d        = state_q;
        partial_01_d   = partial_01_q;
        partial_23_d   = partial_23_q;
        final_result_d = final_result_q;
        l1_done_seen_d = l1_done_seen_q | {l1_1_done, l1_0_done};

        l1_0_valid = 1'b0;
        l1_1_valid = 1'b0;
        l2_valid   = 1'b0;
        ready_o    = 1'b0;
        done_o     = 1'b0;

        case (state_q)
            TREE_IDLE: begin
                ready_o = 1'b1;
                if (valid_i) begin
                    l1_0_valid     = 1'b1;
                    l1_1_valid     = 1'b1;
                    l1_done_seen_d = '0;
                    state_d        = TREE_WAIT_L1;
                end
            end

            TREE_WAIT_L1: begin
                if (both_l1_done) begin
                    partial_01_d = l1_0_result;
                    partial_23_d = l1_1_result;
                    state_d      = TREE_L2_LAUNCH;
                end
            end

            // 1-cycle settle: partial_q now holds L1 results,
            // so L2 bf16_adder reads correct operands via op_a/b
            TREE_L2_LAUNCH: begin
                l2_valid = 1'b1;
                state_d  = TREE_WAIT_L2;
            end

            TREE_WAIT_L2: begin
                if (l2_done) begin
                    final_result_d = l2_result;
                    state_d        = TREE_DONE;
                end
            end

            TREE_DONE: begin
                done_o  = 1'b1;
                state_d = TREE_IDLE;
            end

            default: begin
                state_d = TREE_IDLE;
            end
        endcase
    end

endmodule
