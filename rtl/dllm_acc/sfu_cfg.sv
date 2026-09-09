//-----------------------------------------------------------------------------
// File: sfu_cfg.sv
// Date Created: 2026-04-14
// Description: SFU configuration register file for the Phase-2 dLLM
//              accelerator wrapper. Handles the 0x5000_0000 address region:
//              per-SFU config registers, wave control/status, tile decision
//              readback, scale vector storage, and result buffer read path.
//-----------------------------------------------------------------------------

`include "address_map.svh"

module sfu_cfg #(
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

    // AXI slave interface (from wrapper)
    input  logic                      axi_req_i,
    input  logic                      axi_we_i,
    input  logic [AXI_ADDR_WIDTH-1:0] axi_addr_i,
    input  logic [AXI_DATA_WIDTH-1:0] axi_wdata_i,
    output logic [AXI_DATA_WIDTH-1:0] cfg_rdata_o,
    output logic                      sfu_cfg_read_o,

    // Per-SFU configuration outputs
    output logic [N_SFUS-1:0][SFU_CFG_WIDTH-1:0] sfu_cfg_o,

    // Scale vector outputs (per SFU: CORES_PER_SFU * VLEN * ELEM_WIDTH bits)
    output logic [N_SFUS-1:0][CORES_PER_SFU*VLEN*ELEM_WIDTH-1:0] scale_vec_o,

    // Wave control
    output logic wave_en_o,
    input  logic wave_done_i,
    input  logic sfu_active_i,

    // Test mode: direct-start bypass
    output logic test_start_o,

    // Loop control
    output logic        loop_en_o,
    input  logic [31:0] loop_count_i,

    // Tile classifier interface
    input  logic [N_SFUS-1:0][CORES_PER_SFU-1:0] tile_decision_i,
    input  logic [N_SFUS-1:0][CORES_PER_SFU-1:0] tile_decision_valid_i,
    output logic [N_SFUS-1:0]                    tile_clr_o,

    // Result buffer read path (buffer lives in wrapper)
    output logic                            result_rd_req_o,
    output logic [      $clog2(N_SFUS)-1:0] result_rd_sfu_sel_o,
    output logic [$clog2(RESULT_DEPTH)-1:0] result_rd_token_o,
    output logic [                     1:0] result_rd_word_o,
    input  logic [      AXI_DATA_WIDTH-1:0] result_rd_data_i
);

    // -------------------------------------------------------------------------
    // Local parameters
    // -------------------------------------------------------------------------

    localparam integer SCALE_WORDS_PER_SFU = CORES_PER_SFU * VLEN * ELEM_WIDTH / AXI_DATA_WIDTH;
    localparam integer SCALE_WORDS_TOTAL = N_SFUS * SCALE_WORDS_PER_SFU;
    localparam integer RESULT_WORDS_PER_SFU = RESULT_DEPTH * (VLEN * ELEM_WIDTH / AXI_DATA_WIDTH);

    // -------------------------------------------------------------------------
    // Register storage
    // -------------------------------------------------------------------------

    logic [N_SFUS-1:0][SFU_CFG_WIDTH-1:0] sfu_cfg_d, sfu_cfg_q;
    logic [SCALE_WORDS_TOTAL-1:0][AXI_DATA_WIDTH-1:0] scale_mem_d, scale_mem_q;
    logic wave_en_d, wave_en_q;
    logic wave_done_d, wave_done_q;
    logic loop_en_d, loop_en_q;
    logic test_start_d, test_start_q;
    logic [N_SFUS-1:0] tile_clr_d;
    logic [AXI_DATA_WIDTH-1:0] cfg_rdata_d, cfg_rdata_q;
    logic sfu_cfg_read_d, sfu_cfg_read_q;
    logic result_read_d, result_read_q;

    // -------------------------------------------------------------------------
    // Address decode
    // -------------------------------------------------------------------------

    logic                      sfu_region_hit;
    logic                      cfg_regfile_hit;
    logic                      wave_ctrl_hit;
    logic                      tile_hit;
    logic                      scale_hit;
    logic                      result_hit;
    logic [AXI_ADDR_WIDTH-1:0] sfu_offset;
    logic                      sfu_read_req;
    logic                      sfu_write_req;

    assign sfu_offset      = axi_addr_i - `SFU_CFG_BASE_ADDR;
    assign sfu_region_hit  = (axi_addr_i >= `SFU_CFG_BASE_ADDR) && (axi_addr_i <= `SFU_CFG_END_ADDR);
    assign cfg_regfile_hit = (axi_addr_i >= `SFU_CFG_REGFILE_BASE_ADDR) && (axi_addr_i <= `SFU_CFG_REGFILE_END_ADDR);
    assign wave_ctrl_hit   = (axi_addr_i >= `SFU_WAVE_EN_ADDR) && (axi_addr_i <= `SFU_ACTIVE_ADDR);
    assign tile_hit        = (axi_addr_i >= `SFU_TILE_DECISION_ADDR) && (axi_addr_i <= `SFU_TILE_CLR_ADDR);
    assign scale_hit       = (axi_addr_i >= `SFU_SCALE_BASE_ADDR) && (axi_addr_i <= `SFU_SCALE_END_ADDR);
    assign result_hit      = (axi_addr_i >= `SFU_RESULT_BASE_ADDR) && (axi_addr_i <= `SFU_RESULT_END_ADDR);
    assign sfu_read_req    = axi_req_i && !axi_we_i && sfu_region_hit;
    assign sfu_write_req   = axi_req_i && axi_we_i && sfu_region_hit;

    // Index calculations
    logic [           $clog2(N_SFUS)-1:0] cfg_idx;
    logic [$clog2(SCALE_WORDS_TOTAL)-1:0] scale_word_idx;
    logic [           $clog2(N_SFUS)-1:0] result_sfu_idx;
    logic [     $clog2(RESULT_DEPTH)-1:0] result_token_idx;
    logic [                          1:0] result_word_idx;

    assign cfg_idx = sfu_offset[4:3];
    logic [AXI_ADDR_WIDTH-1:0] scale_offset;
    logic [AXI_ADDR_WIDTH-1:0] result_offset;

    assign scale_offset     = axi_addr_i - `SFU_SCALE_BASE_ADDR;
    assign scale_word_idx   = scale_offset[8:3];
    assign result_offset    = axi_addr_i - `SFU_RESULT_BASE_ADDR;
    assign result_sfu_idx   = result_offset[12:11];
    assign result_token_idx = result_offset[10:5];
    assign result_word_idx  = result_offset[4:3];

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------

    assign sfu_cfg_o        = sfu_cfg_q;
    assign wave_en_o        = wave_en_q;
    assign loop_en_o        = loop_en_q;
    assign tile_clr_o       = tile_clr_d;
    assign test_start_o     = test_start_q;

    // Scale vector packing: scale_mem_q is flat array of 64-bit words.
    // Each SFU gets SCALE_WORDS_PER_SFU consecutive words.
    generate
        for (genvar s = 0; s < N_SFUS; s++) begin : gen_scale_pack
            for (genvar w = 0; w < SCALE_WORDS_PER_SFU; w++) begin : gen_scale_word
                assign scale_vec_o[s][(w+1)*AXI_DATA_WIDTH-1-:AXI_DATA_WIDTH] = scale_mem_q[s*SCALE_WORDS_PER_SFU+w];
            end
        end
    endgenerate

    // Result buffer read port
    assign result_rd_req_o     = sfu_read_req && result_hit;
    assign result_rd_sfu_sel_o = result_sfu_idx[$clog2(N_SFUS)-1:0];
    assign result_rd_token_o   = result_token_idx;
    assign result_rd_word_o    = result_word_idx;

    // -------------------------------------------------------------------------
    // Write logic
    // -------------------------------------------------------------------------

    always_comb begin
        sfu_cfg_d   = sfu_cfg_q;
        wave_en_d   = wave_en_q;
        loop_en_d   = loop_en_q;
        test_start_d = 1'b0;
        scale_mem_d = scale_mem_q;
        tile_clr_d  = '0;

        if (sfu_write_req) begin
            if (cfg_regfile_hit) begin
                sfu_cfg_d[cfg_idx] = axi_wdata_i[SFU_CFG_WIDTH-1:0];
            end

            if (axi_addr_i == `SFU_WAVE_EN_ADDR) begin
                wave_en_d = axi_wdata_i[0];
            end

            if (axi_addr_i == `SFU_TEST_START_ADDR) begin
                test_start_d = axi_wdata_i[0];
            end

            if (axi_addr_i == `SFU_LOOP_EN_ADDR) begin
                loop_en_d = axi_wdata_i[0];
            end

            if (axi_addr_i == `SFU_TILE_CLR_ADDR) begin
                tile_clr_d = axi_wdata_i[N_SFUS-1:0];
            end

            if (scale_hit) begin
                scale_mem_d[scale_word_idx] = axi_wdata_i;
            end
        end

        // Self-clear wave_en when wave starts (sfu_active rises)
        if (wave_en_q && sfu_active_i) begin
            wave_en_d = 1'b0;
        end

        // wave_done latching: set on pulse, clear on wave_en write or test_start write
        wave_done_d = wave_done_q;
        if (wave_done_i) begin
            wave_done_d = 1'b1;
        end else if (sfu_write_req && ((axi_addr_i == `SFU_WAVE_EN_ADDR) ||
                                        (axi_addr_i == `SFU_TEST_START_ADDR))) begin
            wave_done_d = 1'b0;
        end

        // result read flag for rdata override
        result_read_d = sfu_read_req && result_hit;
    end

    // -------------------------------------------------------------------------
    // Read logic (combinational, registered in pipeline)
    // -------------------------------------------------------------------------

    always_comb begin
        cfg_rdata_d    = '0;
        sfu_cfg_read_d = sfu_read_req;

        if (sfu_read_req) begin
            if (cfg_regfile_hit) begin
                cfg_rdata_d[SFU_CFG_WIDTH-1:0] = sfu_cfg_q[cfg_idx];
            end else if (axi_addr_i == `SFU_WAVE_EN_ADDR) begin
                cfg_rdata_d[0] = wave_en_q;
            end else if (axi_addr_i == `SFU_WAVE_DONE_ADDR) begin
                cfg_rdata_d[0] = wave_done_q;
            end else if (axi_addr_i == `SFU_ACTIVE_ADDR) begin
                cfg_rdata_d[0] = sfu_active_i;
            end else if (axi_addr_i == `SFU_TILE_DECISION_ADDR) begin
                for (int s = 0; s < N_SFUS; s++) begin
                    cfg_rdata_d[s*CORES_PER_SFU+:CORES_PER_SFU] = tile_decision_i[s];
                end
            end else if (axi_addr_i == `SFU_TILE_DECISION_VALID_ADDR) begin
                for (int s = 0; s < N_SFUS; s++) begin
                    cfg_rdata_d[s*CORES_PER_SFU+:CORES_PER_SFU] = tile_decision_valid_i[s];
                end
            end else if (axi_addr_i == `SFU_TILE_CLR_ADDR) begin
                cfg_rdata_d = '0;
            end else if (axi_addr_i == `SFU_TEST_START_ADDR) begin
                // Write-only register: always reads as zero
                cfg_rdata_d = '0;
            end else if (axi_addr_i == `SFU_LOOP_EN_ADDR) begin
                cfg_rdata_d[0] = loop_en_q;
            end else if (axi_addr_i == `SFU_LOOP_COUNT_ADDR) begin
                cfg_rdata_d[31:0] = loop_count_i;
            end else if (scale_hit) begin
                cfg_rdata_d = scale_mem_q[scale_word_idx];
            end else if (result_hit) begin
                // Result buffer read data arrives one cycle later from wrapper
                // cfg_rdata is overridden by result_rd_data_i in the pipeline stage
                cfg_rdata_d = '0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Pipeline registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            sfu_cfg_q      <= '0;
            wave_en_q      <= 1'b0;
            wave_done_q    <= 1'b0;
            loop_en_q      <= 1'b0;
            test_start_q   <= 1'b0;
            cfg_rdata_q    <= '0;
            sfu_cfg_read_q <= 1'b0;
            result_read_q  <= 1'b0;
        end else begin
            sfu_cfg_q      <= sfu_cfg_d;
            wave_en_q      <= wave_en_d;
            wave_done_q    <= wave_done_d;
            loop_en_q      <= loop_en_d;
            test_start_q   <= test_start_d;
            cfg_rdata_q    <= cfg_rdata_d;
            sfu_cfg_read_q <= sfu_cfg_read_d;
            result_read_q  <= result_read_d;
        end
    end

    always_ff @(posedge clk_i) begin
        scale_mem_q <= scale_mem_d;
    end

    // Output: select result buffer data if the previous cycle was a result read
    assign cfg_rdata_o    = result_read_q ? result_rd_data_i : cfg_rdata_q;
    assign sfu_cfg_read_o = sfu_cfg_read_q;

endmodule
