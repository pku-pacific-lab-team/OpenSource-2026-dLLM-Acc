//-----------------------------------------------------------------------------
// File: dllm_acc_wrapper.sv
// Date Created: 2026-04-12
// Description: Top-level wrapper for the dLLM accelerator.
//              Phase 1: compute subsystem integration.
//              Phase 2: SFU integration, one-wave coupled execution.
//-----------------------------------------------------------------------------

`include "address_map.svh"

module dllm_acc_wrapper #(
    parameter integer AXI_ADDR_WIDTH = 64,
    parameter integer AXI_DATA_WIDTH = 64,
    parameter integer N_CORES        = 16,
    parameter integer CORE_CFG_WIDTH = 42,
    parameter integer N_SFUS         = 4,
    parameter integer CORES_PER_SFU  = 4,
    parameter integer VLEN           = 16,
    parameter integer ELEM_WIDTH     = 16,
    parameter integer SFU_CFG_WIDTH  = 32,
    parameter integer RESULT_DEPTH   = 64
) (
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      axi_req_i,
    input  logic                      axi_we_i,
    input  logic [AXI_ADDR_WIDTH-1:0] axi_addr_i,
    input  logic [AXI_DATA_WIDTH-1:0] axi_wdata_i,
    output logic [AXI_DATA_WIDTH-1:0] axi_rdata_o
);

    // -------------------------------------------------------------------------
    // Local parameters
    // -------------------------------------------------------------------------

    localparam integer CORE_SEL_WIDTH = (N_CORES > 1) ? $clog2(N_CORES) : 1;
    localparam integer SFU_ACC_WIDTH = VLEN * ELEM_WIDTH;
    localparam integer SCALE_VEC_WIDTH = CORES_PER_SFU * VLEN * ELEM_WIDTH;
    localparam integer RESULT_ADDR_WIDTH = $clog2(RESULT_DEPTH);
    localparam integer RESULT_WORDS_PER_ENTRY = SFU_ACC_WIDTH / AXI_DATA_WIDTH;

    // -------------------------------------------------------------------------
    // Assertions
    // -------------------------------------------------------------------------

    initial begin
        if (N_CORES != 16) begin
            $fatal(1, "dllm_acc_wrapper only supports N_CORES=16 because cache_PE_accelerator has flat 16-core ports");
        end
        if (N_SFUS * CORES_PER_SFU != N_CORES) begin
            $fatal(1, "dllm_acc_wrapper: N_SFUS * CORES_PER_SFU must equal N_CORES");
        end
    end

    // -------------------------------------------------------------------------
    // Internal signals: cache_PE_acc_cfg <-> wrapper
    // -------------------------------------------------------------------------

    logic                                          cfg_core_req;
    logic                                          cfg_core_we;
    logic [AXI_ADDR_WIDTH-1:0]                     cfg_core_addr;
    logic [CORE_SEL_WIDTH-1:0]                     cfg_core_sel;
    logic [AXI_DATA_WIDTH-1:0]                     cfg_core_rdata;
    logic [AXI_DATA_WIDTH-1:0]                     cfg_core_wdata;
    logic [       N_CORES-1:0][CORE_CFG_WIDTH-1:0] cache_pe_csr_cfg;
    logic [       N_CORES-1:0]                     cache_pe_cal_en;
    logic [       N_CORES-1:0]                     cache_pe_w_load_en;
    logic [       N_CORES-1:0][               1:0] cache_pe_csr_flag;
    logic [AXI_DATA_WIDTH-1:0]                     cache_pe_cfg_rdata;
    logic                                          core_data_read;
    logic                                          core_cfg_read;
    logic                                          all_cal_done;

    // -------------------------------------------------------------------------
    // Internal signals: core SRAM arrays
    // -------------------------------------------------------------------------

    // External (CPU) path -- from cfg decode
    logic [       N_CORES-1:0]                     ext_core_req;
    logic [       N_CORES-1:0]                     ext_core_we;
    logic [       N_CORES-1:0][AXI_ADDR_WIDTH-1:0] ext_core_addr;
    logic [       N_CORES-1:0][AXI_DATA_WIDTH-1:0] ext_core_wdata;

    // SFU path -- from SFU SRAM routing
    logic [       N_CORES-1:0]                     sfu_core_req;
    logic [       N_CORES-1:0]                     sfu_core_we;
    logic [       N_CORES-1:0][AXI_ADDR_WIDTH-1:0] sfu_core_addr;
    logic [       N_CORES-1:0][AXI_DATA_WIDTH-1:0] sfu_core_wdata;

    // Muxed path -- to accelerator
    logic [       N_CORES-1:0]                     core_axi_req;
    logic [       N_CORES-1:0]                     core_axi_we;
    logic [       N_CORES-1:0][AXI_ADDR_WIDTH-1:0] core_axi_addr;
    logic [       N_CORES-1:0][AXI_DATA_WIDTH-1:0] core_axi_wdata;
    logic [       N_CORES-1:0][AXI_DATA_WIDTH-1:0] core_axi_rdata;

    logic [CORE_SEL_WIDTH-1:0]                     cfg_core_sel_q;

    // -------------------------------------------------------------------------
    // Internal signals: SFU subsystem
    // -------------------------------------------------------------------------

    logic                                          sfu_active;
    logic                                          wave_en;
    logic                                          wave_done;
    logic                                          loop_en;
    logic [       N_CORES-1:0]                     cal_en_retrigger;
    logic [       N_CORES-1:0]                     cal_en_merged;
    logic [31:0] loop_count_d, loop_count_q;

    logic [               N_SFUS-1:0][         SFU_CFG_WIDTH-1:0]                        sfu_cfg_regs;
    logic [               N_SFUS-1:0][       SCALE_VEC_WIDTH-1:0]                        sfu_scale_vec;

    logic [               N_SFUS-1:0]                                                    sfu_start;
    logic [               N_SFUS-1:0]                                                    sfu_done;
    logic [       AXI_ADDR_WIDTH-1:0]                                                    ctrl_base_addr;
    logic [       AXI_ADDR_WIDTH-1:0]                                                    ctrl_hi_addr;

    logic [               N_SFUS-1:0]                                                    ctrl_dequant_type_sel;
    logic [               N_SFUS-1:0]                                                    ctrl_quant_profiling_enable;
    logic [               N_SFUS-1:0][                       7:0]                        ctrl_spread_threshold;
    logic [               N_SFUS-1:0]                                                    ctrl_last_token;
    logic [               N_SFUS-1:0][         CORES_PER_SFU-1:0]                        ctrl_core_mask;

    // Per-SFU core index output (from SFU gather FSM, for demux)
    logic [               N_SFUS-1:0][$clog2(CORES_PER_SFU)-1:0]                        sfu_core_idx;

    logic [               N_SFUS-1:0][         SFU_ACC_WIDTH-1:0]                        sfu_acc_result;

    // SFU SRAM port signals (per SFU, before demux)
    logic [               N_SFUS-1:0]                                                    sfu_raw_req;
    logic [               N_SFUS-1:0]                                                    sfu_raw_we;
    logic [               N_SFUS-1:0][        AXI_ADDR_WIDTH-1:0]                        sfu_raw_addr;
    logic [               N_SFUS-1:0][        AXI_DATA_WIDTH-1:0]                        sfu_raw_wdata;
    logic [               N_SFUS-1:0][        AXI_DATA_WIDTH-1:0]                        sfu_raw_rdata;

    // Tile classifier
    logic [               N_SFUS-1:0][         CORES_PER_SFU-1:0]                        tile_decision;
    logic [               N_SFUS-1:0][         CORES_PER_SFU-1:0]                        tile_decision_valid;
    logic [               N_SFUS-1:0]                                                    tile_clr;

    // Result buffer
    logic [               N_SFUS-1:0]                                                    result_wr_en;
    logic [    RESULT_ADDR_WIDTH-1:0]                                                    result_wr_addr;
    logic [               N_SFUS-1:0][         SFU_ACC_WIDTH-1:0]                        result_wr_data;
    logic [               N_SFUS-1:0][RESULT_WORDS_PER_ENTRY-1:0]                        result_buf_req;
    logic [               N_SFUS-1:0][RESULT_WORDS_PER_ENTRY-1:0]                        result_buf_we;
    logic [               N_SFUS-1:0][RESULT_WORDS_PER_ENTRY-1:0][RESULT_ADDR_WIDTH-1:0] result_buf_addr;
    logic [               N_SFUS-1:0][RESULT_WORDS_PER_ENTRY-1:0][   AXI_DATA_WIDTH-1:0] result_buf_wdata;
    logic [               N_SFUS-1:0][RESULT_WORDS_PER_ENTRY-1:0][   AXI_DATA_WIDTH-1:0] result_buf_rdata;

    // Result buffer CPU write path (buffer lives in wrapper)
    logic                                                                                result_cpu_wr_req;
    logic [       $clog2(N_SFUS)-1:0]                                                    result_cpu_wr_sfu_sel;
    logic [    RESULT_ADDR_WIDTH-1:0]                                                    result_cpu_wr_token;
    logic [                      1:0]                                                    result_cpu_wr_word;
    logic [       AXI_DATA_WIDTH-1:0]                                                    result_cpu_wr_data;
    logic [       AXI_ADDR_WIDTH-1:0]                                                    result_cpu_wr_offset;

    // Result buffer read path (from sfu_cfg)
    logic                                                                                result_rd_req;
    logic [       $clog2(N_SFUS)-1:0]                                                    result_rd_sfu_sel;
    logic [    RESULT_ADDR_WIDTH-1:0]                                                    result_rd_token;
    logic [                      1:0]                                                    result_rd_word;
    logic [       AXI_DATA_WIDTH-1:0]                                                    result_rd_data;
    logic [       $clog2(N_SFUS)-1:0]                                                    result_rd_sfu_sel_q;
    logic [                      1:0]                                                    result_rd_word_q;

    // sfu_cfg rdata
    logic [       AXI_DATA_WIDTH-1:0]                                                    sfu_cfg_rdata;
    logic                                                                                sfu_cfg_read;

    // Test mode signals
    logic                                                                                test_start;
    logic                                                                                test_mode;

    // Test mode: per-SFU flat read counters for result buffer as SFU input
    logic [               N_SFUS-1:0]                                                    test_rd_tick;
    logic [               N_SFUS-1:0][                       7:0]                        test_rd_cnt_d;
    logic [               N_SFUS-1:0][                       7:0]                        test_rd_cnt_q;
    logic [               N_SFUS-1:0][                       1:0]                        test_rd_word_q;

    // Registered SFU core index for rdata mux (one per SFU)
    logic [               N_SFUS-1:0][ $clog2(CORES_PER_SFU)-1:0]                        sfu_core_idx_q;

    // Per-SFU gated clocks
    logic [               N_SFUS-1:0]                                                    sfu_gclk;

    // -------------------------------------------------------------------------
    // CPU result-buffer write decode
    // -------------------------------------------------------------------------

    assign result_cpu_wr_req     = axi_req_i && axi_we_i && (axi_addr_i >= `SFU_RESULT_BASE_ADDR) && (axi_addr_i <= `SFU_RESULT_END_ADDR);
    assign result_cpu_wr_offset  = axi_addr_i - `SFU_RESULT_BASE_ADDR;
    assign result_cpu_wr_sfu_sel = result_cpu_wr_offset[12:11];
    assign result_cpu_wr_token   = result_cpu_wr_offset[10:5];
    assign result_cpu_wr_word    = result_cpu_wr_offset[4:3];
    assign result_cpu_wr_data    = axi_wdata_i;

    // -------------------------------------------------------------------------
    // cache_PE_acc_cfg: AXI decode + core CSR registers
    // -------------------------------------------------------------------------

    cache_PE_acc_cfg #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .N_CORES       (N_CORES),
        .CORE_CFG_WIDTH(CORE_CFG_WIDTH)
    ) i_cache_pe_acc_cfg (
        .clk_i           (clk),
        .rst_ni          (rst_n),
        .axi_req_i       (axi_req_i),
        .axi_we_i        (axi_we_i),
        .axi_addr_i      (axi_addr_i),
        .axi_wdata_i     (axi_wdata_i),
        .cfg_rdata_o     (cache_pe_cfg_rdata),
        .core_data_read_o(core_data_read),
        .core_cfg_read_o (core_cfg_read),
        .core_req_o      (cfg_core_req),
        .core_we_o       (cfg_core_we),
        .core_addr_o     (cfg_core_addr),
        .core_sel_o      (cfg_core_sel),
        .core_wdata_o    (cfg_core_wdata),
        .core_rdata_i    (cfg_core_rdata),
        .csr_cfg_o       (cache_pe_csr_cfg),
        .cal_en_o        (cache_pe_cal_en),
        .w_load_en_o     (cache_pe_w_load_en),
        .csr_flag_i      (cache_pe_csr_flag),
        .all_cal_done_o  (all_cal_done)
    );

    // -------------------------------------------------------------------------
    // sfu_cfg: SFU configuration registers
    // -------------------------------------------------------------------------

    sfu_cfg #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .N_SFUS        (N_SFUS),
        .CORES_PER_SFU (CORES_PER_SFU),
        .VLEN          (VLEN),
        .ELEM_WIDTH    (ELEM_WIDTH),
        .SFU_CFG_WIDTH (SFU_CFG_WIDTH),
        .RESULT_DEPTH  (RESULT_DEPTH)
    ) i_sfu_cfg (
        .clk_i                (clk),
        .rst_ni               (rst_n),
        .axi_req_i            (axi_req_i),
        .axi_we_i             (axi_we_i),
        .axi_addr_i           (axi_addr_i),
        .axi_wdata_i          (axi_wdata_i),
        .cfg_rdata_o          (sfu_cfg_rdata),
        .sfu_cfg_read_o       (sfu_cfg_read),
        .sfu_cfg_o            (sfu_cfg_regs),
        .scale_vec_o          (sfu_scale_vec),
        .wave_en_o            (wave_en),
        .wave_done_i          (wave_done),
        .sfu_active_i         (sfu_active),
        .test_start_o         (test_start),
        .loop_en_o            (loop_en),
        .loop_count_i         (loop_count_q),
        .tile_decision_i      (tile_decision),
        .tile_decision_valid_i(tile_decision_valid),
        .tile_clr_o           (tile_clr),
        .result_rd_req_o      (result_rd_req),
        .result_rd_sfu_sel_o  (result_rd_sfu_sel),
        .result_rd_token_o    (result_rd_token),
        .result_rd_word_o     (result_rd_word),
        .result_rd_data_i     (result_rd_data)
    );

    // -------------------------------------------------------------------------
    // sfu_ctrl: sequencer FSM
    // -------------------------------------------------------------------------

    sfu_ctrl #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .N_SFUS        (N_SFUS),
        .CORES_PER_SFU (CORES_PER_SFU),
        .VLEN          (VLEN),
        .ELEM_WIDTH    (ELEM_WIDTH),
        .SFU_CFG_WIDTH (SFU_CFG_WIDTH),
        .RESULT_DEPTH  (RESULT_DEPTH)
    ) i_sfu_ctrl (
        .clk_i                   (clk),
        .rst_ni                  (rst_n),
        .wave_en_i               (wave_en),
        .test_start_i            (test_start),
        .all_cal_done_i          (all_cal_done),
        .loop_en_i               (loop_en),
        .sfu_cfg_i               (sfu_cfg_regs),
        .sfu_start_o             (sfu_start),
        .sfu_done_i              (sfu_done),
        .base_addr_o             (ctrl_base_addr),
        .hi_addr_o               (ctrl_hi_addr),
        .dequant_type_sel_o      (ctrl_dequant_type_sel),
        .quant_profiling_enable_o(ctrl_quant_profiling_enable),
        .spread_threshold_o      (ctrl_spread_threshold),
        .last_token_o            (ctrl_last_token),
        .core_mask_o             (ctrl_core_mask),
        .acc_result_i            (sfu_acc_result),
        .result_wr_en_o          (result_wr_en),
        .result_wr_addr_o        (result_wr_addr),
        .result_wr_data_o        (result_wr_data),
        .cal_en_retrigger_o      (cal_en_retrigger),
        .sfu_active_o            (sfu_active),
        .wave_done_o             (wave_done),
        .test_mode_o             (test_mode)
    );

    // -------------------------------------------------------------------------
    // External (CPU) core SRAM request fanout
    // -------------------------------------------------------------------------

    always_comb begin
        for (int i = 0; i < N_CORES; i++) begin
            ext_core_req[i]   = cfg_core_req && (cfg_core_sel == CORE_SEL_WIDTH'(i));
            ext_core_we[i]    = cfg_core_we;
            ext_core_addr[i]  = cfg_core_addr;
            ext_core_wdata[i] = cfg_core_wdata;
        end
    end

    // -------------------------------------------------------------------------
    // SFU SRAM routing: per-SFU 1:4 demux + registered 4:1 rdata mux
    // In test mode, SFU reads come from the result buffer, not core SRAM,
    // so the 1:4 demux is suppressed (no core requests generated).
    // -------------------------------------------------------------------------

    always_comb begin
        for (int i = 0; i < N_CORES; i++) begin
            sfu_core_req[i]   = 1'b0;
            sfu_core_we[i]    = 1'b0;
            sfu_core_addr[i]  = '0;
            sfu_core_wdata[i] = '0;
        end

        // In test mode, suppress SFU->core SRAM routing
        if (!test_mode) begin
            for (int s = 0; s < N_SFUS; s++) begin
                for (int c = 0; c < CORES_PER_SFU; c++) begin
                    if (sfu_core_idx[s] == $clog2(CORES_PER_SFU)'(c)) begin
                        sfu_core_req[s*CORES_PER_SFU+c]   = sfu_raw_req[s];
                        sfu_core_we[s*CORES_PER_SFU+c]    = sfu_raw_we[s];
                        sfu_core_addr[s*CORES_PER_SFU+c]  = sfu_raw_addr[s];
                        sfu_core_wdata[s*CORES_PER_SFU+c] = sfu_raw_wdata[s];
                    end
                end
            end
        end
    end

    // Registered core index per SFU (for rdata mux alignment)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int s = 0; s < N_SFUS; s++) begin
                sfu_core_idx_q[s] <= '0;
            end
        end else begin
            for (int s = 0; s < N_SFUS; s++) begin
                sfu_core_idx_q[s] <= sfu_core_idx[s];
            end
        end
    end

    // 4:1 rdata mux back to each SFU
    // In test mode, reads come from the result buffer instead of core SRAM
    always_comb begin
        for (int s = 0; s < N_SFUS; s++) begin
            if (test_mode) begin
                sfu_raw_rdata[s] = result_buf_rdata[s][test_rd_word_q[s]];
            end else begin
                sfu_raw_rdata[s] = core_axi_rdata[s*CORES_PER_SFU+sfu_core_idx_q[s]];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Test mode: per-SFU flat read counters for result-buffer-as-SFU-input
    // -------------------------------------------------------------------------

    // Each SFU has its own counter so per-SFU core_mask differences work correctly
    always_comb begin
        for (int s = 0; s < N_SFUS; s++) begin
            test_rd_tick[s] = test_mode && sfu_raw_req[s];
        end
    end

    always_comb begin
        for (int s = 0; s < N_SFUS; s++) begin
            test_rd_cnt_d[s] = test_rd_cnt_q[s];
            if (test_start) begin
                test_rd_cnt_d[s] = '0;
            end else if (test_rd_tick[s]) begin
                test_rd_cnt_d[s] = test_rd_cnt_q[s] + 8'd1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_rd_cnt_q  <= '0;
            test_rd_word_q <= '0;
        end else begin
            for (int s = 0; s < N_SFUS; s++) begin
                test_rd_cnt_q[s]  <= test_rd_cnt_d[s];
                // Register the word index for 1-cycle SRAM read latency alignment
                test_rd_word_q[s] <= test_rd_cnt_q[s][1:0];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Core SRAM mux: 2:1 per core (inline)
    // -------------------------------------------------------------------------

    always_comb begin
        for (int i = 0; i < N_CORES; i++) begin
            core_axi_req[i]   = sfu_active ? sfu_core_req[i] : ext_core_req[i];
            core_axi_we[i]    = sfu_active ? sfu_core_we[i] : ext_core_we[i];
            core_axi_addr[i]  = sfu_active ? sfu_core_addr[i] : ext_core_addr[i];
            core_axi_wdata[i] = sfu_active ? sfu_core_wdata[i] : ext_core_wdata[i];
        end
    end

    // -------------------------------------------------------------------------
    // Registered core read selection (for external CPU path rdata mux)
    // -------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_core_sel_q <= '0;
        end else begin
            cfg_core_sel_q <= cfg_core_sel;
        end
    end

    assign cfg_core_rdata = core_axi_rdata[cfg_core_sel_q];

    // -------------------------------------------------------------------------
    // 4 * special_function_unit instances
    // -------------------------------------------------------------------------

    generate
        for (genvar s = 0; s < N_SFUS; s++) begin : gen_sfu
            // Per-SFU clock gate: sfu_cfg bit[31] = 1 gates the clock off
            gclk_unit i_sfu_cg (
                .clk_i    (clk),
                .en_i     (~sfu_cfg_regs[s][31]),
                .test_en_i(1'b0),
                .gclk_o   (sfu_gclk[s])
            );

            special_function_unit #(
                .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
                .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
                .VLEN          (VLEN),
                .ELEM_WIDTH    (ELEM_WIDTH),
                .N_CORES       (CORES_PER_SFU)
            ) i_sfu (
                .clk_i                   (sfu_gclk[s]),
                .rst_ni                  (rst_n),
                .core_req_o              (sfu_raw_req[s]),
                .core_we_o               (sfu_raw_we[s]),
                .core_addr_o             (sfu_raw_addr[s]),
                .core_wdata_o            (sfu_raw_wdata[s]),
                .core_rdata_i            (sfu_raw_rdata[s]),
                .quant_profiling_enable_i(ctrl_quant_profiling_enable[s]),
                .dequant_type_sel_i      (ctrl_dequant_type_sel[s]),
                .base_addr_i             (ctrl_base_addr),
                .hi_addr_i               (ctrl_hi_addr),
                .scale_vec_i             (sfu_scale_vec[s]),
                .spread_threshold_i      (ctrl_spread_threshold[s]),
                .sfu_start_i             (sfu_start[s]),
                .core_mask_i             (ctrl_core_mask[s]),
                .tile_classifier_clear_i (tile_clr[s]),
                .last_token_i            (ctrl_last_token[s]),
                .sfu_done_o              (sfu_done[s]),
                .acc_result_o            (sfu_acc_result[s]),
                .core_idx_o              (sfu_core_idx[s]),
                .tile_decision_o         (tile_decision[s]),
                .tile_decision_valid_o   (tile_decision_valid[s])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Result buffer: 4 SFUs * 4 SRAM macros
    // -------------------------------------------------------------------------

    generate
        for (genvar s = 0; s < N_SFUS; s++) begin : gen_result_sfu
            for (genvar w = 0; w < RESULT_WORDS_PER_ENTRY; w++) begin : gen_result_word
                // Arbitrate: test read (highest priority), sequencer write,
                // CPU write, CPU read
                always_comb begin
                    result_buf_req[s][w]   = 1'b0;
                    result_buf_we[s][w]    = 1'b0;
                    result_buf_addr[s][w]  = '0;
                    result_buf_wdata[s][w] = '0;

                    // Test mode: SFU reads from result buffer using per-SFU flat counter
                    if (test_mode && test_rd_tick[s] && (test_rd_cnt_q[s][1:0] == 2'(w))) begin
                        result_buf_req[s][w]  = 1'b1;
                        result_buf_addr[s][w] = test_rd_cnt_q[s][7:2];
                    end else if (result_wr_en[s]) begin
                        result_buf_req[s][w]   = 1'b1;
                        result_buf_we[s][w]    = 1'b1;
                        result_buf_addr[s][w]  = result_wr_addr;
                        result_buf_wdata[s][w] = result_wr_data[s][(w+1)*AXI_DATA_WIDTH-1-:AXI_DATA_WIDTH];
                    end else if (result_cpu_wr_req && (result_cpu_wr_sfu_sel == $clog2(N_SFUS)'(s)) && (result_cpu_wr_word == $bits(result_cpu_wr_word)'(w))) begin
                        result_buf_req[s][w]   = 1'b1;
                        result_buf_we[s][w]    = 1'b1;
                        result_buf_addr[s][w]  = result_cpu_wr_token;
                        result_buf_wdata[s][w] = result_cpu_wr_data;
                    end else if (result_rd_req && (result_rd_sfu_sel == $clog2(N_SFUS)'(s)) && (result_rd_word == $bits(result_rd_word)'(w))) begin
                        result_buf_req[s][w]  = 1'b1;
                        result_buf_addr[s][w] = result_rd_token;
                    end
                end

                sram_64x64 i_result_buf (
                    .clk_i         (clk),
                    .chip_enable_i (result_buf_req[s][w]),
                    .write_enable_i(result_buf_we[s][w]),
                    .addr_i        (result_buf_addr[s][w]),
                    .write_data_i  (result_buf_wdata[s][w]),
                    .read_data_o   (result_buf_rdata[s][w])
                );
            end
        end
    endgenerate

    // Result buffer read data mux (select by sfu and word, registered from previous cycle)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_rd_sfu_sel_q <= '0;
            result_rd_word_q    <= '0;
        end else begin
            result_rd_sfu_sel_q <= result_rd_sfu_sel;
            result_rd_word_q    <= result_rd_word;
        end
    end

    assign result_rd_data = result_buf_rdata[result_rd_sfu_sel_q][result_rd_word_q];

    // -------------------------------------------------------------------------
    // cal_en merge: CSR enable with loop retrigger pulse override
    // -------------------------------------------------------------------------

    always_comb begin
        cal_en_merged = cache_pe_cal_en;
        if (cal_en_retrigger != '0) begin
            // If cal_en_retrigger is high for any core, we need to set the per-core cal_en to low so the cal_done_q signal can be reset to low.
            // After this cycle, cal_en_retrigger will go back to low, and the per-core cal_en will go back to the value from cache_pe_cal_en (which should be high if we are in SFU loop mode).
            cal_en_merged = ~cal_en_retrigger;
        end
    end

    // -------------------------------------------------------------------------
    // Loop counter: increments on wave_done when loop_en is set
    // -------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            loop_count_q <= '0;
        end else begin
            loop_count_q <= loop_count_d;
        end
    end

    always_comb begin
        loop_count_d = loop_count_q;
        if (axi_req_i && axi_we_i && (axi_addr_i == `SFU_LOOP_EN_ADDR)) begin
            loop_count_d = '0;
        end else if (wave_done && loop_en) begin
            loop_count_d = loop_count_q + 32'd1;
        end
    end

    // -------------------------------------------------------------------------
    // Top-level rdata mux (3:1, registered selects from previous cycle)
    // -------------------------------------------------------------------------

    always_comb begin
        axi_rdata_o = '0;

        if (core_data_read) begin
            axi_rdata_o = cfg_core_rdata;
        end else if (core_cfg_read) begin
            axi_rdata_o = cache_pe_cfg_rdata;
        end else if (sfu_cfg_read) begin
            axi_rdata_o = sfu_cfg_rdata;
        end
    end

    // -------------------------------------------------------------------------
    // 16-core cache PE accelerator
    // -------------------------------------------------------------------------

    cache_PE_accelerator i_cache_pe_accelerator (
        .clk  (clk),
        .rst_n(rst_n),

        .core0_axi_req_i  (core_axi_req[0]),
        .core0_axi_we_i   (core_axi_we[0]),
        .core0_axi_addr_i (core_axi_addr[0]),
        .core0_axi_wdata_i(core_axi_wdata[0]),
        .core0_axi_rdata_o(core_axi_rdata[0]),
        .core0_csr_en_i   ({cal_en_merged[0], cache_pe_w_load_en[0]}),
        .core0_csr_cfg_i  (cache_pe_csr_cfg[0]),
        .core0_csr_flag_o (cache_pe_csr_flag[0]),

        .core1_axi_req_i  (core_axi_req[1]),
        .core1_axi_we_i   (core_axi_we[1]),
        .core1_axi_addr_i (core_axi_addr[1]),
        .core1_axi_wdata_i(core_axi_wdata[1]),
        .core1_axi_rdata_o(core_axi_rdata[1]),
        .core1_csr_en_i   ({cal_en_merged[1], cache_pe_w_load_en[1]}),
        .core1_csr_cfg_i  (cache_pe_csr_cfg[1]),
        .core1_csr_flag_o (cache_pe_csr_flag[1]),

        .core2_axi_req_i  (core_axi_req[2]),
        .core2_axi_we_i   (core_axi_we[2]),
        .core2_axi_addr_i (core_axi_addr[2]),
        .core2_axi_wdata_i(core_axi_wdata[2]),
        .core2_axi_rdata_o(core_axi_rdata[2]),
        .core2_csr_en_i   ({cal_en_merged[2], cache_pe_w_load_en[2]}),
        .core2_csr_cfg_i  (cache_pe_csr_cfg[2]),
        .core2_csr_flag_o (cache_pe_csr_flag[2]),

        .core3_axi_req_i  (core_axi_req[3]),
        .core3_axi_we_i   (core_axi_we[3]),
        .core3_axi_addr_i (core_axi_addr[3]),
        .core3_axi_wdata_i(core_axi_wdata[3]),
        .core3_axi_rdata_o(core_axi_rdata[3]),
        .core3_csr_en_i   ({cal_en_merged[3], cache_pe_w_load_en[3]}),
        .core3_csr_cfg_i  (cache_pe_csr_cfg[3]),
        .core3_csr_flag_o (cache_pe_csr_flag[3]),

        .core4_axi_req_i  (core_axi_req[4]),
        .core4_axi_we_i   (core_axi_we[4]),
        .core4_axi_addr_i (core_axi_addr[4]),
        .core4_axi_wdata_i(core_axi_wdata[4]),
        .core4_axi_rdata_o(core_axi_rdata[4]),
        .core4_csr_en_i   ({cal_en_merged[4], cache_pe_w_load_en[4]}),
        .core4_csr_cfg_i  (cache_pe_csr_cfg[4]),
        .core4_csr_flag_o (cache_pe_csr_flag[4]),

        .core5_axi_req_i  (core_axi_req[5]),
        .core5_axi_we_i   (core_axi_we[5]),
        .core5_axi_addr_i (core_axi_addr[5]),
        .core5_axi_wdata_i(core_axi_wdata[5]),
        .core5_axi_rdata_o(core_axi_rdata[5]),
        .core5_csr_en_i   ({cal_en_merged[5], cache_pe_w_load_en[5]}),
        .core5_csr_cfg_i  (cache_pe_csr_cfg[5]),
        .core5_csr_flag_o (cache_pe_csr_flag[5]),

        .core6_axi_req_i  (core_axi_req[6]),
        .core6_axi_we_i   (core_axi_we[6]),
        .core6_axi_addr_i (core_axi_addr[6]),
        .core6_axi_wdata_i(core_axi_wdata[6]),
        .core6_axi_rdata_o(core_axi_rdata[6]),
        .core6_csr_en_i   ({cal_en_merged[6], cache_pe_w_load_en[6]}),
        .core6_csr_cfg_i  (cache_pe_csr_cfg[6]),
        .core6_csr_flag_o (cache_pe_csr_flag[6]),

        .core7_axi_req_i  (core_axi_req[7]),
        .core7_axi_we_i   (core_axi_we[7]),
        .core7_axi_addr_i (core_axi_addr[7]),
        .core7_axi_wdata_i(core_axi_wdata[7]),
        .core7_axi_rdata_o(core_axi_rdata[7]),
        .core7_csr_en_i   ({cal_en_merged[7], cache_pe_w_load_en[7]}),
        .core7_csr_cfg_i  (cache_pe_csr_cfg[7]),
        .core7_csr_flag_o (cache_pe_csr_flag[7]),

        .core8_axi_req_i  (core_axi_req[8]),
        .core8_axi_we_i   (core_axi_we[8]),
        .core8_axi_addr_i (core_axi_addr[8]),
        .core8_axi_wdata_i(core_axi_wdata[8]),
        .core8_axi_rdata_o(core_axi_rdata[8]),
        .core8_csr_en_i   ({cal_en_merged[8], cache_pe_w_load_en[8]}),
        .core8_csr_cfg_i  (cache_pe_csr_cfg[8]),
        .core8_csr_flag_o (cache_pe_csr_flag[8]),

        .core9_axi_req_i  (core_axi_req[9]),
        .core9_axi_we_i   (core_axi_we[9]),
        .core9_axi_addr_i (core_axi_addr[9]),
        .core9_axi_wdata_i(core_axi_wdata[9]),
        .core9_axi_rdata_o(core_axi_rdata[9]),
        .core9_csr_en_i   ({cal_en_merged[9], cache_pe_w_load_en[9]}),
        .core9_csr_cfg_i  (cache_pe_csr_cfg[9]),
        .core9_csr_flag_o (cache_pe_csr_flag[9]),

        .core10_axi_req_i  (core_axi_req[10]),
        .core10_axi_we_i   (core_axi_we[10]),
        .core10_axi_addr_i (core_axi_addr[10]),
        .core10_axi_wdata_i(core_axi_wdata[10]),
        .core10_axi_rdata_o(core_axi_rdata[10]),
        .core10_csr_en_i   ({cal_en_merged[10], cache_pe_w_load_en[10]}),
        .core10_csr_cfg_i  (cache_pe_csr_cfg[10]),
        .core10_csr_flag_o (cache_pe_csr_flag[10]),

        .core11_axi_req_i  (core_axi_req[11]),
        .core11_axi_we_i   (core_axi_we[11]),
        .core11_axi_addr_i (core_axi_addr[11]),
        .core11_axi_wdata_i(core_axi_wdata[11]),
        .core11_axi_rdata_o(core_axi_rdata[11]),
        .core11_csr_en_i   ({cal_en_merged[11], cache_pe_w_load_en[11]}),
        .core11_csr_cfg_i  (cache_pe_csr_cfg[11]),
        .core11_csr_flag_o (cache_pe_csr_flag[11]),

        .core12_axi_req_i  (core_axi_req[12]),
        .core12_axi_we_i   (core_axi_we[12]),
        .core12_axi_addr_i (core_axi_addr[12]),
        .core12_axi_wdata_i(core_axi_wdata[12]),
        .core12_axi_rdata_o(core_axi_rdata[12]),
        .core12_csr_en_i   ({cal_en_merged[12], cache_pe_w_load_en[12]}),
        .core12_csr_cfg_i  (cache_pe_csr_cfg[12]),
        .core12_csr_flag_o (cache_pe_csr_flag[12]),

        .core13_axi_req_i  (core_axi_req[13]),
        .core13_axi_we_i   (core_axi_we[13]),
        .core13_axi_addr_i (core_axi_addr[13]),
        .core13_axi_wdata_i(core_axi_wdata[13]),
        .core13_axi_rdata_o(core_axi_rdata[13]),
        .core13_csr_en_i   ({cal_en_merged[13], cache_pe_w_load_en[13]}),
        .core13_csr_cfg_i  (cache_pe_csr_cfg[13]),
        .core13_csr_flag_o (cache_pe_csr_flag[13]),

        .core14_axi_req_i  (core_axi_req[14]),
        .core14_axi_we_i   (core_axi_we[14]),
        .core14_axi_addr_i (core_axi_addr[14]),
        .core14_axi_wdata_i(core_axi_wdata[14]),
        .core14_axi_rdata_o(core_axi_rdata[14]),
        .core14_csr_en_i   ({cal_en_merged[14], cache_pe_w_load_en[14]}),
        .core14_csr_cfg_i  (cache_pe_csr_cfg[14]),
        .core14_csr_flag_o (cache_pe_csr_flag[14]),

        .core15_axi_req_i  (core_axi_req[15]),
        .core15_axi_we_i   (core_axi_we[15]),
        .core15_axi_addr_i (core_axi_addr[15]),
        .core15_axi_wdata_i(core_axi_wdata[15]),
        .core15_axi_rdata_o(core_axi_rdata[15]),
        .core15_csr_en_i   ({cal_en_merged[15], cache_pe_w_load_en[15]}),
        .core15_csr_cfg_i  (cache_pe_csr_cfg[15]),
        .core15_csr_flag_o (cache_pe_csr_flag[15])
    );

endmodule
