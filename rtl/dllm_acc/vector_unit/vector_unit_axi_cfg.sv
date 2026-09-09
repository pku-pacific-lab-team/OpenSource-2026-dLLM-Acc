//-----------------------------------------------------------------------------
// File: vector_unit_axi_cfg.sv
// Description: AXI-visible config, status, and memory-window decode for vector_unit.
//-----------------------------------------------------------------------------

`include "address_map.svh"

module vector_unit_axi_cfg #(
    parameter logic   [63:0] BASE_ADDR            = 64'h6000_0000,
    parameter integer        AXI_ADDR_WIDTH       = 64,
    parameter integer        AXI_DATA_WIDTH       = 64,
    parameter integer        INSTR_WIDTH          = 32,
    parameter integer        INSTR_DEPTH          = 32,
    parameter integer        SCALAR_WIDTH         = 32,
    parameter integer        SCALAR_RF_DEPTH      = 32,
    parameter integer        VECTOR_RF_DEPTH      = 32,
    parameter integer        VECTOR_RF_BANK_WIDTH = 64,
    parameter integer        NUM_VECTOR_RF_BANKS  = 8,
    parameter integer        NUM_GROUPS           = 4,
    parameter integer        INSTR_STATE_WIDTH    = 3,
    parameter integer        PREFILL_STATE_WIDTH  = 2,
    parameter integer        INSTR_COUNT_WIDTH    = 6,
    parameter integer        PC_WIDTH             = 6,
    parameter integer        TP_NUM_SEQS          = 8,
    parameter integer        TP_SHIFT_CFG_W       = 4,
    parameter integer        TP_TILE_CNT_W        = 5
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,
    input  logic                        axi_req_i,
    input  logic                        axi_we_i,
    input  logic [  AXI_ADDR_WIDTH-1:0] axi_addr_i,
    input  logic [AXI_DATA_WIDTH/8-1:0] axi_be_i,
    input  logic [  AXI_DATA_WIDTH-1:0] axi_wdata_i,
    output logic [  AXI_DATA_WIDTH-1:0] axi_rdata_o,

    input logic                           run_active_i,
    input logic                           done_i,
    input logic [  INSTR_STATE_WIDTH-1:0] vu_state_i,
    input logic [PREFILL_STATE_WIDTH-1:0] prefill_state_i,
    input logic                           active_bank_i,
    input logic [                    1:0] bank_valid_i,
    input logic                           exec_pending_i,
    input logic [           PC_WIDTH-1:0] pc_i,

    input logic [        INSTR_WIDTH-1:0]                           instr_buf_rdata_i,
    input logic [         NUM_GROUPS-1:0][        SCALAR_WIDTH-1:0] scalar_rf_rdata_i,
    input logic [NUM_VECTOR_RF_BANKS-1:0][VECTOR_RF_BANK_WIDTH-1:0] vector_rf_rdata_i,

    input logic                           lane_issue_en_i,
    input logic                           decode_token_promote_en_i,
    input logic                           token_promote_instr_start_i,
    input logic                           token_promote_busy_i,
    input logic                           token_promote_done_i,
    input logic                           token_promote_result_i,
    input logic [$clog2(TP_NUM_SEQS)-1:0] token_promote_seq_id_i,
    input logic [      TP_TILE_CNT_W-1:0] token_promote_acc_i,
    input logic [$clog2(TP_NUM_SEQS)-1:0] token_promote_seq_idx_i,
    input logic [      TP_TILE_CNT_W-1:0] token_promote_tile_idx_i,
    input logic [      TP_TILE_CNT_W-1:0] token_promote_processed_tile_count_i,

    output logic                         start_pulse_o,
    output logic                         clear_done_pulse_o,
    output logic                         loop_mode_o,
    output logic [INSTR_COUNT_WIDTH-1:0] instr_count_o,

    output logic                                   axi_read_instr_buf_en_o,
    output logic [        $clog2(INSTR_DEPTH)-1:0] axi_read_instr_buf_idx_o,
    output logic                                   axi_read_scalar_rf_en_o,
    output logic [    $clog2(SCALAR_RF_DEPTH)-1:0] axi_read_scalar_rf_idx_o,
    output logic [         $clog2(NUM_GROUPS)-1:0] axi_read_scalar_group_idx_o,
    output logic                                   axi_read_vector_rf_en_o,
    output logic [    $clog2(VECTOR_RF_DEPTH)-1:0] axi_read_vector_rf_idx_o,
    output logic [$clog2(NUM_VECTOR_RF_BANKS)-1:0] axi_read_vector_bank_idx_o,

    output logic                                   axi_write_instr_buf_en_o,
    output logic [        $clog2(INSTR_DEPTH)-1:0] axi_write_instr_buf_idx_o,
    output logic [                INSTR_WIDTH-1:0] axi_write_instr_buf_data_o,
    output logic [                           31:0] axi_write_instr_buf_be_o,
    output logic                                   axi_write_scalar_rf_en_o,
    output logic [    $clog2(SCALAR_RF_DEPTH)-1:0] axi_write_scalar_rf_idx_o,
    output logic [         $clog2(NUM_GROUPS)-1:0] axi_write_scalar_group_idx_o,
    output logic [               SCALAR_WIDTH-1:0] axi_write_scalar_rf_data_o,
    output logic [                           31:0] axi_write_scalar_rf_be_o,
    output logic                                   axi_write_vector_rf_en_o,
    output logic [    $clog2(VECTOR_RF_DEPTH)-1:0] axi_write_vector_rf_idx_o,
    output logic [$clog2(NUM_VECTOR_RF_BANKS)-1:0] axi_write_vector_rf_bank_idx_o,
    output logic [       VECTOR_RF_BANK_WIDTH-1:0] axi_write_vector_rf_data_o,

    output logic [TP_NUM_SEQS*TP_SHIFT_CFG_W-1:0] token_promote_shift_cfg_o,
    output logic [             TP_TILE_CNT_W-1:0] token_promote_num_tiles_cfg_o,
    output logic [     $clog2(TP_NUM_SEQS+1)-1:0] token_promote_num_seqs_cfg_o,
    output logic [             TP_TILE_CNT_W-1:0] token_promote_acc_thres_cfg_o,

    // DMA config register outputs
    output logic [AXI_ADDR_WIDTH-1:0] dma_src_addr_o,
    output logic [AXI_ADDR_WIDTH-1:0] dma_dst_addr_o,
    output logic [AXI_ADDR_WIDTH-1:0] dma_length_o,
    output logic [              31:0] dma_config_o,
    output logic                      dma_launch_o,
    output logic [AXI_ADDR_WIDTH-1:0] dma_instr_src_base_addr_o,
    output logic [AXI_ADDR_WIDTH-1:0] dma_instr_dst_base_addr_o,

    // DMA status inputs
    input logic dma_busy_i,
    input logic dma_error_i,
    input logic dma_ready_i,

    // DMA active flag -- when set, storage windows allow access even during run_active
    input logic dma_active_i
);

    import vector_unit_pkg::*;

    localparam integer INSTR_ADDR_WIDTH = (INSTR_DEPTH > 1) ? $clog2(INSTR_DEPTH) : 1;
    localparam integer SCALAR_RF_ADDR_WIDTH = (SCALAR_RF_DEPTH > 1) ? $clog2(SCALAR_RF_DEPTH) : 1;
    localparam integer SCALAR_RF_GROUP_IDX_WIDTH = (NUM_GROUPS > 1) ? $clog2(NUM_GROUPS) : 1;
    localparam integer SCALAR_RF_TOTAL_WORDS = NUM_GROUPS * SCALAR_RF_DEPTH;
    localparam integer SCALAR_RF_WORD_IDX_WIDTH = (SCALAR_RF_TOTAL_WORDS > 1) ? $clog2(SCALAR_RF_TOTAL_WORDS) : 1;
    localparam integer VECTOR_RF_ADDR_WIDTH = (VECTOR_RF_DEPTH > 1) ? $clog2(VECTOR_RF_DEPTH) : 1;
    localparam integer VECTOR_RF_BANK_IDX_WIDTH = (NUM_VECTOR_RF_BANKS > 1) ? $clog2(NUM_VECTOR_RF_BANKS) : 1;
    localparam integer VECTOR_RF_WORD_BYTES = VECTOR_RF_BANK_WIDTH / 8;
    localparam integer VECTOR_RF_WINDOW_BYTES = VECTOR_RF_DEPTH * NUM_VECTOR_RF_BANKS * VECTOR_RF_WORD_BYTES;
    localparam integer TP_NUM_SEQS_CFG_W = (TP_NUM_SEQS > 1) ? $clog2(TP_NUM_SEQS + 1) : 1;
    localparam integer TP_TILE_CFG_ACC_THRES_LSB = 8;
    localparam integer TP_TILE_CFG_NUM_SEQS_LSB = 16;
    localparam logic [AXI_ADDR_WIDTH-1:0] VECTOR_RF_WINDOW_LAST_OFFSET = AXI_ADDR_WIDTH'(VECTOR_RF_WINDOW_BYTES) - AXI_ADDR_WIDTH'(1);

    // Addresses derived from BASE_ADDR + offset defines
    localparam logic [AXI_ADDR_WIDTH-1:0] CTRL_STATUS_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_CTRL_STATUS_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] LOOP_MODE_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_LOOP_MODE_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] INSTR_COUNT_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_INSTR_COUNT_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DEBUG_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DEBUG_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] INSTR_BUF_BASE_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_INSTR_BUF_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] INSTR_BUF_END_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_INSTR_BUF_END_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] SCALAR_RF_BASE_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_SCALAR_RF_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] SCALAR_RF_END_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_SCALAR_RF_END_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] TOKEN_PROMOTE_CTRL_STATUS_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_TOKEN_PROMOTE_CTRL_STATUS_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] TOKEN_PROMOTE_SHIFT_CFG_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_TOKEN_PROMOTE_SHIFT_CFG_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] TOKEN_PROMOTE_TILE_CFG_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_TOKEN_PROMOTE_TILE_CFG_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] TOKEN_PROMOTE_RESULT_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_TOKEN_PROMOTE_RESULT_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] TOKEN_PROMOTE_DEBUG_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_TOKEN_PROMOTE_DEBUG_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] VECTOR_RF_BASE_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_VECTOR_RF_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] ADDR_MAP_VU_VECTOR_RF_END_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_VECTOR_RF_END_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DERIVED_VU_VECTOR_RF_END_ADDR = VECTOR_RF_BASE_ADDR + VECTOR_RF_WINDOW_LAST_OFFSET;
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_BASE_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_END_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_END_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_SRC_LO_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_SRC_LO_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_SRC_HI_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_SRC_HI_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_DST_LO_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_DST_LO_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_DST_HI_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_DST_HI_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_LEN_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_LEN_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_CONFIG_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_CONFIG_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_LAUNCH_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_LAUNCH_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_INSTR_SRC_BASE_LO_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_INSTR_SRC_BASE_LO_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_INSTR_SRC_BASE_HI_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_INSTR_SRC_BASE_HI_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_INSTR_DST_BASE_LO_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_INSTR_DST_BASE_LO_OFFSET);
    localparam logic [AXI_ADDR_WIDTH-1:0] DMA_INSTR_DST_BASE_HI_ADDR = BASE_ADDR + AXI_ADDR_WIDTH'(`VU_DMA_INSTR_DST_BASE_HI_OFFSET);

    axi_read_src_t axi_read_src_d, axi_read_src_q;
    logic [VECTOR_RF_BANK_IDX_WIDTH-1:0] axi_read_vector_bank_d, axi_read_vector_bank_q;
    logic [SCALAR_RF_GROUP_IDX_WIDTH-1:0] axi_read_scalar_group_d, axi_read_scalar_group_q;

    logic loop_mode_d, loop_mode_q;
    logic [INSTR_COUNT_WIDTH-1:0] instr_count_d, instr_count_q;

    logic token_promote_start_d, token_promote_start_q;
    logic token_promote_valid_d, token_promote_valid_q;
    logic [TP_NUM_SEQS*TP_SHIFT_CFG_W-1:0] token_promote_shift_cfg_d, token_promote_shift_cfg_q;
    logic [TP_TILE_CNT_W-1:0] token_promote_num_tiles_cfg_d, token_promote_num_tiles_cfg_q;
    logic [TP_NUM_SEQS_CFG_W-1:0] token_promote_num_seqs_cfg_d, token_promote_num_seqs_cfg_q;
    logic [TP_TILE_CNT_W-1:0] token_promote_acc_thres_cfg_d, token_promote_acc_thres_cfg_q;
    logic token_promote_busy_d, token_promote_busy_q;
    logic token_promote_done_d, token_promote_done_q;
    logic token_promote_result_d, token_promote_result_q;
    logic [$clog2(TP_NUM_SEQS)-1:0] token_promote_result_seq_id_d, token_promote_result_seq_id_q;
    logic [TP_TILE_CNT_W-1:0] token_promote_result_acc_d, token_promote_result_acc_q;
    logic [$clog2(TP_NUM_SEQS)-1:0] token_promote_seq_idx_d, token_promote_seq_idx_q;
    logic [TP_TILE_CNT_W-1:0] token_promote_tile_idx_d, token_promote_tile_idx_q;
    logic [TP_TILE_CNT_W-1:0] token_promote_processed_tile_count_d, token_promote_processed_tile_count_q;
    logic token_promote_clear_done_pulse;

    // DMA config registers
    logic [31:0] dma_src_lo_d, dma_src_lo_q;
    logic [31:0] dma_src_hi_d, dma_src_hi_q;
    logic [31:0] dma_dst_lo_d, dma_dst_lo_q;
    logic [31:0] dma_dst_hi_d, dma_dst_hi_q;
    logic [31:0] dma_len_d, dma_len_q;
    logic [31:0] dma_config_d, dma_config_q;
    logic dma_launch_d, dma_launch_q;
    logic [31:0] dma_instr_src_base_lo_d, dma_instr_src_base_lo_q;
    logic [31:0] dma_instr_src_base_hi_d, dma_instr_src_base_hi_q;
    logic [31:0] dma_instr_dst_base_lo_d, dma_instr_dst_base_lo_q;
    logic [31:0] dma_instr_dst_base_hi_d, dma_instr_dst_base_hi_q;
    logic [7:0] dma_read_offset_d, dma_read_offset_q;

    logic                                                     axi_read_req;
    logic                                                     axi_write_req;
    logic                                                     instr_buf_window_hit;
    logic                                                     scalar_rf_window_hit;
    logic                                                     vector_rf_window_hit;
    logic                                                     dma_window_hit;
    logic [                               AXI_ADDR_WIDTH-1:0] instr_buf_offset;
    logic [                               AXI_ADDR_WIDTH-1:0] scalar_rf_offset;
    logic [                               AXI_ADDR_WIDTH-1:0] vector_rf_offset;
    logic [                             INSTR_ADDR_WIDTH-1:0] instr_word_idx;
    logic [                     SCALAR_RF_WORD_IDX_WIDTH-1:0] scalar_word_idx;
    logic [                    SCALAR_RF_GROUP_IDX_WIDTH-1:0] scalar_group_idx;
    logic [                         SCALAR_RF_ADDR_WIDTH-1:0] scalar_entry_idx;
    logic [VECTOR_RF_ADDR_WIDTH+VECTOR_RF_BANK_IDX_WIDTH-1:0] vector_word_idx;
    logic [                         VECTOR_RF_ADDR_WIDTH-1:0] axi_vec_idx;
    logic [                     VECTOR_RF_BANK_IDX_WIDTH-1:0] axi_bank_idx;

    // Storage access allowed when VU is idle or DMA is actively transferring
    logic                                                     storage_access_allowed;
    assign storage_access_allowed = !run_active_i || dma_active_i;

    assign axi_read_req           = axi_req_i && !axi_we_i;
    assign axi_write_req          = axi_req_i && axi_we_i;
    assign instr_buf_window_hit   = (axi_addr_i >= INSTR_BUF_BASE_ADDR) && (axi_addr_i <= INSTR_BUF_END_ADDR);
    assign scalar_rf_window_hit   = (axi_addr_i >= SCALAR_RF_BASE_ADDR) && (axi_addr_i <= SCALAR_RF_END_ADDR);
    assign vector_rf_window_hit   = (axi_addr_i >= VECTOR_RF_BASE_ADDR) && (axi_addr_i <= DERIVED_VU_VECTOR_RF_END_ADDR);
    assign dma_window_hit         = (axi_addr_i >= DMA_BASE_ADDR) && (axi_addr_i <= DMA_END_ADDR);

    initial begin
        if (DERIVED_VU_VECTOR_RF_END_ADDR != ADDR_MAP_VU_VECTOR_RF_END_ADDR) begin
            $fatal(1, "vector_unit_axi_cfg vector RF window mismatch: derived end=%h address_map end=%h", DERIVED_VU_VECTOR_RF_END_ADDR, ADDR_MAP_VU_VECTOR_RF_END_ADDR);
        end
    end

    // -------------------------------------------------------------------------
    // AXI read state registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            axi_read_src_q          <= AXI_RD_NONE;
            axi_read_vector_bank_q  <= '0;
            axi_read_scalar_group_q <= '0;
        end else begin
            axi_read_src_q          <= axi_read_src_d;
            axi_read_vector_bank_q  <= axi_read_vector_bank_d;
            axi_read_scalar_group_q <= axi_read_scalar_group_d;
        end
    end

    // -------------------------------------------------------------------------
    // Loop mode and instruction count registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            loop_mode_q   <= 1'b0;
            instr_count_q <= '0;
        end else begin
            loop_mode_q   <= loop_mode_d;
            instr_count_q <= instr_count_d;
        end
    end

    assign loop_mode_o   = loop_mode_q;
    assign instr_count_o = instr_count_q;

    // -------------------------------------------------------------------------
    // AXI decode and window logic
    // -------------------------------------------------------------------------

    always_comb begin
        instr_buf_offset               = '0;
        scalar_rf_offset               = '0;
        vector_rf_offset               = '0;
        instr_word_idx                 = '0;
        scalar_word_idx                = '0;
        scalar_group_idx               = '0;
        scalar_entry_idx               = '0;
        vector_word_idx                = '0;
        axi_vec_idx                    = '0;
        axi_bank_idx                   = '0;

        start_pulse_o                  = 1'b0;
        clear_done_pulse_o             = 1'b0;

        loop_mode_d                    = loop_mode_q;
        instr_count_d                  = instr_count_q;

        dma_src_lo_d                   = dma_src_lo_q;
        dma_src_hi_d                   = dma_src_hi_q;
        dma_dst_lo_d                   = dma_dst_lo_q;
        dma_dst_hi_d                   = dma_dst_hi_q;
        dma_len_d                      = dma_len_q;
        dma_config_d                   = dma_config_q;
        dma_launch_d                   = 1'b0;  // Auto-clear launch pulse
        dma_instr_src_base_lo_d        = dma_instr_src_base_lo_q;
        dma_instr_src_base_hi_d        = dma_instr_src_base_hi_q;
        dma_instr_dst_base_lo_d        = dma_instr_dst_base_lo_q;
        dma_instr_dst_base_hi_d        = dma_instr_dst_base_hi_q;
        dma_read_offset_d              = '0;

        axi_read_src_d                 = AXI_RD_NONE;
        axi_read_vector_bank_d         = '0;
        axi_read_scalar_group_d        = '0;
        axi_read_instr_buf_en_o        = 1'b0;
        axi_read_instr_buf_idx_o       = '0;
        axi_read_scalar_rf_en_o        = 1'b0;
        axi_read_scalar_rf_idx_o       = '0;
        axi_read_scalar_group_idx_o    = '0;
        axi_read_vector_rf_en_o        = 1'b0;
        axi_read_vector_rf_idx_o       = '0;
        axi_read_vector_bank_idx_o     = '0;

        axi_write_instr_buf_en_o       = 1'b0;
        axi_write_instr_buf_idx_o      = '0;
        axi_write_instr_buf_data_o     = '0;
        axi_write_instr_buf_be_o       = '0;
        axi_write_scalar_rf_en_o       = 1'b0;
        axi_write_scalar_rf_idx_o      = '0;
        axi_write_scalar_group_idx_o   = '0;
        axi_write_scalar_rf_data_o     = '0;
        axi_write_scalar_rf_be_o       = '0;
        axi_write_vector_rf_en_o       = 1'b0;
        axi_write_vector_rf_idx_o      = '0;
        axi_write_vector_rf_bank_idx_o = '0;
        axi_write_vector_rf_data_o     = '0;

        if (instr_buf_window_hit) begin
            instr_buf_offset = axi_addr_i - INSTR_BUF_BASE_ADDR;
            instr_word_idx   = INSTR_ADDR_WIDTH'(instr_buf_offset >> 3);
        end

        if (scalar_rf_window_hit) begin
            scalar_rf_offset = axi_addr_i - SCALAR_RF_BASE_ADDR;
            scalar_word_idx  = SCALAR_RF_WORD_IDX_WIDTH'(scalar_rf_offset >> 3);
            scalar_group_idx = SCALAR_RF_GROUP_IDX_WIDTH'(int'(scalar_word_idx) / SCALAR_RF_DEPTH);
            scalar_entry_idx = SCALAR_RF_ADDR_WIDTH'(int'(scalar_word_idx) % SCALAR_RF_DEPTH);
        end

        if (vector_rf_window_hit) begin
            vector_rf_offset = axi_addr_i - VECTOR_RF_BASE_ADDR;
            vector_word_idx  = (VECTOR_RF_ADDR_WIDTH + VECTOR_RF_BANK_IDX_WIDTH)'(vector_rf_offset >> 3);
            axi_vec_idx      = VECTOR_RF_ADDR_WIDTH'(int'(vector_word_idx) / NUM_VECTOR_RF_BANKS);
            axi_bank_idx     = VECTOR_RF_BANK_IDX_WIDTH'(int'(vector_word_idx) % NUM_VECTOR_RF_BANKS);
        end

        if (axi_read_req) begin
            if (axi_addr_i == CTRL_STATUS_ADDR) begin
                axi_read_src_d = AXI_RD_CTRL_STATUS;
            end else if (axi_addr_i == LOOP_MODE_ADDR) begin
                axi_read_src_d = AXI_RD_LOOP_MODE;
            end else if (axi_addr_i == INSTR_COUNT_ADDR) begin
                axi_read_src_d = AXI_RD_INSTR_COUNT;
            end else if (axi_addr_i == DEBUG_ADDR) begin
                axi_read_src_d = AXI_RD_DEBUG;
            end else if (axi_addr_i == TOKEN_PROMOTE_CTRL_STATUS_ADDR) begin
                axi_read_src_d = AXI_RD_TOKEN_PROMOTE_CTRL_STATUS;
            end else if (axi_addr_i == TOKEN_PROMOTE_SHIFT_CFG_ADDR) begin
                axi_read_src_d = AXI_RD_TOKEN_PROMOTE_SHIFT_CFG;
            end else if (axi_addr_i == TOKEN_PROMOTE_TILE_CFG_ADDR) begin
                axi_read_src_d = AXI_RD_TOKEN_PROMOTE_TILE_CFG;
            end else if (axi_addr_i == TOKEN_PROMOTE_RESULT_ADDR) begin
                axi_read_src_d = AXI_RD_TOKEN_PROMOTE_RESULT;
            end else if (axi_addr_i == TOKEN_PROMOTE_DEBUG_ADDR) begin
                axi_read_src_d = AXI_RD_TOKEN_PROMOTE_DEBUG;
            end else if (instr_buf_window_hit) begin
                if (storage_access_allowed) begin
                    if (int'(instr_word_idx) < INSTR_DEPTH) begin
                        axi_read_src_d           = AXI_RD_INSTR_BUF;
                        axi_read_instr_buf_en_o  = 1'b1;
                        axi_read_instr_buf_idx_o = INSTR_ADDR_WIDTH'(instr_word_idx);
                    end else begin
                        axi_read_src_d = AXI_RD_INVALID;
                    end
                end else begin
                    axi_read_src_d = AXI_RD_INVALID;
                end
            end else if (scalar_rf_window_hit) begin
                if (storage_access_allowed) begin
                    if (int'(scalar_word_idx) < SCALAR_RF_TOTAL_WORDS) begin
                        axi_read_src_d              = AXI_RD_SCALAR_RF;
                        axi_read_scalar_group_d     = scalar_group_idx;
                        axi_read_scalar_rf_en_o     = 1'b1;
                        axi_read_scalar_rf_idx_o    = scalar_entry_idx;
                        axi_read_scalar_group_idx_o = scalar_group_idx;
                    end else begin
                        axi_read_src_d = AXI_RD_INVALID;
                    end
                end else begin
                    axi_read_src_d = AXI_RD_INVALID;
                end
            end else if (vector_rf_window_hit) begin
                if (storage_access_allowed) begin
                    if (int'(axi_vec_idx) < VECTOR_RF_DEPTH) begin
                        axi_read_src_d             = AXI_RD_VECTOR_RF;
                        axi_read_vector_bank_d     = axi_bank_idx;
                        axi_read_vector_rf_en_o    = 1'b1;
                        axi_read_vector_rf_idx_o   = axi_vec_idx;
                        axi_read_vector_bank_idx_o = axi_bank_idx;
                    end else begin
                        axi_read_src_d = AXI_RD_INVALID;
                    end
                end else begin
                    axi_read_src_d = AXI_RD_INVALID;
                end
            end else if (dma_window_hit) begin
                axi_read_src_d    = AXI_RD_DMA_REGS;
                dma_read_offset_d = axi_addr_i[7:0];
            end else begin
                axi_read_src_d = AXI_RD_INVALID;
            end
        end

        if (axi_write_req) begin
            case (axi_addr_i)
                CTRL_STATUS_ADDR: begin
                    start_pulse_o      = axi_wdata_i[0];
                    clear_done_pulse_o = axi_wdata_i[1];
                end
                LOOP_MODE_ADDR: begin
                    if (|axi_be_i) begin
                        loop_mode_d = axi_wdata_i[0];
                    end
                end
                INSTR_COUNT_ADDR: begin
                    if (!run_active_i && (|axi_be_i)) begin
                        instr_count_d = axi_wdata_i[INSTR_COUNT_WIDTH-1:0];
                    end
                end
                // DMA registers -- accessible regardless of run_active
                DMA_SRC_LO_ADDR: begin
                    if (|axi_be_i[3:0]) dma_src_lo_d = axi_wdata_i[31:0];
                end
                DMA_SRC_HI_ADDR: begin
                    if (|axi_be_i[3:0]) dma_src_hi_d = axi_wdata_i[31:0];
                end
                DMA_DST_LO_ADDR: begin
                    if (|axi_be_i[3:0]) dma_dst_lo_d = axi_wdata_i[31:0];
                end
                DMA_DST_HI_ADDR: begin
                    if (|axi_be_i[3:0]) dma_dst_hi_d = axi_wdata_i[31:0];
                end
                DMA_LEN_ADDR: begin
                    if (|axi_be_i[3:0]) dma_len_d = axi_wdata_i[31:0];
                end
                DMA_CONFIG_ADDR: begin
                    if (|axi_be_i[3:0]) dma_config_d = axi_wdata_i[31:0];
                end
                DMA_LAUNCH_ADDR: begin
                    dma_launch_d = 1'b1;
                end
                DMA_INSTR_SRC_BASE_LO_ADDR: begin
                    if (|axi_be_i[3:0]) dma_instr_src_base_lo_d = axi_wdata_i[31:0];
                end
                DMA_INSTR_SRC_BASE_HI_ADDR: begin
                    if (|axi_be_i[3:0]) dma_instr_src_base_hi_d = axi_wdata_i[31:0];
                end
                DMA_INSTR_DST_BASE_LO_ADDR: begin
                    if (|axi_be_i[3:0]) dma_instr_dst_base_lo_d = axi_wdata_i[31:0];
                end
                DMA_INSTR_DST_BASE_HI_ADDR: begin
                    if (|axi_be_i[3:0]) dma_instr_dst_base_hi_d = axi_wdata_i[31:0];
                end
                default: begin
                end
            endcase
        end

        if (storage_access_allowed && axi_write_req && instr_buf_window_hit) begin
            if (int'(instr_word_idx) < INSTR_DEPTH) begin
                axi_write_instr_buf_en_o   = (|axi_be_i[3:0]);
                axi_write_instr_buf_idx_o  = instr_word_idx;
                axi_write_instr_buf_data_o = axi_wdata_i[INSTR_WIDTH-1:0];
                axi_write_instr_buf_be_o   = {{8{axi_be_i[3]}}, {8{axi_be_i[2]}}, {8{axi_be_i[1]}}, {8{axi_be_i[0]}}};
            end
        end

        if (storage_access_allowed && axi_write_req && scalar_rf_window_hit) begin
            if (int'(scalar_word_idx) < SCALAR_RF_TOTAL_WORDS) begin
                axi_write_scalar_rf_en_o     = (|axi_be_i[3:0]);
                axi_write_scalar_rf_idx_o    = scalar_entry_idx;
                axi_write_scalar_group_idx_o = scalar_group_idx;
                axi_write_scalar_rf_data_o   = axi_wdata_i[SCALAR_WIDTH-1:0];
                axi_write_scalar_rf_be_o     = {{8{axi_be_i[3]}}, {8{axi_be_i[2]}}, {8{axi_be_i[1]}}, {8{axi_be_i[0]}}};
            end
        end

        if (storage_access_allowed && axi_write_req && vector_rf_window_hit) begin
            if (int'(axi_vec_idx) < VECTOR_RF_DEPTH) begin
                axi_write_vector_rf_en_o       = (&axi_be_i);
                axi_write_vector_rf_idx_o      = axi_vec_idx;
                axi_write_vector_rf_bank_idx_o = axi_bank_idx;
                axi_write_vector_rf_data_o     = axi_wdata_i[VECTOR_RF_BANK_WIDTH-1:0];
            end
        end

    end

    // -------------------------------------------------------------------------
    // Token promotion registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            token_promote_start_q                <= 1'b0;
            token_promote_valid_q                <= 1'b0;
            token_promote_shift_cfg_q            <= '0;
            token_promote_num_tiles_cfg_q        <= '0;
            token_promote_num_seqs_cfg_q         <= '0;
            token_promote_acc_thres_cfg_q        <= '0;
            token_promote_busy_q                 <= 1'b0;
            token_promote_done_q                 <= 1'b0;
            token_promote_result_q               <= 1'b0;
            token_promote_result_seq_id_q        <= '0;
            token_promote_result_acc_q           <= '0;
            token_promote_seq_idx_q              <= '0;
            token_promote_tile_idx_q             <= '0;
            token_promote_processed_tile_count_q <= '0;
        end else begin
            token_promote_start_q                <= token_promote_start_d;
            token_promote_valid_q                <= token_promote_valid_d;
            token_promote_shift_cfg_q            <= token_promote_shift_cfg_d;
            token_promote_num_tiles_cfg_q        <= token_promote_num_tiles_cfg_d;
            token_promote_num_seqs_cfg_q         <= token_promote_num_seqs_cfg_d;
            token_promote_acc_thres_cfg_q        <= token_promote_acc_thres_cfg_d;
            token_promote_busy_q                 <= token_promote_busy_d;
            token_promote_done_q                 <= token_promote_done_d;
            token_promote_result_q               <= token_promote_result_d;
            token_promote_result_seq_id_q        <= token_promote_result_seq_id_d;
            token_promote_result_acc_q           <= token_promote_result_acc_d;
            token_promote_seq_idx_q              <= token_promote_seq_idx_d;
            token_promote_tile_idx_q             <= token_promote_tile_idx_d;
            token_promote_processed_tile_count_q <= token_promote_processed_tile_count_d;
        end
    end

    always_comb begin
        token_promote_start_d                = (lane_issue_en_i && decode_token_promote_en_i) ? token_promote_instr_start_i : 1'b0;
        token_promote_valid_d                = lane_issue_en_i && decode_token_promote_en_i;
        token_promote_shift_cfg_d            = token_promote_shift_cfg_q;
        token_promote_num_tiles_cfg_d        = token_promote_num_tiles_cfg_q;
        token_promote_num_seqs_cfg_d         = token_promote_num_seqs_cfg_q;
        token_promote_acc_thres_cfg_d        = token_promote_acc_thres_cfg_q;
        token_promote_busy_d                 = token_promote_busy_i;
        token_promote_done_d                 = token_promote_done_q;
        token_promote_result_d               = token_promote_result_q;
        token_promote_result_seq_id_d        = token_promote_result_seq_id_q;
        token_promote_result_acc_d           = token_promote_result_acc_q;
        token_promote_seq_idx_d              = token_promote_seq_idx_i;
        token_promote_tile_idx_d             = token_promote_tile_idx_i;
        token_promote_processed_tile_count_d = token_promote_processed_tile_count_i;
        token_promote_clear_done_pulse       = 1'b0;

        if (!run_active_i && axi_req_i && axi_we_i) begin
            case (axi_addr_i)
                TOKEN_PROMOTE_CTRL_STATUS_ADDR: begin
                    if (|axi_be_i) begin
                        token_promote_clear_done_pulse = axi_wdata_i[1];
                    end
                end
                TOKEN_PROMOTE_SHIFT_CFG_ADDR: begin
                    if (|axi_be_i[3:0]) begin
                        token_promote_shift_cfg_d = axi_wdata_i[31:0];
                    end
                end
                TOKEN_PROMOTE_TILE_CFG_ADDR: begin
                    if (|axi_be_i[3:0]) begin
                        token_promote_num_tiles_cfg_d = axi_wdata_i[TP_TILE_CNT_W-1:0];
                        token_promote_acc_thres_cfg_d = axi_wdata_i[TP_TILE_CFG_ACC_THRES_LSB+:TP_TILE_CNT_W];
                        token_promote_num_seqs_cfg_d  = axi_wdata_i[TP_TILE_CFG_NUM_SEQS_LSB+:TP_NUM_SEQS_CFG_W];
                    end
                end
                default: begin
                end
            endcase
        end

        if (token_promote_done_i) begin
            token_promote_done_d          = 1'b1;
            token_promote_result_d        = token_promote_result_i;
            token_promote_result_seq_id_d = token_promote_seq_id_i;
            token_promote_result_acc_d    = token_promote_acc_i;
        end

        if (token_promote_clear_done_pulse) begin
            token_promote_done_d = 1'b0;
        end
    end

    assign token_promote_shift_cfg_o     = token_promote_shift_cfg_q;
    assign token_promote_num_tiles_cfg_o = token_promote_num_tiles_cfg_q;
    assign token_promote_num_seqs_cfg_o  = token_promote_num_seqs_cfg_q;
    assign token_promote_acc_thres_cfg_o = token_promote_acc_thres_cfg_q;

    // -------------------------------------------------------------------------
    // DMA config registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            dma_src_lo_q            <= '0;
            dma_src_hi_q            <= '0;
            dma_dst_lo_q            <= '0;
            dma_dst_hi_q            <= '0;
            dma_len_q               <= '0;
            dma_config_q            <= '0;
            dma_launch_q            <= 1'b0;
            dma_instr_src_base_lo_q <= '0;
            dma_instr_src_base_hi_q <= '0;
            dma_instr_dst_base_lo_q <= '0;
            dma_instr_dst_base_hi_q <= '0;
            dma_read_offset_q       <= '0;
        end else begin
            dma_src_lo_q            <= dma_src_lo_d;
            dma_src_hi_q            <= dma_src_hi_d;
            dma_dst_lo_q            <= dma_dst_lo_d;
            dma_dst_hi_q            <= dma_dst_hi_d;
            dma_len_q               <= dma_len_d;
            dma_config_q            <= dma_config_d;
            dma_launch_q            <= dma_launch_d;
            dma_instr_src_base_lo_q <= dma_instr_src_base_lo_d;
            dma_instr_src_base_hi_q <= dma_instr_src_base_hi_d;
            dma_instr_dst_base_lo_q <= dma_instr_dst_base_lo_d;
            dma_instr_dst_base_hi_q <= dma_instr_dst_base_hi_d;
            dma_read_offset_q       <= dma_read_offset_d;
        end
    end

    assign dma_src_addr_o            = {dma_src_hi_q, dma_src_lo_q};
    assign dma_dst_addr_o            = {dma_dst_hi_q, dma_dst_lo_q};
    assign dma_length_o              = AXI_ADDR_WIDTH'(dma_len_q);
    assign dma_config_o              = dma_config_q;
    assign dma_launch_o              = dma_launch_q;
    assign dma_instr_src_base_addr_o = {dma_instr_src_base_hi_q, dma_instr_src_base_lo_q};
    assign dma_instr_dst_base_addr_o = {dma_instr_dst_base_hi_q, dma_instr_dst_base_lo_q};

    // -------------------------------------------------------------------------
    // AXI read data mux
    // -------------------------------------------------------------------------

    always_comb begin
        axi_rdata_o = '0;

        case (axi_read_src_q)
            AXI_RD_CTRL_STATUS: begin
                axi_rdata_o[0] = 1'b0;
                axi_rdata_o[1] = 1'b0;
                axi_rdata_o[8] = run_active_i;
                axi_rdata_o[9] = done_i;
            end
            AXI_RD_LOOP_MODE: begin
                axi_rdata_o[0] = loop_mode_q;
            end
            AXI_RD_INSTR_COUNT: begin
                axi_rdata_o[INSTR_COUNT_WIDTH-1:0] = instr_count_q;
            end
            AXI_RD_DEBUG: begin
                axi_rdata_o[2:0]          = vu_state_i;
                axi_rdata_o[5:4]          = prefill_state_i;
                axi_rdata_o[8]            = active_bank_i;
                axi_rdata_o[10:9]         = bank_valid_i;
                axi_rdata_o[11]           = exec_pending_i;
                axi_rdata_o[16+:PC_WIDTH] = pc_i;
            end
            AXI_RD_TOKEN_PROMOTE_CTRL_STATUS: begin
                axi_rdata_o[8]  = token_promote_busy_q;
                axi_rdata_o[9]  = token_promote_done_q;
                axi_rdata_o[10] = token_promote_result_q;
            end
            AXI_RD_TOKEN_PROMOTE_SHIFT_CFG: begin
                axi_rdata_o[31:0] = token_promote_shift_cfg_q;
            end
            AXI_RD_TOKEN_PROMOTE_TILE_CFG: begin
                axi_rdata_o[TP_TILE_CNT_W-1:0]                           = token_promote_num_tiles_cfg_q;
                axi_rdata_o[TP_TILE_CFG_ACC_THRES_LSB+:TP_TILE_CNT_W]    = token_promote_acc_thres_cfg_q;
                axi_rdata_o[TP_TILE_CFG_NUM_SEQS_LSB+:TP_NUM_SEQS_CFG_W] = token_promote_num_seqs_cfg_q;
            end
            AXI_RD_TOKEN_PROMOTE_RESULT: begin
                axi_rdata_o[$clog2(TP_NUM_SEQS)-1:0] = token_promote_result_seq_id_q;
                axi_rdata_o[8+:TP_TILE_CNT_W]        = token_promote_result_acc_q;
                axi_rdata_o[16]                      = token_promote_result_q;
            end
            AXI_RD_TOKEN_PROMOTE_DEBUG: begin
                axi_rdata_o[$clog2(TP_NUM_SEQS)-1:0] = token_promote_seq_idx_q;
                axi_rdata_o[8+:TP_TILE_CNT_W]        = token_promote_tile_idx_q;
                axi_rdata_o[16]                      = token_promote_start_q;
                axi_rdata_o[17]                      = decode_token_promote_en_i ? token_promote_instr_start_i : 1'b0;
                axi_rdata_o[18]                      = token_promote_valid_q;
                axi_rdata_o[19]                      = decode_token_promote_en_i;
            end
            AXI_RD_INSTR_BUF: begin
                axi_rdata_o[INSTR_WIDTH-1:0] = instr_buf_rdata_i;
            end
            AXI_RD_SCALAR_RF: begin
                axi_rdata_o[SCALAR_WIDTH-1:0] = scalar_rf_rdata_i[axi_read_scalar_group_q];
            end
            AXI_RD_VECTOR_RF: begin
                axi_rdata_o = vector_rf_rdata_i[axi_read_vector_bank_q];
            end
            AXI_RD_DMA_REGS: begin
                case (dma_read_offset_q)
                    8'h00:   axi_rdata_o = {32'b0, dma_src_lo_q};
                    8'h08:   axi_rdata_o = {32'b0, dma_src_hi_q};
                    8'h10:   axi_rdata_o = {32'b0, dma_dst_lo_q};
                    8'h18:   axi_rdata_o = {32'b0, dma_dst_hi_q};
                    8'h20:   axi_rdata_o = {32'b0, dma_len_q};
                    8'h28:   axi_rdata_o = {32'b0, dma_config_q};
                    8'h38:   axi_rdata_o = {32'b0, 29'b0, dma_ready_i, dma_error_i, dma_busy_i};  // [2:0] = {ready, error, busy}
                    8'h40:   axi_rdata_o = {32'b0, dma_instr_src_base_lo_q};
                    8'h48:   axi_rdata_o = {32'b0, dma_instr_src_base_hi_q};
                    8'h50:   axi_rdata_o = {32'b0, dma_instr_dst_base_lo_q};
                    8'h58:   axi_rdata_o = {32'b0, dma_instr_dst_base_hi_q};
                    default: axi_rdata_o = `AXI_INVALID_READ_DATA;
                endcase
            end
            AXI_RD_INVALID: begin
                axi_rdata_o = `AXI_INVALID_READ_DATA;
            end
            default: begin
            end
        endcase
    end

endmodule
