//-----------------------------------------------------------------------------
// File: sfu_ctrl.sv
// Description: SFU sequencer for the dLLM accelerator wrapper.
//              Orchestrates one-wave coupled execution: waits for all cores to
//              complete, then issues per-token start pulses to the SFUs.
//              Each SFU handles its own core iteration internally (deferred
//              accumulation architecture). The sequencer manages the token loop,
//              result writeback, and loop/retrigger logic.
//-----------------------------------------------------------------------------

module sfu_ctrl #(
    parameter integer AXI_ADDR_WIDTH = 64,
    parameter integer AXI_DATA_WIDTH = 64,
    parameter integer N_SFUS         = 4,
    parameter integer CORES_PER_SFU  = 4,
    parameter integer VLEN           = 16,
    parameter integer ELEM_WIDTH     = 16,
    parameter integer SFU_CFG_WIDTH  = 32,
    parameter integer RESULT_DEPTH   = 32
) (
    input logic clk_i,
    input logic rst_ni,

    // Wave control (from sfu_cfg)
    input logic wave_en_i,
    input logic test_start_i,
    input logic all_cal_done_i,
    input logic loop_en_i,

    // Per-SFU config (from sfu_cfg)
    input logic [N_SFUS-1:0][SFU_CFG_WIDTH-1:0] sfu_cfg_i,

    // SFU execution interface
    output logic [N_SFUS-1:0]                      sfu_start_o,
    input  logic [N_SFUS-1:0]                      sfu_done_i,
    output logic [AXI_ADDR_WIDTH-1:0]              base_addr_o,
    output logic [AXI_ADDR_WIDTH-1:0]              hi_addr_o,

    // Per-SFU config decomposition outputs (directly to SFU instances)
    output logic [N_SFUS-1:0]                      dequant_type_sel_o,
    output logic [N_SFUS-1:0]                      quant_profiling_enable_o,
    output logic [N_SFUS-1:0][7:0]                 spread_threshold_o,
    output logic [N_SFUS-1:0]                      last_token_o,
    output logic [N_SFUS-1:0][CORES_PER_SFU-1:0]  core_mask_o,

    // Accumulator results (from SFU instances)
    input logic [N_SFUS-1:0][VLEN*ELEM_WIDTH-1:0] acc_result_i,

    // Result buffer write port
    output logic [              N_SFUS-1:0]                      result_wr_en_o,
    output logic [$clog2(RESULT_DEPTH)-1:0]                      result_wr_addr_o,
    output logic [              N_SFUS-1:0][VLEN*ELEM_WIDTH-1:0] result_wr_data_o,

    // Loop mode
    output logic [N_SFUS*CORES_PER_SFU-1:0] cal_en_retrigger_o,

    // Status
    output logic sfu_active_o,
    output logic wave_done_o,
    output logic test_mode_o
);

    // -------------------------------------------------------------------------
    // Local parameters
    // -------------------------------------------------------------------------

    localparam integer TOKEN_IDX_WIDTH = $clog2(RESULT_DEPTH);
    localparam integer SFU_ACC_WIDTH = VLEN * ELEM_WIDTH;

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------

    typedef enum logic [3:0] {
        CTRL_IDLE,
        CTRL_ARMED,
        CTRL_WAVE_START,
        CTRL_TOKEN_START,
        CTRL_TOKEN_WAIT,
        CTRL_WRITEBACK,
        CTRL_TOKEN_NEXT,
        CTRL_WAVE_DONE,
        CTRL_RETRIGGER
    } ctrl_state_t;

    ctrl_state_t state_d, state_q;
    logic test_mode_d, test_mode_q;

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------

    logic [TOKEN_IDX_WIDTH-1:0] token_cnt_d, token_cnt_q;

    // Accumulated SFU done pulses (for mixed-latency SFUs with different core_masks)
    logic [N_SFUS-1:0] sfu_done_seen_d, sfu_done_seen_q;

    // -------------------------------------------------------------------------
    // Per-SFU config decomposition
    // -------------------------------------------------------------------------

    logic [N_SFUS-1:0][TOKEN_IDX_WIDTH-1:0] token_count;

    generate
        for (genvar s = 0; s < N_SFUS; s++) begin : gen_cfg_decompose
            assign dequant_type_sel_o[s]       = sfu_cfg_i[s][0];
            assign quant_profiling_enable_o[s] = sfu_cfg_i[s][1];
            assign spread_threshold_o[s]       = sfu_cfg_i[s][9:2];
            assign token_count[s]              = sfu_cfg_i[s][15:10];
            assign core_mask_o[s]              = sfu_cfg_i[s][19:16];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Max token count across all SFUs
    // -------------------------------------------------------------------------

    logic [TOKEN_IDX_WIDTH-1:0] max_token_count;

    always_comb begin
        max_token_count = token_count[0];
        for (int s = 1; s < N_SFUS; s++) begin
            if (token_count[s] > max_token_count) begin
                max_token_count = token_count[s];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Per-SFU token active mask (which SFUs participate at this token)
    // -------------------------------------------------------------------------

    logic [N_SFUS-1:0] token_active_mask;

    always_comb begin
        for (int s = 0; s < N_SFUS; s++) begin
            token_active_mask[s] = (token_cnt_q < token_count[s]);
        end
    end

    // -------------------------------------------------------------------------
    // Address generation
    // -------------------------------------------------------------------------

    assign base_addr_o = {{(AXI_ADDR_WIDTH - 11) {1'b0}}, 2'b11, 1'b0, token_cnt_q, 2'b00};
    assign hi_addr_o   = {{(AXI_ADDR_WIDTH - 11) {1'b0}}, 2'b11, 1'b1, token_cnt_q, 2'b00};

    // -------------------------------------------------------------------------
    // Per-SFU last-token flag
    // -------------------------------------------------------------------------

    generate
        for (genvar s = 0; s < N_SFUS; s++) begin : gen_last_token
            assign last_token_o[s] = (token_cnt_q == token_count[s] - TOKEN_IDX_WIDTH'(1));
        end
    endgenerate

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------

    logic all_sfu_done;
    logic [N_SFUS-1:0] sfu_done_merged;
    assign sfu_done_merged = sfu_done_seen_q | sfu_done_i;
    assign all_sfu_done    = &(sfu_done_merged | ~token_active_mask);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q          <= CTRL_IDLE;
            token_cnt_q      <= '0;
            test_mode_q      <= 1'b0;
            sfu_done_seen_q  <= '0;
        end else begin
            state_q          <= state_d;
            token_cnt_q      <= token_cnt_d;
            test_mode_q      <= test_mode_d;
            sfu_done_seen_q  <= sfu_done_seen_d;
        end
    end

    always_comb begin
        state_d            = state_q;
        token_cnt_d        = token_cnt_q;
        test_mode_d        = test_mode_q;

        sfu_active_o       = 1'b0;
        wave_done_o        = 1'b0;
        test_mode_o        = test_mode_q;
        sfu_start_o        = '0;
        result_wr_en_o     = '0;
        result_wr_addr_o   = token_cnt_q;
        result_wr_data_o   = acc_result_i;
        cal_en_retrigger_o = '0;
        sfu_done_seen_d    = sfu_done_seen_q | sfu_done_i;

        case (state_q)
            CTRL_IDLE: begin
                test_mode_d = 1'b0;
                if (test_start_i) begin
                    test_mode_d = 1'b1;
                    state_d     = CTRL_WAVE_START;
                end else if (wave_en_i) begin
                    state_d = CTRL_ARMED;
                end
            end

            CTRL_ARMED: begin
                if (all_cal_done_i) begin
                    state_d = CTRL_WAVE_START;
                end
            end

            CTRL_WAVE_START: begin
                sfu_active_o = 1'b1;
                token_cnt_d  = '0;
                state_d      = CTRL_TOKEN_START;
            end

            CTRL_TOKEN_START: begin
                sfu_active_o    = 1'b1;
                // Start all SFUs that have tokens remaining
                sfu_start_o     = token_active_mask;
                sfu_done_seen_d = '0;
                state_d         = CTRL_TOKEN_WAIT;
            end

            CTRL_TOKEN_WAIT: begin
                sfu_active_o = 1'b1;
                if (all_sfu_done) begin
                    state_d = CTRL_WRITEBACK;
                end
            end

            CTRL_WRITEBACK: begin
                sfu_active_o     = 1'b1;
                result_wr_addr_o = token_cnt_q;
                result_wr_data_o = acc_result_i;
                state_d          = CTRL_TOKEN_NEXT;

                for (int s = 0; s < N_SFUS; s++) begin
                    result_wr_en_o[s] = (token_cnt_q < token_count[s]);
                end
            end

            CTRL_TOKEN_NEXT: begin
                sfu_active_o = 1'b1;
                if (token_cnt_q == max_token_count - TOKEN_IDX_WIDTH'(1)) begin
                    if (test_mode_q && loop_en_i) begin
                        token_cnt_d = '0;
                        state_d     = CTRL_TOKEN_START;
                    end else begin
                        state_d = CTRL_WAVE_DONE;
                    end
                end else begin
                    token_cnt_d = token_cnt_q + TOKEN_IDX_WIDTH'(1);
                    state_d     = CTRL_TOKEN_START;
                end
            end

            CTRL_WAVE_DONE: begin
                wave_done_o = 1'b1;
                if (test_mode_q) begin
                    state_d = CTRL_IDLE;
                end else if (loop_en_i) begin
                    state_d = CTRL_RETRIGGER;
                end else begin
                    state_d = CTRL_IDLE;
                end
            end

            CTRL_RETRIGGER: begin
                cal_en_retrigger_o = {(N_SFUS * CORES_PER_SFU) {1'b1}};
                state_d            = CTRL_ARMED;
            end

            default: begin
                state_d = CTRL_IDLE;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Assertions
    // -------------------------------------------------------------------------

`ifndef SYNTHESIS
    // pragma translate_off
    generate
        for (genvar s = 0; s < N_SFUS; s++) begin : gen_assert_core_mask
            always @(posedge clk_i) begin
                if (rst_ni && (state_q == CTRL_WAVE_START)) begin
                    assert ($countones(core_mask_o[s]) >= 2)
                    else $error("sfu_ctrl: core_mask[%0d] = %b has fewer than 2 bits set", s, core_mask_o[s]);
                end
            end
        end
    endgenerate

    always @(posedge clk_i) begin
        if (rst_ni && (state_q == CTRL_WAVE_START)) begin
            assert (max_token_count >= TOKEN_IDX_WIDTH'(1))
            else $error("sfu_ctrl: max_token_count is zero");
        end
    end
    // pragma translate_on
`endif

endmodule
