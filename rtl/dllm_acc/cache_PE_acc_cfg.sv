//-----------------------------------------------------------------------------
// File: cache_PE_acc_cfg.sv
// Description: AXI-visible decode, config registers, and status readback for
//              the Phase-1 dLLM accelerator wrapper.
//-----------------------------------------------------------------------------

`include "address_map.svh"

module cache_PE_acc_cfg #(
    parameter integer AXI_ADDR_WIDTH = 64,
    parameter integer AXI_DATA_WIDTH = 64,
    parameter integer N_CORES        = 16,
    parameter integer CORE_CFG_WIDTH = 42
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,
    input  logic                      axi_req_i,
    input  logic                      axi_we_i,
    input  logic [AXI_ADDR_WIDTH-1:0] axi_addr_i,
    input  logic [AXI_DATA_WIDTH-1:0] axi_wdata_i,
    output logic [AXI_DATA_WIDTH-1:0] cfg_rdata_o,
    output logic                      core_data_read_o,
    output logic                      core_cfg_read_o,

    output logic                       core_req_o,
    output logic                       core_we_o,
    output logic [ AXI_ADDR_WIDTH-1:0] core_addr_o,
    output logic [$clog2(N_CORES)-1:0] core_sel_o,
    output logic [ AXI_DATA_WIDTH-1:0] core_wdata_o,
    input  logic [ AXI_DATA_WIDTH-1:0] core_rdata_i,

    output logic [N_CORES-1:0][CORE_CFG_WIDTH-1:0] csr_cfg_o,
    output logic [N_CORES-1:0]                     cal_en_o,
    output logic [N_CORES-1:0]                     w_load_en_o,
    input  logic [N_CORES-1:0][               1:0] csr_flag_i,

    output logic all_cal_done_o
);

    localparam integer CORE_SEL_WIDTH = (N_CORES > 1) ? $clog2(N_CORES) : 1;
    localparam integer AXI_DATA_BYTES = AXI_DATA_WIDTH / 8;
    localparam integer CORE_WORD_ADDR_WIDTH = 11;
    localparam integer CORE_WINDOW_WORDS = 2048;
    localparam integer CORE_STATUS_WORDS = 5;

    localparam integer CORE_WINDOW_BYTES = CORE_WINDOW_WORDS * AXI_DATA_BYTES;
    localparam integer CORE_DATA_WINDOW_BYTES = N_CORES * CORE_WINDOW_BYTES;
    localparam integer CORE_CFG_REGFILE_BYTES = N_CORES * AXI_DATA_BYTES;
    localparam integer CORE_STATUS_WINDOW_BYTES = CORE_STATUS_WORDS * AXI_DATA_BYTES;

    localparam logic [AXI_ADDR_WIDTH-1:0] ADDR_MAP_CACHE_PE_CORE_DATA_END_ADDR = `CACHE_PE_CORE_DATA_END_ADDR;
    localparam logic [AXI_ADDR_WIDTH-1:0] CORE_DATA_WINDOW_LAST_OFFSET = AXI_ADDR_WIDTH'(CORE_DATA_WINDOW_BYTES) - AXI_ADDR_WIDTH'(1);
    localparam logic [AXI_ADDR_WIDTH-1:0] DERIVED_CACHE_PE_CORE_DATA_END_ADDR = `CACHE_PE_CORE_DATA_BASE_ADDR + CORE_DATA_WINDOW_LAST_OFFSET;

    localparam logic [AXI_ADDR_WIDTH-1:0] ADDR_MAP_CACHE_PE_CORE_CFG_REGFILE_END_ADDR = `CACHE_PE_CORE_CFG_REGFILE_END_ADDR;
    localparam logic [AXI_ADDR_WIDTH-1:0] CORE_CFG_REGFILE_LAST_OFFSET = AXI_ADDR_WIDTH'(CORE_CFG_REGFILE_BYTES) - AXI_ADDR_WIDTH'(1);
    localparam logic [AXI_ADDR_WIDTH-1:0] DERIVED_CACHE_PE_CORE_CFG_REGFILE_END_ADDR = `CACHE_PE_CORE_CFG_REGFILE_BASE_ADDR + CORE_CFG_REGFILE_LAST_OFFSET;

    localparam logic [AXI_ADDR_WIDTH-1:0] ADDR_MAP_CACHE_PE_CORE_STATUS_END_ADDR = `CACHE_PE_CORE_STATUS_END_ADDR;
    localparam logic [AXI_ADDR_WIDTH-1:0] CORE_STATUS_WINDOW_LAST_OFFSET = AXI_ADDR_WIDTH'(CORE_STATUS_WINDOW_BYTES) - AXI_ADDR_WIDTH'(1);
    localparam logic [AXI_ADDR_WIDTH-1:0] DERIVED_CACHE_PE_CORE_STATUS_END_ADDR = `CACHE_PE_CORE_STATUS_BASE_ADDR + CORE_STATUS_WINDOW_LAST_OFFSET;

    logic                                                            axi_read_req;
    logic                                                            axi_write_req;
    logic                                                            core_data_window_hit;
    logic                                                            core_cfg_regfile_window_hit;
    logic                                                            core_status_window_hit;
    logic                                                            core_cfg_window_hit;
    logic                                                            sfu_cfg_window_hit;
    logic                                                            core_data_read_req;
    logic                                                            core_cfg_read_req;
    logic [                  AXI_ADDR_WIDTH-1:0]                     core_data_offset;
    logic [                  AXI_ADDR_WIDTH-1:0]                     core_cfg_regfile_offset;
    logic [                  CORE_SEL_WIDTH-1:0]                     core_data_sel;
    logic [            CORE_WORD_ADDR_WIDTH-1:0]                     core_word_addr;
    logic [                  CORE_SEL_WIDTH-1:0]                     core_cfg_idx;
    logic [                         N_CORES-1:0][CORE_CFG_WIDTH-1:0] csr_cfg_d;
    logic [                         N_CORES-1:0][CORE_CFG_WIDTH-1:0] csr_cfg_q;
    logic [                  AXI_DATA_WIDTH-1:0]                     reg_rdata_d;
    logic [                  AXI_DATA_WIDTH-1:0]                     reg_rdata_q;
    logic                                                            core_rdata_sel_q;
    logic                                                            core_cfg_read_q;
    logic [                         N_CORES-1:0]                     cal_done_vec;
    logic [                         N_CORES-1:0]                     w_load_done_vec;
    logic [                         N_CORES-1:0]                     cal_en_d;
    logic [                         N_CORES-1:0]                     cal_en_q;
    logic [                         N_CORES-1:0]                     w_load_en_d;
    logic [                         N_CORES-1:0]                     w_load_en_q;
    logic                                                            all_cal_done;
    logic                                                            all_w_load_done;
    logic [$clog2(N_CORES * AXI_DATA_BYTES)-1:0]                     core_cfg_regfile_word_idx;

    assign axi_read_req                = axi_req_i && !axi_we_i;
    assign axi_write_req               = axi_req_i && axi_we_i;
    assign core_data_window_hit        = (axi_addr_i >= `CACHE_PE_CORE_DATA_BASE_ADDR) && (axi_addr_i <= DERIVED_CACHE_PE_CORE_DATA_END_ADDR);
    assign core_cfg_regfile_window_hit = (axi_addr_i >= `CACHE_PE_CORE_CFG_REGFILE_BASE_ADDR) && (axi_addr_i <= DERIVED_CACHE_PE_CORE_CFG_REGFILE_END_ADDR);
    assign core_status_window_hit      = (axi_addr_i >= `CACHE_PE_CORE_STATUS_BASE_ADDR) && (axi_addr_i <= DERIVED_CACHE_PE_CORE_STATUS_END_ADDR);
    assign core_cfg_window_hit         = core_cfg_regfile_window_hit || core_status_window_hit;
    assign sfu_cfg_window_hit          = (axi_addr_i >= `SFU_CFG_BASE_ADDR) && (axi_addr_i <= `SFU_CFG_END_ADDR);
    assign core_data_read_req          = axi_read_req && core_data_window_hit;
    assign core_cfg_read_req           = axi_read_req && core_cfg_window_hit;

    assign core_req_o                  = axi_req_i && core_data_window_hit;
    assign core_we_o                   = axi_we_i;
    assign core_addr_o                 = {{(AXI_ADDR_WIDTH - CORE_WORD_ADDR_WIDTH) {1'b0}}, core_word_addr};
    assign core_sel_o                  = core_data_sel;
    assign core_wdata_o                = axi_wdata_i;
    assign csr_cfg_o                   = csr_cfg_q;
    assign cal_en_o                    = cal_en_q;
    assign w_load_en_o                 = w_load_en_q;
    assign cfg_rdata_o                 = reg_rdata_q;
    assign core_data_read_o            = core_rdata_sel_q;
    assign core_cfg_read_o             = core_cfg_read_q;
    assign all_cal_done_o              = all_cal_done;
    assign core_cfg_idx                = core_cfg_regfile_word_idx[CORE_SEL_WIDTH-1:0];

    // pragma translate_off
    initial begin
        if (DERIVED_CACHE_PE_CORE_DATA_END_ADDR != ADDR_MAP_CACHE_PE_CORE_DATA_END_ADDR) begin
            $fatal(1, "cache_PE_acc_cfg core-data window mismatch: derived end=%h address_map end=%h", DERIVED_CACHE_PE_CORE_DATA_END_ADDR, ADDR_MAP_CACHE_PE_CORE_DATA_END_ADDR);
        end

        if (DERIVED_CACHE_PE_CORE_CFG_REGFILE_END_ADDR != ADDR_MAP_CACHE_PE_CORE_CFG_REGFILE_END_ADDR) begin
            $fatal(1, "cache_PE_acc_cfg core-cfg regfile mismatch: derived end=%h address_map end=%h", DERIVED_CACHE_PE_CORE_CFG_REGFILE_END_ADDR,
                   ADDR_MAP_CACHE_PE_CORE_CFG_REGFILE_END_ADDR);
        end

        if (DERIVED_CACHE_PE_CORE_STATUS_END_ADDR != ADDR_MAP_CACHE_PE_CORE_STATUS_END_ADDR) begin
            $fatal(1, "cache_PE_acc_cfg core-status window mismatch: derived end=%h address_map end=%h", DERIVED_CACHE_PE_CORE_STATUS_END_ADDR,
                   ADDR_MAP_CACHE_PE_CORE_STATUS_END_ADDR);
        end
    end
    // pragma translate_on

    // -------------------------------------------------------------------------
    // AXI decode and window logic
    // -------------------------------------------------------------------------
    // Region 0: Core data SRAM window
    //   0x3000_0000 - 0x3003_FFFF
    //   Each core owns a 16 KB sub-window. The incoming byte address is
    //   translated into the 11-bit word address expected by cache_PE_core_ctrlr.
    //
    // Region 1a: Per-core config register file
    //   0x4000_0000 - 0x4000_007F
    //   Sixteen 64-bit words, one CSR config payload per core.
    //
    // Region 1b: Core control / status registers
    //   0x4000_0080 - 0x4000_00A7
    //   CAL_START, W_LOAD_START, CAL_DONE, W_LOAD_DONE, and DONE_ALL.
    //
    // Region 2: SFU config / metadata window
    //   0x5000_0000 - 0x5000_02FF
    //   Reserved for Phase 2. Reads return zero and writes are ignored.
    // -------------------------------------------------------------------------

    always_comb begin
        core_data_offset          = '0;
        core_cfg_regfile_offset   = '0;
        core_data_sel             = '0;
        core_word_addr            = '0;
        core_cfg_regfile_word_idx = '0;

        if (core_data_window_hit) begin
            core_data_offset = axi_addr_i - `CACHE_PE_CORE_DATA_BASE_ADDR;
            core_data_sel    = core_data_offset[17:14];
            core_word_addr   = CORE_WORD_ADDR_WIDTH'(core_data_offset >> 3);
        end

        if (core_cfg_regfile_window_hit) begin
            core_cfg_regfile_offset   = axi_addr_i - `CACHE_PE_CORE_CFG_REGFILE_BASE_ADDR;
            core_cfg_regfile_word_idx = $bits(core_cfg_regfile_word_idx)'(core_cfg_regfile_offset >> 3);
        end
    end

    // -------------------------------------------------------------------------
    // Core status aggregation
    // -------------------------------------------------------------------------

    for (genvar core_idx = 0; core_idx < N_CORES; core_idx++) begin : gen_core_status
        assign cal_done_vec[core_idx]    = csr_flag_i[core_idx][0];
        assign w_load_done_vec[core_idx] = csr_flag_i[core_idx][1];
    end

    assign all_cal_done    = &cal_done_vec;
    assign all_w_load_done = &w_load_done_vec;

    // -------------------------------------------------------------------------
    // Wrapper config register file and read select pipeline
    // -------------------------------------------------------------------------

    always_comb begin
        csr_cfg_d = csr_cfg_q;

        if (axi_write_req && core_cfg_regfile_window_hit && (int'(core_cfg_regfile_word_idx) < N_CORES)) begin
            csr_cfg_d[core_cfg_idx] = axi_wdata_i[CORE_CFG_WIDTH-1:0];
        end
    end

    always_comb begin
        cal_en_d    = cal_en_q;
        w_load_en_d = w_load_en_q;
        if (axi_write_req && (axi_addr_i == `CACHE_PE_CORE_CAL_START_ADDR)) begin
            cal_en_d = axi_wdata_i[N_CORES-1:0];
        end else if (axi_write_req && (axi_addr_i == `CACHE_PE_CORE_W_LOAD_START_ADDR)) begin
            w_load_en_d = axi_wdata_i[N_CORES-1:0];
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            csr_cfg_q        <= '0;
            cal_en_q         <= '0;
            w_load_en_q      <= '0;
            reg_rdata_q      <= '0;
            core_rdata_sel_q <= 1'b0;
            core_cfg_read_q  <= 1'b0;
        end else begin
            csr_cfg_q        <= csr_cfg_d;
            cal_en_q         <= cal_en_d;
            w_load_en_q      <= w_load_en_d;
            reg_rdata_q      <= reg_rdata_d;
            core_rdata_sel_q <= core_data_read_req;
            core_cfg_read_q  <= core_cfg_read_req;
        end
    end

    // -------------------------------------------------------------------------
    // Local readback mux
    // -------------------------------------------------------------------------

    always_comb begin
        reg_rdata_d = '0;

        if (core_cfg_read_req) begin
            if (core_cfg_regfile_window_hit) begin
                if (int'(core_cfg_regfile_word_idx) < N_CORES) begin
                    reg_rdata_d[CORE_CFG_WIDTH-1:0] = csr_cfg_q[core_cfg_idx];
                end
            end else begin
                unique case (axi_addr_i)
                    `CACHE_PE_CORE_CAL_START_ADDR: begin
                        reg_rdata_d[N_CORES-1:0] = cal_en_q;
                    end
                    `CACHE_PE_CORE_W_LOAD_START_ADDR: begin
                        reg_rdata_d[N_CORES-1:0] = w_load_en_q;
                    end
                    `CACHE_PE_CORE_CAL_DONE_ADDR: begin
                        reg_rdata_d[N_CORES-1:0] = cal_done_vec;
                    end
                    `CACHE_PE_CORE_W_LOAD_DONE_ADDR: begin
                        reg_rdata_d[N_CORES-1:0] = w_load_done_vec;
                    end
                    `CACHE_PE_CORE_DONE_ALL_ADDR: begin
                        reg_rdata_d[0] = all_cal_done;
                        reg_rdata_d[1] = all_w_load_done;
                    end
                    default: begin
                        reg_rdata_d = '0;
                    end
                endcase
            end
        end
    end

endmodule
