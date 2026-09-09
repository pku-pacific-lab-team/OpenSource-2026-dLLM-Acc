//-----------------------------------------------------------------------------
// File: special_function_unit.sv
// Description: Special function unit inside NPU. Deferred-accumulation
//              architecture with gather-dequant overlap.
//              For each token, iterates over active cores (per core_mask):
//              Phase A: per-core gather+dequant with overlap -- core N+1's
//                       gather runs concurrently with core N's dequant pipeline
//              Phase B: 2-level BF16 addition tree reduces all per-core results
//-----------------------------------------------------------------------------

`include "address_map.svh"

module special_function_unit #(
    parameter integer AXI_ADDR_WIDTH = 64,
    parameter integer AXI_DATA_WIDTH = 64,
    parameter integer VLEN           = 16,
    parameter integer ELEM_WIDTH     = 16,
    parameter integer N_CORES        = 4
) (
    input logic clk_i,
    input logic rst_ni,

    // Single SRAM port to compute core (muxed externally by NPU wrapper)
    output logic                      core_req_o,
    output logic                      core_we_o,
    output logic [AXI_ADDR_WIDTH-1:0] core_addr_o,
    output logic [AXI_DATA_WIDTH-1:0] core_wdata_o,
    input  logic [AXI_DATA_WIDTH-1:0] core_rdata_i,

    // Stable config inputs from NPU wrapper (set before sfu_start_i)
    input logic                                                quant_profiling_enable_i,
    input logic                                                dequant_type_sel_i,
    input logic [AXI_ADDR_WIDTH-1:0]                           base_addr_i,
    input logic [AXI_ADDR_WIDTH-1:0]                           hi_addr_i,
    input logic [       N_CORES-1:0][VLEN-1:0][ELEM_WIDTH-1:0] scale_vec_i,
    input logic [               7:0]                           spread_threshold_i,

    // Control
    input  logic                                       sfu_start_i,
    input  logic [           N_CORES-1:0]              core_mask_i,
    input  logic                                       tile_classifier_clear_i,
    input  logic                                       last_token_i,
    output logic                                       sfu_done_o,
    output logic [           VLEN-1:0][ELEM_WIDTH-1:0] acc_result_o,
    output logic [$clog2(N_CORES)-1:0]                 core_idx_o,
    output logic [        N_CORES-1:0]                 tile_decision_o,
    output logic [        N_CORES-1:0]                 tile_decision_valid_o
);

    // -------------------------------------------------------------------------
    // Local parameters
    // -------------------------------------------------------------------------

    localparam integer CORE_IDX_WIDTH = (N_CORES > 1) ? $clog2(N_CORES) : 1;

    // -------------------------------------------------------------------------
    // FSM state encoding
    // -------------------------------------------------------------------------

    typedef enum logic [3:0] {
        SFU_IDLE,
        SFU_GATHER,
        SFU_GATHER_LAST,
        SFU_DEQUANT,        // launch dequant + store prev result + overlap->GATHER
        SFU_WAIT_DEQUANT,   // last core only: wait for final dequant
        SFU_CAPTURE,         // store last core's result -> tree
        SFU_TREE_START,
        SFU_TREE_WAIT,
        SFU_DONE
    } sfu_state_t;

    // -------------------------------------------------------------------------
    // Signal declarations
    // -------------------------------------------------------------------------

    sfu_state_t state_d, state_q;

    // Core iteration (gather target)
    logic [    N_CORES-1:0] core_mask_q;
    logic [CORE_IDX_WIDTH-1:0] core_cnt_d, core_cnt_q;

    // Dequant tracking (which core's dequant is in-flight / captured)
    logic [CORE_IDX_WIDTH-1:0] dequant_core_d, dequant_core_q;
    logic                      has_prev_result_d, has_prev_result_q;

    // Priority encoder: next active core above core_cnt_q
    logic [CORE_IDX_WIDTH-1:0] next_active_core;
    logic                      has_next_core;

    // Gather
    logic [2:0] gather_cnt_d, gather_cnt_q;
    logic [               2:0] gather_max;
    logic [AXI_ADDR_WIDTH-1:0] gather_addr;

    logic [2:0][AXI_DATA_WIDTH-1:0] lo_staging_d, lo_staging_q;
    logic [2:0][AXI_DATA_WIDTH-1:0] hi_staging_d, hi_staging_q;

    logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_op_d, vec_op_q;

    // Dequant pipeline
    logic                            dequant_valid;
    logic                            dequant_done;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] dequant_result;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] dequant_result_d, dequant_result_q;

    // Per-core dequant result buffers
    logic [N_CORES-1:0][VLEN-1:0][ELEM_WIDTH-1:0] dequant_buf_d, dequant_buf_q;

    // Scale selection (follows gather target = core_cnt_q)
    logic [VLEN-1:0][ELEM_WIDTH-1:0] scale_vec_sel;

    // Tile classifier
    logic                      tile_classifier_valid;
    logic [CORE_IDX_WIDTH-1:0] classifier_core_idx;

    // Staging intermediates
    logic [191:0] lo_final;
    logic [191:0] hi_final;

    // Tree
    logic                            tree_valid;
    logic                            tree_ready;
    logic                            tree_done;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] tree_result;

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q           <= SFU_IDLE;
            gather_cnt_q      <= '0;
            core_cnt_q        <= '0;
            core_mask_q       <= '0;
            dequant_core_q    <= '0;
            has_prev_result_q <= 1'b0;
        end else begin
            state_q           <= state_d;
            gather_cnt_q      <= gather_cnt_d;
            core_cnt_q        <= core_cnt_d;
            dequant_core_q    <= dequant_core_d;
            has_prev_result_q <= has_prev_result_d;
            if (sfu_start_i && state_q == SFU_IDLE)
                core_mask_q <= core_mask_i;
        end
    end

    always_ff @(posedge clk_i) begin
        dequant_buf_q    <= dequant_buf_d;
        dequant_result_q <= dequant_result_d;
    end

    // -------------------------------------------------------------------------
    // Next-active-core priority encoder
    // -------------------------------------------------------------------------

    always_comb begin
        next_active_core = '0;
        has_next_core    = 1'b0;
        for (int c = N_CORES - 1; c >= 0; c--) begin
            if (core_mask_q[c] && (CORE_IDX_WIDTH'(c) > core_cnt_q)) begin
                next_active_core = CORE_IDX_WIDTH'(c);
                has_next_core    = 1'b1;
            end
        end
    end

    // First active core (for initialization, uses unregistered mask)
    logic [CORE_IDX_WIDTH-1:0] first_active_core;

    always_comb begin
        first_active_core = '0;
        for (int c = N_CORES - 1; c >= 0; c--) begin
            if (core_mask_i[c]) begin
                first_active_core = CORE_IDX_WIDTH'(c);
            end
        end
    end

    // -------------------------------------------------------------------------
    // Auto-capture: grab dequant result when pipeline completes
    // This fires regardless of FSM state -- the result is held in
    // dequant_result_q until the FSM stores it into dequant_buf.
    // -------------------------------------------------------------------------

    always_comb begin
        dequant_result_d = dequant_result_q;
        if (dequant_done) begin
            dequant_result_d = dequant_result;
        end
    end

    // -------------------------------------------------------------------------
    // FSM control logic
    // -------------------------------------------------------------------------

    always_comb begin
        state_d               = state_q;
        gather_cnt_d          = gather_cnt_q;
        core_cnt_d            = core_cnt_q;
        dequant_buf_d         = dequant_buf_q;
        dequant_core_d        = dequant_core_q;
        has_prev_result_d     = has_prev_result_q;
        dequant_valid         = 1'b0;
        tile_classifier_valid = 1'b0;
        tree_valid            = 1'b0;
        sfu_done_o            = 1'b0;

        // Mark that a previous result is available once dequant completes
        if (dequant_done) begin
            has_prev_result_d = 1'b1;
        end

        case (state_q)
            SFU_IDLE: begin
                if (sfu_start_i) begin
                    state_d           = SFU_GATHER;
                    gather_cnt_d      = '0;
                    core_cnt_d        = first_active_core;
                    has_prev_result_d = 1'b0;
                    // Zero dequant buffers for inactive cores
                    for (int c = 0; c < N_CORES; c++) begin
                        if (!core_mask_i[c]) begin
                            dequant_buf_d[c] = '0;
                        end
                    end
                end
            end

            SFU_GATHER: begin
                if (gather_cnt_q == gather_max) begin
                    state_d = SFU_GATHER_LAST;
                end else begin
                    gather_cnt_d = gather_cnt_q + 3'd1;
                end
            end

            SFU_GATHER_LAST: begin
                state_d = SFU_DEQUANT;
            end

            // -----------------------------------------------------------------
            // SFU_DEQUANT: the overlap hub.
            //   1. Store the PREVIOUS core's captured result (if any)
            //   2. Launch dequant for the CURRENT core (core_cnt_q)
            //   3. If more cores: advance core_cnt, start gathering -> overlap
            //      If last core: go to WAIT_DEQUANT
            // -----------------------------------------------------------------
            SFU_DEQUANT: begin
                // 1. Store previous core's result
                if (has_prev_result_q) begin
                    dequant_buf_d[dequant_core_q] = dequant_result_q;
                    tile_classifier_valid         = quant_profiling_enable_i;
                end

                // 2. Launch dequant for current core
                dequant_valid     = 1'b1;
                dequant_core_d    = core_cnt_q;
                has_prev_result_d = 1'b0; // new dequant in-flight, no result yet

                // 3. Advance
                if (has_next_core) begin
                    // Overlap: start gathering next core while dequant runs
                    core_cnt_d   = next_active_core;
                    gather_cnt_d = '0;
                    state_d      = SFU_GATHER;
                end else begin
                    // Last core: wait for this dequant to finish
                    state_d = SFU_WAIT_DEQUANT;
                end
            end

            SFU_WAIT_DEQUANT: begin
                // Last core: wait for dequant pipeline to complete
                if (dequant_done) begin
                    // dequant_result captured by auto-capture
                    state_d = SFU_CAPTURE;
                end
            end

            SFU_CAPTURE: begin
                // Store last core's result + feed classifier
                dequant_buf_d[dequant_core_q] = dequant_result_q;
                tile_classifier_valid         = quant_profiling_enable_i;
                has_prev_result_d             = 1'b0;
                state_d                       = SFU_TREE_START;
            end

            SFU_TREE_START: begin
                tree_valid = 1'b1;
                state_d    = SFU_TREE_WAIT;
            end

            SFU_TREE_WAIT: begin
                if (tree_done) begin
                    state_d = SFU_DONE;
                end
            end

            SFU_DONE: begin
                sfu_done_o = 1'b1;
                state_d    = SFU_IDLE;
            end

            default: begin
                state_d = SFU_IDLE;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------

    // core_idx_o follows the gather target for wrapper SRAM demux
    assign core_idx_o   = core_cnt_q;
    assign acc_result_o = tree_result;

    // Classifier core index: the core whose result is being stored
    assign classifier_core_idx = dequant_core_q;

    // -------------------------------------------------------------------------
    // SRAM address generation
    // -------------------------------------------------------------------------

    assign gather_max    = dequant_type_sel_i ? 3'd5 : 3'd2;
    assign scale_vec_sel = scale_vec_i[core_cnt_q];

    always_comb begin
        if (dequant_type_sel_i) begin
            if (gather_cnt_q[0]) begin
                gather_addr = hi_addr_i + AXI_ADDR_WIDTH'(gather_cnt_q[2:1]);
            end else begin
                gather_addr = base_addr_i + AXI_ADDR_WIDTH'(gather_cnt_q[2:1]);
            end
        end else begin
            gather_addr = base_addr_i + AXI_ADDR_WIDTH'(gather_cnt_q);
        end
    end

    // -------------------------------------------------------------------------
    // SRAM port outputs
    // -------------------------------------------------------------------------

    always_comb begin
        core_req_o  = 1'b0;
        core_addr_o = '0;

        if (state_q == SFU_GATHER) begin
            core_req_o  = 1'b1;
            core_addr_o = gather_addr;
        end
    end

    assign core_we_o    = 1'b0;
    assign core_wdata_o = '0;

    // -------------------------------------------------------------------------
    // Staging registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i) begin
        lo_staging_q <= lo_staging_d;
        hi_staging_q <= hi_staging_d;
    end

    always_comb begin
        lo_staging_d = lo_staging_q;
        hi_staging_d = hi_staging_q;

        if (state_q == SFU_GATHER && gather_cnt_q > 0) begin
            if (dequant_type_sel_i) begin
                if (!gather_cnt_q[0]) begin
                    hi_staging_d[gather_cnt_q[2:1]-1] = core_rdata_i;
                end else begin
                    lo_staging_d[gather_cnt_q[2:1]] = core_rdata_i;
                end
            end else begin
                lo_staging_d[gather_cnt_q-1] = core_rdata_i;
            end
        end

        if (state_q == SFU_GATHER_LAST) begin
            if (dequant_type_sel_i) begin
                hi_staging_d[2] = core_rdata_i;
            end else begin
                lo_staging_d[2] = core_rdata_i;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Vector operand register
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i) begin
        vec_op_q <= vec_op_d;
    end

    always_comb begin
        vec_op_d = vec_op_q;
        lo_final = '0;
        hi_final = '0;

        if (state_q == SFU_GATHER_LAST) begin
            lo_final = {lo_staging_d[2], lo_staging_d[1], lo_staging_d[0]};
            hi_final = {hi_staging_d[2], hi_staging_d[1], hi_staging_d[0]};

            for (int k = 0; k < VLEN; k++) begin
                if (dequant_type_sel_i) begin
                    vec_op_d[k] = {hi_final[k*12+:4], lo_final[k*12+:12]};
                end else begin
                    vec_op_d[k] = {4'b0, lo_final[k*12+:12]};
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Dequantization Lane
    // -------------------------------------------------------------------------

    sfu_dequant_lane #(
        .VLEN      (VLEN),
        .ELEM_WIDTH(ELEM_WIDTH)
    ) i_sfu_dequant_lane (
        .clk_i           (clk_i),
        .rst_ni          (rst_ni),
        .valid_i         (dequant_valid),
        .ready_o         (),
        .done_o          (dequant_done),
        .vec_op_i        (vec_op_q),
        .scale_vec_i     (scale_vec_sel),
        .dequant_type_i  (dequant_type_sel_i),
        .dequant_result_o(dequant_result)
    );

    // -------------------------------------------------------------------------
    // BF16 Addition Tree
    // -------------------------------------------------------------------------

    sfu_acc_tree #(
        .VLEN      (VLEN),
        .ELEM_WIDTH(ELEM_WIDTH),
        .N_INPUTS  (N_CORES)
    ) i_sfu_acc_tree (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .valid_i   (tree_valid),
        .ready_o   (tree_ready),
        .done_o    (tree_done),
        .operands_i(dequant_buf_q),
        .result_o  (tree_result)
    );

    // -------------------------------------------------------------------------
    // Tile Classifier
    // -------------------------------------------------------------------------

    sfu_tile_classifier #(
        .VLEN      (VLEN),
        .ELEM_WIDTH(ELEM_WIDTH)
    ) i_sfu_tile_classifier (
        .clk_i                (clk_i),
        .rst_ni               (rst_ni),
        .clear_i              (tile_classifier_clear_i),
        .valid_i              (tile_classifier_valid),
        .dequant_result_i     (dequant_result_q),
        .core_idx_i           (classifier_core_idx),
        .last_token_i         (last_token_i),
        .spread_threshold_i   (spread_threshold_i),
        .tile_decision_o      (tile_decision_o),
        .tile_decision_valid_o(tile_decision_valid_o)
    );

endmodule
