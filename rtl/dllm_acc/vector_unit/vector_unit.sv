//-----------------------------------------------------------------------------
// File: vector_unit.sv
// Date Created: 2026-03-19
// Description: Top-level SIMD vector unit with unified vector/scalar RFs.
//-----------------------------------------------------------------------------

`include "address_map.svh"
`include "axi_typedef.svh"
`include "axi_assign.svh"

module vector_unit #(
    // Instance base address for MMIO decode
    parameter logic [63:0] BASE_ADDR = 64'h6000_0000,

    // AXI slave interface parameters
    parameter integer AXI_ADDR_WIDTH = 64,
    parameter integer AXI_DATA_WIDTH = 64,

    // Vector unit parameters
    parameter integer INSTR_WIDTH     = 32,
    parameter integer INSTR_DEPTH     = 64,
    parameter integer SCALAR_WIDTH    = 32,
    parameter integer SCALAR_RF_DEPTH = 64,

    parameter integer VLEN                 = 64,
    parameter integer ELEM_WIDTH           = 16,
    parameter integer VECTOR_RF_DEPTH      = 64,
    parameter integer VECTOR_RF_BANK_WIDTH = 64,

    parameter integer TP_NUM_SEQS    = 8,
    parameter integer TP_TILE_SIZE   = 16,
    parameter integer TP_SHIFT_CFG_W = 4,
    parameter integer TP_TILE_CNT_W  = 5,
    parameter integer OP_WIDTH       = 3
) (
    input logic clk_i,
    input logic rst_ni,

    // AXI slave interface
    input  logic                        axi_req_i,
    input  logic                        axi_we_i,
    input  logic [  AXI_ADDR_WIDTH-1:0] axi_addr_i,
    input  logic [AXI_DATA_WIDTH/8-1:0] axi_be_i,
    input  logic [  AXI_DATA_WIDTH-1:0] axi_wdata_i,
    output logic [  AXI_DATA_WIDTH-1:0] axi_rdata_o,

    // DMA AXI master port
    AXI_BUS.Master master
);

    import vector_unit_pkg::*;

    localparam integer VECTOR_DATA_WIDTH = VLEN * ELEM_WIDTH;
    localparam integer NUM_VECTOR_RF_BANKS = VECTOR_DATA_WIDTH / VECTOR_RF_BANK_WIDTH;
    localparam integer NUM_GROUPS = vector_unit_pkg::NUM_GROUPS;
    localparam integer LANES_PER_GROUP = vector_unit_pkg::LANES_PER_GROUP;
    localparam integer SCALAR_RF_GROUP_IDX_WIDTH = (NUM_GROUPS > 1) ? $clog2(NUM_GROUPS) : 1;
    localparam integer VECTOR_RF_ADDR_WIDTH = (VECTOR_RF_DEPTH > 1) ? $clog2(VECTOR_RF_DEPTH) : 1;
    localparam integer SCALAR_RF_ADDR_WIDTH = (SCALAR_RF_DEPTH > 1) ? $clog2(SCALAR_RF_DEPTH) : 1;
    localparam integer INSTR_ADDR_WIDTH = (INSTR_DEPTH > 1) ? $clog2(INSTR_DEPTH) : 1;
    localparam integer INSTR_COUNT_WIDTH = INSTR_ADDR_WIDTH + 1;
    localparam integer VECTOR_RF_BANK_IDX_WIDTH = (NUM_VECTOR_RF_BANKS > 1) ? $clog2(NUM_VECTOR_RF_BANKS) : 1;
    localparam integer FUNC_WIDTH = 9;
    localparam integer INSTR_SRC0_LSB = 0;
    localparam integer INSTR_DST_LSB = INSTR_SRC0_LSB + VECTOR_RF_ADDR_WIDTH;
    localparam integer INSTR_SCALAR_LSB = INSTR_DST_LSB + VECTOR_RF_ADDR_WIDTH;
    localparam integer INSTR_OP_LSB = INSTR_SCALAR_LSB + SCALAR_RF_ADDR_WIDTH;
    localparam integer INSTR_FUNC_LSB = INSTR_OP_LSB + OP_WIDTH;

    vu_state_t                                                                                       vu_state_q;
    prefill_state_t                                                                                  prefill_state_q;
    logic                                                                                            active_bank_q;
    logic                 [                           1:0]                                           bank_valid_q;
    logic                                                                                            run_active_q;
    logic                                                                                            done_q;
    logic                                                                                            start_pulse;
    logic                                                                                            clear_done_pulse;
    logic                                                                                            loop_mode;
    logic                 [         INSTR_COUNT_WIDTH-1:0]                                           pc_q;
    logic                 [         INSTR_COUNT_WIDTH-1:0]                                           instr_count;
    logic                                                                                            instr_req;
    logic                                                                                            instr_valid_q;

    logic                 [                           1:0][         INSTR_WIDTH-1:0]                 instr_bank;
    logic                 [      VECTOR_RF_ADDR_WIDTH-1:0]                                           active_vec_idx;
    logic                 [      VECTOR_RF_ADDR_WIDTH-1:0]                                           active_dst_idx;
    logic                 [      VECTOR_RF_ADDR_WIDTH-1:0]                                           shadow_vec_idx;
    logic                 [      SCALAR_RF_ADDR_WIDTH-1:0]                                           active_scalar_idx;
    logic                 [      SCALAR_RF_ADDR_WIDTH-1:0]                                           shadow_scalar_idx;
    logic                 [                FUNC_WIDTH-1:0]                                           active_func;
    op_type_t                                                                                        active_op;
    op_type_t                                                                                        shadow_op;

    logic                                                                                            decode_align_en;
    logic                                                                                            decode_token_promote_en;
    logic                                                                                            decode_quant_en;
    logic                                                                                            decode_dma_en;
    logic                                                                                            decode_bf16_add_en;
    logic                                                                                            decode_bf16_mul_en;
    logic                                                                                            decode_pe_array_en;
    logic                                                                                            decode_binary_op;
    logic                                                                                            shadow_decode_token_promote_en;
    logic                                                                                            shadow_decode_binary_op;

    // src1 operand path (for binary ops: BF16 add/mul)
    logic                 [      VECTOR_RF_ADDR_WIDTH-1:0]                                           active_vec1_idx;
    logic                 [      VECTOR_RF_ADDR_WIDTH-1:0]                                           shadow_vec1_idx;
    // Per-group compute lane signals
    logic                 [                NUM_GROUPS-1:0]                                           align_lane_ready_g;
    logic                 [                NUM_GROUPS-1:0]                                           align_lane_done_g;
    logic                 [                NUM_GROUPS-1:0][     LANES_PER_GROUP-1:0][ELEM_WIDTH-1:0] align_lane_vec_result_g;
    logic                 [                NUM_GROUPS-1:0]                                           align_lane_vec_write_g;
    logic                 [                NUM_GROUPS-1:0][        SCALAR_WIDTH-1:0]                 align_lane_scalar_result_g;
    logic                 [                NUM_GROUPS-1:0]                                           align_lane_scalar_write_g;

    logic                 [                NUM_GROUPS-1:0]                                           quant_lane_ready_g;
    logic                 [                NUM_GROUPS-1:0]                                           quant_lane_done_g;
    logic                 [                NUM_GROUPS-1:0][     LANES_PER_GROUP-1:0][ELEM_WIDTH-1:0] quant_lane_vec_result_g;
    logic                 [                NUM_GROUPS-1:0]                                           quant_lane_vec_write_g;
    logic                 [                NUM_GROUPS-1:0][        SCALAR_WIDTH-1:0]                 quant_lane_scalar_result_g;
    logic                 [                NUM_GROUPS-1:0]                                           quant_lane_scalar_write_g;

    // BF16 add lane signals (per group)
    logic                 [                NUM_GROUPS-1:0]                                           bf16_add_lane_ready_g;
    logic                 [                NUM_GROUPS-1:0]                                           bf16_add_lane_done_g;
    logic                 [                NUM_GROUPS-1:0][     LANES_PER_GROUP-1:0][ELEM_WIDTH-1:0] bf16_add_lane_vec_result_g;
    logic                 [                NUM_GROUPS-1:0]                                           bf16_add_lane_vec_write_g;

    // BF16 mul lane signals (per group)
    logic                 [                NUM_GROUPS-1:0]                                           bf16_mul_lane_ready_g;
    logic                 [                NUM_GROUPS-1:0]                                           bf16_mul_lane_done_g;
    logic                 [                NUM_GROUPS-1:0][     LANES_PER_GROUP-1:0][ELEM_WIDTH-1:0] bf16_mul_lane_vec_result_g;
    logic                 [                NUM_GROUPS-1:0]                                           bf16_mul_lane_vec_write_g;

    // PE array signals
    logic                 [                           1:0]                                           pe_array_mode;
    logic                 [                      VLEN-1:0][                    15:0]                 pe_array_wgt;
    logic                 [                      VLEN-1:0][                    15:0]                 pe_array_act;
    logic                                                                                            pe_array_acc_clear;
    logic                                                                                            pe_array_acc_en;
    logic signed          [                      VLEN-1:0][                    15:0]                 pe_array_acc;
    logic                                                                                            pe_array_ready;
    logic                                                                                            pe_array_done;
    logic                                                                                            pe_array_vrf_read_en;
    logic                 [      VECTOR_RF_ADDR_WIDTH-1:0]                                           pe_array_vrf_read_idx;
    logic                                                                                            pe_array_wb_valid;
    logic                 [                      VLEN-1:0][          ELEM_WIDTH-1:0]                 pe_array_wb_vec_result;

    // Aggregated ready/done across groups
    logic                                                                                            align_lane_ready;
    logic                                                                                            align_lane_done;
    logic                                                                                            quant_lane_ready;
    logic                                                                                            quant_lane_done;
    logic                                                                                            bf16_add_lane_ready;
    logic                                                                                            bf16_add_lane_done;
    logic                                                                                            bf16_mul_lane_ready;
    logic                                                                                            bf16_mul_lane_done;

    logic                                                                                            instr_buf_req;
    logic                                                                                            instr_buf_we;
    logic                 [          INSTR_ADDR_WIDTH-1:0]                                           instr_buf_addr;
    logic                 [               INSTR_WIDTH-1:0]                                           instr_buf_wdata;
    logic                 [                          31:0]                                           instr_buf_be;
    logic                 [               INSTR_WIDTH-1:0]                                           instr_buf_rdata;

    logic                 [                NUM_GROUPS-1:0]                                           scalar_rf_req;
    logic                 [                NUM_GROUPS-1:0]                                           scalar_rf_we;
    logic                 [                NUM_GROUPS-1:0][SCALAR_RF_ADDR_WIDTH-1:0]                 scalar_rf_addr;
    logic                 [                NUM_GROUPS-1:0][        SCALAR_WIDTH-1:0]                 scalar_rf_wdata;
    logic                 [                NUM_GROUPS-1:0][                    31:0]                 scalar_rf_be;
    logic                 [                NUM_GROUPS-1:0][        SCALAR_WIDTH-1:0]                 scalar_rf_rdata;
    logic                                                                                            axi_read_instr_buf_en;
    logic                                                                                            axi_read_scalar_rf_en;
    logic                                                                                            axi_read_vector_rf_en;
    logic                 [          INSTR_ADDR_WIDTH-1:0]                                           axi_read_instr_buf_idx;
    logic                 [      SCALAR_RF_ADDR_WIDTH-1:0]                                           axi_read_scalar_rf_idx;
    logic                 [      VECTOR_RF_ADDR_WIDTH-1:0]                                           axi_read_vector_rf_idx;
    logic                 [  VECTOR_RF_BANK_IDX_WIDTH-1:0]                                           axi_read_vector_bank_idx;
    logic                                                                                            axi_write_instr_buf_en;
    logic                 [          INSTR_ADDR_WIDTH-1:0]                                           axi_write_instr_buf_idx;
    logic                 [               INSTR_WIDTH-1:0]                                           axi_write_instr_buf_data;
    logic                 [                          31:0]                                           axi_write_instr_buf_be;
    logic                                                                                            axi_write_scalar_rf_en;
    logic                 [      SCALAR_RF_ADDR_WIDTH-1:0]                                           axi_write_scalar_rf_idx;
    logic                 [ SCALAR_RF_GROUP_IDX_WIDTH-1:0]                                           axi_write_scalar_group_idx;
    logic                 [              SCALAR_WIDTH-1:0]                                           axi_write_scalar_rf_data;
    logic                 [                          31:0]                                           axi_write_scalar_rf_be;
    logic                 [ SCALAR_RF_GROUP_IDX_WIDTH-1:0]                                           axi_read_scalar_group_idx;
    logic                                                                                            axi_write_vector_rf_en;
    logic                 [      VECTOR_RF_ADDR_WIDTH-1:0]                                           axi_write_vector_rf_idx;
    logic                 [  VECTOR_RF_BANK_IDX_WIDTH-1:0]                                           axi_write_vector_rf_bank_idx;
    logic                 [      VECTOR_RF_BANK_WIDTH-1:0]                                           axi_write_vector_rf_data;

    logic                 [       NUM_VECTOR_RF_BANKS-1:0]                                           vector_rf_req;
    logic                 [       NUM_VECTOR_RF_BANKS-1:0]                                           vector_rf_we;
    logic                 [       NUM_VECTOR_RF_BANKS-1:0][VECTOR_RF_ADDR_WIDTH-1:0]                 vector_rf_addr;
    logic                 [       NUM_VECTOR_RF_BANKS-1:0][VECTOR_RF_BANK_WIDTH-1:0]                 vector_rf_wdata;
    logic                 [       NUM_VECTOR_RF_BANKS-1:0][VECTOR_RF_BANK_WIDTH-1:0]                 vector_rf_rdata;

    logic                 [                      VLEN-1:0][          ELEM_WIDTH-1:0]                 curr_vec_op;
    logic                 [                      VLEN-1:0][          ELEM_WIDTH-1:0]                 curr_vec_op1;
    logic                 [                      VLEN-1:0][          ELEM_WIDTH-1:0]                 vrf_rdata_unpacked;
    logic                 [                NUM_GROUPS-1:0][        SCALAR_WIDTH-1:0]                 curr_scalar_op;
    logic                                                                                            active_scalar_half_sel;
    logic                                                                                            active_lane_supported;
    logic                                                                                            selected_lane_ready;
    logic                                                                                            exec_result_clear;

    logic                                                                                            exec_pending_q;
    logic                                                                                            exec_vec_write_d;
    logic                                                                                            exec_vec_write_q;
    logic                 [                NUM_GROUPS-1:0]                                           exec_scalar_write_d;
    logic                 [                NUM_GROUPS-1:0]                                           exec_scalar_write_q;
    logic                 [                      VLEN-1:0][          ELEM_WIDTH-1:0]                 exec_vec_result_d;
    logic                 [                      VLEN-1:0][          ELEM_WIDTH-1:0]                 exec_vec_result_q;
    logic                 [                NUM_GROUPS-1:0][        SCALAR_WIDTH-1:0]                 exec_scalar_result_d;
    logic                 [                NUM_GROUPS-1:0][        SCALAR_WIDTH-1:0]                 exec_scalar_result_q;
    logic                 [      VECTOR_RF_ADDR_WIDTH-1:0]                                           issued_dst_idx_q;
    logic                 [      SCALAR_RF_ADDR_WIDTH-1:0]                                           issued_scalar_idx_q;
    op_type_t                                                                                        issued_op_q;
    logic                                                                                            issued_scalar_half_sel_q;

    // Per-group token promotion signals
    logic                 [                NUM_GROUPS-1:0][ $clog2(TP_NUM_SEQS)-1:0]                 token_promote_seq_idx_g;
    logic                 [                NUM_GROUPS-1:0][       TP_TILE_CNT_W-1:0]                 token_promote_tile_idx_g;
    logic                 [                NUM_GROUPS-1:0][       TP_TILE_CNT_W-1:0]                 token_promote_processed_tile_count_g;
    logic                                                                                            token_promote_instr_start;
    logic                 [                           1:0]                                           token_promote_score_mode;
    logic                 [                NUM_GROUPS-1:0]                                           token_promote_ready_g;
    logic                 [                NUM_GROUPS-1:0]                                           token_promote_busy_g;
    logic                 [                NUM_GROUPS-1:0]                                           token_promote_instr_done_g;
    logic                 [                NUM_GROUPS-1:0]                                           token_promote_done_g;
    logic                 [                NUM_GROUPS-1:0]                                           token_promote_result_g;
    logic                 [                NUM_GROUPS-1:0][ $clog2(TP_NUM_SEQS)-1:0]                 token_promote_seq_id_g;
    logic                 [                NUM_GROUPS-1:0][       TP_TILE_CNT_W-1:0]                 token_promote_acc_g;
    // Aggregated token promote signals (group 0 used for AXI cfg interface)
    logic                                                                                            token_promote_ready;
    logic                                                                                            token_promote_busy;
    logic                                                                                            token_promote_instr_done;
    logic                                                                                            token_promote_done;
    logic                                                                                            token_promote_result;
    logic                 [       $clog2(TP_NUM_SEQS)-1:0]                                           token_promote_seq_id;
    logic                 [             TP_TILE_CNT_W-1:0]                                           token_promote_acc;
    logic                 [       $clog2(TP_NUM_SEQS)-1:0]                                           token_promote_seq_idx;
    logic                 [             TP_TILE_CNT_W-1:0]                                           token_promote_tile_idx;
    logic                 [             TP_TILE_CNT_W-1:0]                                           token_promote_processed_tile_count;
    logic                 [TP_NUM_SEQS*TP_SHIFT_CFG_W-1:0]                                           token_promote_shift_cfg;
    logic                 [             TP_TILE_CNT_W-1:0]                                           token_promote_num_tiles_cfg;
    logic                 [     $clog2(TP_NUM_SEQS+1)-1:0]                                           token_promote_num_seqs_cfg;
    logic                 [             TP_TILE_CNT_W-1:0]                                           token_promote_acc_thres_cfg;

    logic                                                                                            lane_issue_en;
    logic                                                                                            vrf_read_vec_en;
    logic                                                                                            vrf_read_vec1_en;
    logic                                                                                            vrf_writeback_en;
    logic                                                                                            capture_active_vec;
    logic                                                                                            capture_active_vec1;
    logic                                                                                            capture_shadow_vec;
    logic                                                                                            capture_shadow_vec1;
    logic                                                                                            scalar_rf_read_active_en;
    logic                                                                                            scalar_rf_read_shadow_en;
    logic                                                                                            capture_active_scalar;
    logic                                                                                            capture_shadow_scalar;
    logic                                                                                            exec_done;
    logic                                                                                            exec_active;

    // DMA signals
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_src_addr;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_dst_addr;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_length;
    logic                 [                          31:0]                                           dma_config;
    logic                                                                                            dma_launch;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_instr_src_base_addr;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_instr_dst_base_addr;
    logic                                                                                            dma_busy;
    logic                                                                                            dma_error;
    logic                                                                                            dma_ready;
    logic                                                                                            dma_busy_aggregated;
    logic                                                                                            dma_active;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_req_src_addr;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_req_dst_addr;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_req_length;
    logic                 [                          31:0]                                           dma_req_config;

    vu_dma_idma_req_t                                                                                dma_idma_req;
    logic                                                                                            dma_idma_req_valid;
    logic                                                                                            dma_idma_req_ready;
    vu_dma_idma_rsp_t                                                                                dma_idma_rsp;
    logic                                                                                            dma_idma_rsp_valid;
    idma_pkg::idma_busy_t                                                                            dma_idma_busy;

    vu_dma_axi_req_t                                                                                 dma_axi_read_req;
    vu_dma_axi_resp_t                                                                                dma_axi_read_rsp;
    vu_dma_axi_req_t                                                                                 dma_axi_write_req;
    vu_dma_axi_resp_t                                                                                dma_axi_write_rsp;
    vu_dma_axi_req_t                                                                                 dma_axi_m_req;
    vu_dma_axi_resp_t                                                                                dma_axi_m_rsp;

    logic                 [                           4:0]                                           dma_vu_reg_index;
    logic                 [                          13:0]                                           dma_ext_offset;
    logic                                                                                            dma_direction;
    logic                 [                           1:0]                                           dma_vu_resource;
    logic                 [                           5:0]                                           dma_transfer_len_field;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_ext_addr;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_vu_addr;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_computed_src_addr;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_computed_dst_addr;
    logic                 [            AXI_ADDR_WIDTH-1:0]                                           dma_computed_length;
    logic                                                                                            dma_instr_launch;
    logic                                                                                            dma_instr_done;
    logic dma_instr_pending_d, dma_instr_pending_q;

    // -------------------------------------------------------------------------
    // Static config checks
    // -------------------------------------------------------------------------

    initial begin
        if (TP_TILE_SIZE != LANES_PER_GROUP) begin
            $fatal(1, "vector_unit requires TP_TILE_SIZE (%0d) to equal LANES_PER_GROUP (%0d)", TP_TILE_SIZE, LANES_PER_GROUP);
        end

        if ((INSTR_FUNC_LSB + FUNC_WIDTH) > INSTR_WIDTH) begin
            $fatal(1, "vector_unit instruction layout overflow: func_lsb=%0d func_width=%0d instr_width=%0d", INSTR_FUNC_LSB, FUNC_WIDTH, INSTR_WIDTH);
        end
    end

    // -------------------------------------------------------------------------
    // Execution result state
    // -------------------------------------------------------------------------

    // Datapath payload registers do not need reset when their associated
    // control strobes reset low.
    always_ff @(posedge clk_i) begin
        exec_vec_write_q     <= exec_vec_write_d;
        exec_scalar_write_q  <= exec_scalar_write_d;
        exec_vec_result_q    <= exec_vec_result_d;
        exec_scalar_result_q <= exec_scalar_result_d;
    end

    //-----------------------------------------------------------------------------
    // Issue / Prefill Control FSM
    //-----------------------------------------------------------------------------

    // Aggregate per-group ready/done -- all groups must agree
    assign align_lane_ready = &align_lane_ready_g;
    assign align_lane_done = &align_lane_done_g;
    assign quant_lane_ready = &quant_lane_ready_g;
    assign quant_lane_done = &quant_lane_done_g;
    assign bf16_add_lane_ready = &bf16_add_lane_ready_g;
    assign bf16_add_lane_done = &bf16_add_lane_done_g;
    assign bf16_mul_lane_ready = &bf16_mul_lane_ready_g;
    assign bf16_mul_lane_done = &bf16_mul_lane_done_g;
    assign token_promote_ready = &token_promote_ready_g;
    assign token_promote_instr_done = &token_promote_instr_done_g;
    // Group 0 used for AXI cfg status interface
    assign token_promote_busy = token_promote_busy_g[0];
    assign token_promote_done = token_promote_done_g[0];
    assign token_promote_result = token_promote_result_g[0];
    assign token_promote_seq_id = token_promote_seq_id_g[0];
    assign token_promote_acc = token_promote_acc_g[0];
    assign token_promote_seq_idx = token_promote_seq_idx_g[0];
    assign token_promote_tile_idx = token_promote_tile_idx_g[0];
    assign token_promote_processed_tile_count = token_promote_processed_tile_count_g[0];

    assign exec_done = align_lane_done || token_promote_instr_done || quant_lane_done || dma_instr_done || bf16_add_lane_done || bf16_mul_lane_done || pe_array_done;
    assign exec_active = (vu_state_q == VU_EXEC_ACTIVE);

    vector_unit_ctrl #(
        .VECTOR_RF_ADDR_WIDTH(VECTOR_RF_ADDR_WIDTH),
        .SCALAR_RF_ADDR_WIDTH(SCALAR_RF_ADDR_WIDTH),
        .INSTR_COUNT_WIDTH   (INSTR_COUNT_WIDTH)
    ) i_vector_unit_ctrl (
        .clk_i                           (clk_i),
        .rst_ni                          (rst_ni),
        .start_pulse_i                   (start_pulse),
        .clear_done_pulse_i              (clear_done_pulse),
        .loop_mode_i                     (loop_mode),
        .instr_count_i                   (instr_count),
        .decode_dma_en_i                 (decode_dma_en),
        .decode_binary_op_i              (decode_binary_op),
        .decode_pe_array_en_i            (decode_pe_array_en),
        .decode_token_promote_en_i       (decode_token_promote_en),
        .shadow_decode_token_promote_en_i(shadow_decode_token_promote_en),
        .shadow_decode_binary_op_i       (shadow_decode_binary_op),
        .active_lane_supported_i         (active_lane_supported),
        .selected_lane_ready_i           (selected_lane_ready),
        .active_scalar_half_sel_i        (active_scalar_half_sel),
        .active_dst_idx_i                (active_dst_idx),
        .active_scalar_idx_i             (active_scalar_idx),
        .active_op_i                     (active_op),
        .exec_done_i                     (exec_done),
        .exec_vec_write_pending_i        (exec_vec_write_q),
        .vu_state_o                      (vu_state_q),
        .prefill_state_o                 (prefill_state_q),
        .active_bank_o                   (active_bank_q),
        .bank_valid_o                    (bank_valid_q),
        .run_active_o                    (run_active_q),
        .done_o                          (done_q),
        .pc_o                            (pc_q),
        .instr_valid_o                   (instr_valid_q),
        .exec_pending_o                  (exec_pending_q),
        .instr_req_o                     (instr_req),
        .lane_issue_en_o                 (lane_issue_en),
        .vrf_read_vec_en_o               (vrf_read_vec_en),
        .vrf_read_vec1_en_o              (vrf_read_vec1_en),
        .vrf_writeback_en_o              (vrf_writeback_en),
        .scalar_rf_read_active_en_o      (scalar_rf_read_active_en),
        .scalar_rf_read_shadow_en_o      (scalar_rf_read_shadow_en),
        .capture_active_vec_o            (capture_active_vec),
        .capture_active_vec1_o           (capture_active_vec1),
        .capture_shadow_vec_o            (capture_shadow_vec),
        .capture_shadow_vec1_o           (capture_shadow_vec1),
        .capture_active_scalar_o         (capture_active_scalar),
        .capture_shadow_scalar_o         (capture_shadow_scalar),
        .exec_result_clear_o             (exec_result_clear),
        .issued_dst_idx_o                (issued_dst_idx_q),
        .issued_scalar_idx_o             (issued_scalar_idx_q),
        .issued_op_o                     (issued_op_q),
        .issued_scalar_half_sel_o        (issued_scalar_half_sel_q)
    );

    //-----------------------------------------------------------------------------
    // AXI Config / Status Frontend
    //-----------------------------------------------------------------------------

    vector_unit_axi_cfg #(
        .BASE_ADDR           (BASE_ADDR),
        .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH      (AXI_DATA_WIDTH),
        .INSTR_WIDTH         (INSTR_WIDTH),
        .INSTR_DEPTH         (INSTR_DEPTH),
        .SCALAR_WIDTH        (SCALAR_WIDTH),
        .SCALAR_RF_DEPTH     (SCALAR_RF_DEPTH),
        .VECTOR_RF_DEPTH     (VECTOR_RF_DEPTH),
        .VECTOR_RF_BANK_WIDTH(VECTOR_RF_BANK_WIDTH),
        .NUM_VECTOR_RF_BANKS (NUM_VECTOR_RF_BANKS),
        .NUM_GROUPS          (NUM_GROUPS),
        .INSTR_STATE_WIDTH   ($bits(vu_state_t)),
        .PREFILL_STATE_WIDTH ($bits(prefill_state_t)),
        .INSTR_COUNT_WIDTH   (INSTR_COUNT_WIDTH),
        .PC_WIDTH            (INSTR_COUNT_WIDTH),
        .TP_NUM_SEQS         (TP_NUM_SEQS),
        .TP_SHIFT_CFG_W      (TP_SHIFT_CFG_W),
        .TP_TILE_CNT_W       (TP_TILE_CNT_W)
    ) i_vector_unit_axi_cfg (
        .clk_i                               (clk_i),
        .rst_ni                              (rst_ni),
        .axi_req_i                           (axi_req_i),
        .axi_we_i                            (axi_we_i),
        .axi_addr_i                          (axi_addr_i),
        .axi_be_i                            (axi_be_i),
        .axi_wdata_i                         (axi_wdata_i),
        .axi_rdata_o                         (axi_rdata_o),
        .run_active_i                        (run_active_q),
        .done_i                              (done_q),
        .vu_state_i                          (vu_state_q),
        .prefill_state_i                     (prefill_state_q),
        .active_bank_i                       (active_bank_q),
        .bank_valid_i                        (bank_valid_q),
        .exec_pending_i                      (exec_pending_q),
        .pc_i                                (pc_q),
        .instr_buf_rdata_i                   (instr_buf_rdata),
        .scalar_rf_rdata_i                   (scalar_rf_rdata),
        .vector_rf_rdata_i                   (vector_rf_rdata),
        .lane_issue_en_i                     (lane_issue_en),
        .decode_token_promote_en_i           (decode_token_promote_en),
        .token_promote_instr_start_i         (token_promote_instr_start),
        .token_promote_busy_i                (token_promote_busy),
        .token_promote_done_i                (token_promote_done),
        .token_promote_result_i              (token_promote_result),
        .token_promote_seq_id_i              (token_promote_seq_id),
        .token_promote_acc_i                 (token_promote_acc),
        .token_promote_seq_idx_i             (token_promote_seq_idx),
        .token_promote_tile_idx_i            (token_promote_tile_idx),
        .token_promote_processed_tile_count_i(token_promote_processed_tile_count),
        .start_pulse_o                       (start_pulse),
        .clear_done_pulse_o                  (clear_done_pulse),
        .loop_mode_o                         (loop_mode),
        .instr_count_o                       (instr_count),
        .axi_read_instr_buf_en_o             (axi_read_instr_buf_en),
        .axi_read_instr_buf_idx_o            (axi_read_instr_buf_idx),
        .axi_read_scalar_rf_en_o             (axi_read_scalar_rf_en),
        .axi_read_scalar_rf_idx_o            (axi_read_scalar_rf_idx),
        .axi_read_scalar_group_idx_o         (axi_read_scalar_group_idx),
        .axi_read_vector_rf_en_o             (axi_read_vector_rf_en),
        .axi_read_vector_rf_idx_o            (axi_read_vector_rf_idx),
        .axi_read_vector_bank_idx_o          (axi_read_vector_bank_idx),
        .axi_write_instr_buf_en_o            (axi_write_instr_buf_en),
        .axi_write_instr_buf_idx_o           (axi_write_instr_buf_idx),
        .axi_write_instr_buf_data_o          (axi_write_instr_buf_data),
        .axi_write_instr_buf_be_o            (axi_write_instr_buf_be),
        .axi_write_scalar_rf_en_o            (axi_write_scalar_rf_en),
        .axi_write_scalar_rf_idx_o           (axi_write_scalar_rf_idx),
        .axi_write_scalar_group_idx_o        (axi_write_scalar_group_idx),
        .axi_write_scalar_rf_data_o          (axi_write_scalar_rf_data),
        .axi_write_scalar_rf_be_o            (axi_write_scalar_rf_be),
        .axi_write_vector_rf_en_o            (axi_write_vector_rf_en),
        .axi_write_vector_rf_idx_o           (axi_write_vector_rf_idx),
        .axi_write_vector_rf_bank_idx_o      (axi_write_vector_rf_bank_idx),
        .axi_write_vector_rf_data_o          (axi_write_vector_rf_data),
        .token_promote_shift_cfg_o           (token_promote_shift_cfg),
        .token_promote_num_tiles_cfg_o       (token_promote_num_tiles_cfg),
        .token_promote_num_seqs_cfg_o        (token_promote_num_seqs_cfg),
        .token_promote_acc_thres_cfg_o       (token_promote_acc_thres_cfg),
        .dma_src_addr_o                      (dma_src_addr),
        .dma_dst_addr_o                      (dma_dst_addr),
        .dma_length_o                        (dma_length),
        .dma_config_o                        (dma_config),
        .dma_launch_o                        (dma_launch),
        .dma_instr_src_base_addr_o           (dma_instr_src_base_addr),
        .dma_instr_dst_base_addr_o           (dma_instr_dst_base_addr),
        .dma_busy_i                          (dma_busy),
        .dma_error_i                         (dma_error),
        .dma_ready_i                         (dma_ready),
        .dma_active_i                        (dma_active)
    );

    //-----------------------------------------------------------------------------
    // Memories
    //-----------------------------------------------------------------------------

    sram_be_64x32 i_instr_buf (
        .clk_i         (clk_i),
        .chip_enable_i (instr_buf_req),
        .write_enable_i(instr_buf_we),
        .addr_i        (instr_buf_addr),
        .write_data_i  (instr_buf_wdata),
        .bit_enable_i  (instr_buf_be),
        .read_data_o   (instr_buf_rdata)
    );

    generate
        genvar bank_idx;
        for (bank_idx = 0; bank_idx < NUM_VECTOR_RF_BANKS; bank_idx = bank_idx + 1) begin : gen_vector_rf
            sram_be_64x64 i_vector_rf_bank (
                .clk_i         (clk_i),
                .chip_enable_i (vector_rf_req[bank_idx]),
                .write_enable_i(vector_rf_we[bank_idx]),
                .addr_i        (vector_rf_addr[bank_idx]),
                .write_data_i  (vector_rf_wdata[bank_idx]),
                .bit_enable_i  ('1),
                .read_data_o   (vector_rf_rdata[bank_idx])
            );
        end
    endgenerate

    generate
        genvar group_idx;
        for (group_idx = 0; group_idx < NUM_GROUPS; group_idx = group_idx + 1) begin : gen_scalar_rf
            sram_be_64x32 i_scalar_rf (
                .clk_i         (clk_i),
                .chip_enable_i (scalar_rf_req[group_idx]),
                .write_enable_i(scalar_rf_we[group_idx]),
                .addr_i        (scalar_rf_addr[group_idx]),
                .write_data_i  (scalar_rf_wdata[group_idx]),
                .bit_enable_i  (scalar_rf_be[group_idx]),
                .read_data_o   (scalar_rf_rdata[group_idx])
            );
        end
    endgenerate

    //-----------------------------------------------------------------------------
    // RF / Operand Frontend
    //-----------------------------------------------------------------------------

    vector_unit_rf_frontend #(
        .INSTR_WIDTH         (INSTR_WIDTH),
        .INSTR_DEPTH         (INSTR_DEPTH),
        .SCALAR_WIDTH        (SCALAR_WIDTH),
        .SCALAR_RF_DEPTH     (SCALAR_RF_DEPTH),
        .VLEN                (VLEN),
        .ELEM_WIDTH          (ELEM_WIDTH),
        .VECTOR_RF_DEPTH     (VECTOR_RF_DEPTH),
        .VECTOR_RF_BANK_WIDTH(VECTOR_RF_BANK_WIDTH),
        .NUM_GROUPS          (NUM_GROUPS)
    ) i_vector_unit_rf_frontend (
        .clk_i                         (clk_i),
        .rst_ni                        (rst_ni),
        .exec_active_i                 (exec_active),
        .active_bank_i                 (active_bank_q),
        .instr_req_i                   (instr_req),
        .instr_valid_i                 (instr_valid_q),
        .instr_pc_i                    (pc_q[INSTR_ADDR_WIDTH-1:0]),
        .vrf_read_vec_en_i             (vrf_read_vec_en),
        .vrf_read_vec1_en_i            (vrf_read_vec1_en),
        .vrf_writeback_en_i            (vrf_writeback_en),
        .capture_active_vec_i          (capture_active_vec),
        .capture_active_vec1_i         (capture_active_vec1),
        .capture_shadow_vec_i          (capture_shadow_vec),
        .capture_shadow_vec1_i         (capture_shadow_vec1),
        .scalar_rf_read_active_en_i    (scalar_rf_read_active_en),
        .scalar_rf_read_shadow_en_i    (scalar_rf_read_shadow_en),
        .capture_active_scalar_i       (capture_active_scalar),
        .capture_shadow_scalar_i       (capture_shadow_scalar),
        .active_vec_idx_i              (active_vec_idx),
        .active_vec1_idx_i             (active_vec1_idx),
        .shadow_vec_idx_i              (shadow_vec_idx),
        .shadow_vec1_idx_i             (shadow_vec1_idx),
        .active_scalar_idx_i           (active_scalar_idx),
        .shadow_scalar_idx_i           (shadow_scalar_idx),
        .pe_array_vrf_read_en_i        (pe_array_vrf_read_en),
        .pe_array_vrf_read_idx_i       (pe_array_vrf_read_idx),
        .exec_vec_write_i              (exec_vec_write_q),
        .exec_scalar_write_g_i         ((vu_state_q == VU_WRITEBACK_ACTIVE) ? exec_scalar_write_q : '0),
        .exec_vec_result_i             (exec_vec_result_q),
        .exec_scalar_result_g_i        (exec_scalar_result_q),
        .issued_dst_idx_i              (issued_dst_idx_q),
        .issued_scalar_idx_i           (issued_scalar_idx_q),
        .issued_op_i                   (issued_op_q),
        .issued_scalar_half_sel_i      (issued_scalar_half_sel_q),
        .axi_read_instr_buf_en_i       (axi_read_instr_buf_en),
        .axi_read_instr_buf_idx_i      (axi_read_instr_buf_idx),
        .axi_read_scalar_rf_en_i       (axi_read_scalar_rf_en),
        .axi_read_scalar_rf_idx_i      (axi_read_scalar_rf_idx),
        .axi_read_scalar_group_idx_i   (axi_read_scalar_group_idx),
        .axi_read_vector_rf_en_i       (axi_read_vector_rf_en),
        .axi_read_vector_rf_idx_i      (axi_read_vector_rf_idx),
        .axi_read_vector_bank_idx_i    (axi_read_vector_bank_idx),
        .axi_write_instr_buf_en_i      (axi_write_instr_buf_en),
        .axi_write_instr_buf_idx_i     (axi_write_instr_buf_idx),
        .axi_write_instr_buf_data_i    (axi_write_instr_buf_data),
        .axi_write_instr_buf_be_i      (axi_write_instr_buf_be),
        .axi_write_scalar_rf_en_i      (axi_write_scalar_rf_en),
        .axi_write_scalar_rf_idx_i     (axi_write_scalar_rf_idx),
        .axi_write_scalar_group_idx_i  (axi_write_scalar_group_idx),
        .axi_write_scalar_rf_data_i    (axi_write_scalar_rf_data),
        .axi_write_scalar_rf_be_i      (axi_write_scalar_rf_be),
        .axi_write_vector_rf_en_i      (axi_write_vector_rf_en),
        .axi_write_vector_rf_idx_i     (axi_write_vector_rf_idx),
        .axi_write_vector_rf_bank_idx_i(axi_write_vector_rf_bank_idx),
        .axi_write_vector_rf_data_i    (axi_write_vector_rf_data),
        .instr_buf_req_o               (instr_buf_req),
        .instr_buf_we_o                (instr_buf_we),
        .instr_buf_addr_o              (instr_buf_addr),
        .instr_buf_wdata_o             (instr_buf_wdata),
        .instr_buf_be_o                (instr_buf_be),
        .instr_buf_rdata_i             (instr_buf_rdata),
        .scalar_rf_req_o               (scalar_rf_req),
        .scalar_rf_we_o                (scalar_rf_we),
        .scalar_rf_addr_o              (scalar_rf_addr),
        .scalar_rf_wdata_o             (scalar_rf_wdata),
        .scalar_rf_be_o                (scalar_rf_be),
        .scalar_rf_rdata_i             (scalar_rf_rdata),
        .vector_rf_req_o               (vector_rf_req),
        .vector_rf_we_o                (vector_rf_we),
        .vector_rf_addr_o              (vector_rf_addr),
        .vector_rf_wdata_o             (vector_rf_wdata),
        .vector_rf_rdata_i             (vector_rf_rdata),
        .instr_bank_o                  (instr_bank),
        .curr_vec_op_o                 (curr_vec_op),
        .curr_vec_op1_o                (curr_vec_op1),
        .curr_scalar_op_o              (curr_scalar_op),
        .vrf_rdata_unpacked_o          (vrf_rdata_unpacked)
    );

    //-----------------------------------------------------------------------------
    // Instruction Decode
    //-----------------------------------------------------------------------------

    assign active_vec_idx = instr_bank[active_bank_q][INSTR_SRC0_LSB+:VECTOR_RF_ADDR_WIDTH];
    assign shadow_vec_idx = instr_bank[~active_bank_q][INSTR_SRC0_LSB+:VECTOR_RF_ADDR_WIDTH];
    assign active_dst_idx = instr_bank[active_bank_q][INSTR_DST_LSB+:VECTOR_RF_ADDR_WIDTH];
    assign active_scalar_idx = instr_bank[active_bank_q][INSTR_SCALAR_LSB+:SCALAR_RF_ADDR_WIDTH];
    assign shadow_scalar_idx = instr_bank[~active_bank_q][INSTR_SCALAR_LSB+:SCALAR_RF_ADDR_WIDTH];
    assign active_func = instr_bank[active_bank_q][INSTR_FUNC_LSB+:FUNC_WIDTH];
    assign active_op = op_type_t'(instr_bank[active_bank_q][INSTR_OP_LSB+:OP_WIDTH]);
    assign shadow_op = op_type_t'(instr_bank[~active_bank_q][INSTR_OP_LSB+:OP_WIDTH]);

    assign decode_align_en = (active_op == OP_TYPE_ALIGN);
    assign decode_token_promote_en = (active_op == OP_TYPE_TOKEN_PROMOTE);
    assign decode_quant_en = (active_op == OP_TYPE_QUANT);
    assign decode_dma_en = (active_op == OP_TYPE_DMA);
    assign decode_bf16_add_en = (active_op == OP_TYPE_BF16_ADD);
    assign decode_bf16_mul_en = (active_op == OP_TYPE_BF16_MUL);
    assign decode_pe_array_en = (active_op == OP_TYPE_PE_ARRAY);
    assign decode_binary_op = decode_bf16_add_en || decode_bf16_mul_en;
    assign shadow_decode_token_promote_en = (shadow_op == OP_TYPE_TOKEN_PROMOTE);
    assign shadow_decode_binary_op = (shadow_op == OP_TYPE_BF16_ADD) || (shadow_op == OP_TYPE_BF16_MUL);

    // src1 index: reuses scalar_idx field for binary ops
    assign active_vec1_idx = instr_bank[active_bank_q][INSTR_SCALAR_LSB+:VECTOR_RF_ADDR_WIDTH];
    assign shadow_vec1_idx = instr_bank[~active_bank_q][INSTR_SCALAR_LSB+:VECTOR_RF_ADDR_WIDTH];

    assign active_lane_supported = decode_align_en || decode_token_promote_en || decode_quant_en || decode_dma_en || decode_bf16_add_en || decode_bf16_mul_en || decode_pe_array_en;
    assign selected_lane_ready   = (decode_align_en && align_lane_ready)
                                 || (decode_token_promote_en && token_promote_ready)
                                 || (decode_quant_en && quant_lane_ready)
                                 || (decode_dma_en && dma_ready)
                                 || (decode_bf16_add_en && bf16_add_lane_ready)
                                 || (decode_bf16_mul_en && bf16_mul_lane_ready)
                                 || (decode_pe_array_en && pe_array_ready);
    assign active_scalar_half_sel = active_func[0];
    assign token_promote_instr_start = active_func[0];
    assign token_promote_score_mode = active_func[2:1];

    // DMA instruction field extraction (uses standard INSTR_*_LSB field positions)
    //   src0   [INSTR_SRC0_LSB   +: VRF_AW]  = vu_reg_index
    //   dst    [INSTR_DST_LSB    +: VRF_AW]  = ext_offset[5:0]
    //   scalar [INSTR_SCALAR_LSB +: SRF_AW]  = ext_offset[11:6]
    //   spare  [31:30]                        = ext_offset[13:12]
    //   func[0]                               = direction (0=load ext->VU, 1=store VU->ext)
    //   func[2:1]                             = vu_resource: 00=vector RF, 01=instr buf, 10=scalar RF
    //   func[8:3]                             = transfer_length-1 (0-63 -> 1-64 words)
    assign dma_vu_reg_index = instr_bank[active_bank_q][INSTR_SRC0_LSB+:VECTOR_RF_ADDR_WIDTH];
    assign dma_ext_offset = {
        instr_bank[active_bank_q][31:30], instr_bank[active_bank_q][INSTR_SCALAR_LSB+:SCALAR_RF_ADDR_WIDTH], instr_bank[active_bank_q][INSTR_DST_LSB+:VECTOR_RF_ADDR_WIDTH]
    };
    assign dma_direction = active_func[0];
    assign dma_vu_resource = active_func[2:1];
    assign dma_transfer_len_field = active_func[8:3];

    // VU-side address: entry-level addressing for vector RF and scalar RF.
    // Vector RF: vu_reg_index selects entry, stride = NUM_VECTOR_RF_BANKS * 8 bytes.
    // Scalar RF: vu_reg_index selects entry, stride = NUM_GROUPS * 8 bytes.
    // Instr buf: word-level addressing (unchanged).
    always_comb begin
        dma_vu_addr = (BASE_ADDR + AXI_ADDR_WIDTH'(`VU_VECTOR_RF_OFFSET)) + (AXI_ADDR_WIDTH'(dma_vu_reg_index) * AXI_ADDR_WIDTH'(NUM_VECTOR_RF_BANKS) * AXI_ADDR_WIDTH'(8));
        case (dma_vu_resource)
            2'b01:   dma_vu_addr = (BASE_ADDR + AXI_ADDR_WIDTH'(`VU_INSTR_BUF_OFFSET)) + (AXI_ADDR_WIDTH'(dma_vu_reg_index) << 3);
            2'b10:   dma_vu_addr = (BASE_ADDR + AXI_ADDR_WIDTH'(`VU_SCALAR_RF_OFFSET)) + (AXI_ADDR_WIDTH'(dma_vu_reg_index) * AXI_ADDR_WIDTH'(NUM_GROUPS) * AXI_ADDR_WIDTH'(8));
            default: ;
        endcase
    end

    // External address: instruction-mode base + offset * 8
    // Load (direction=0): external is source -> use instruction SRC base
    // Store (direction=1): external is destination -> use instruction DST base
    assign dma_ext_addr = (dma_direction == 1'b0)
        ? (dma_instr_src_base_addr + (AXI_ADDR_WIDTH'(dma_ext_offset) << 3))
        : (dma_instr_dst_base_addr + (AXI_ADDR_WIDTH'(dma_ext_offset) << 3));

    // Final src/dst based on direction
    assign dma_computed_src_addr = (dma_direction == 1'b0) ? dma_ext_addr : dma_vu_addr;
    assign dma_computed_dst_addr = (dma_direction == 1'b0) ? dma_vu_addr : dma_ext_addr;
    assign dma_computed_length = (AXI_ADDR_WIDTH'(dma_transfer_len_field) + AXI_ADDR_WIDTH'(1)) << 3;

    // DMA instruction launch: fires on lane_issue_en for DMA instructions
    assign dma_instr_launch = lane_issue_en && decode_dma_en;

    // DMA instruction completion tracking
    assign dma_instr_done = dma_idma_rsp_valid && dma_instr_pending_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) dma_instr_pending_q <= 1'b0;
        else dma_instr_pending_q <= dma_instr_pending_d;
    end

    always_comb begin
        dma_instr_pending_d = dma_instr_pending_q;
        if (dma_instr_launch) dma_instr_pending_d = 1'b1;
        else if (dma_instr_done) dma_instr_pending_d = 1'b0;
    end

    //-----------------------------------------------------------------------------
    // SIMD Execution Lanes
    //-----------------------------------------------------------------------------

    // Per-group compute lanes (LANES_PER_GROUP=16 each, NUM_GROUPS=4)
    generate
        genvar g;
        for (g = 0; g < NUM_GROUPS; g = g + 1) begin : gen_compute_group
            vector_align_lane #(
                .VLEN        (LANES_PER_GROUP),
                .ELEM_WIDTH  (ELEM_WIDTH),
                .SCALAR_WIDTH(SCALAR_WIDTH)
            ) i_align_lane (
                .clk_i          (clk_i),
                .rst_ni         (rst_ni),
                .valid_i        (lane_issue_en && decode_align_en),
                .vec_op_i       (curr_vec_op[g*LANES_PER_GROUP+:LANES_PER_GROUP]),
                .ready_o        (align_lane_ready_g[g]),
                .done_o         (align_lane_done_g[g]),
                .vec_result_o   (align_lane_vec_result_g[g]),
                .vec_write_o    (align_lane_vec_write_g[g]),
                .scalar_result_o(align_lane_scalar_result_g[g]),
                .scalar_write_o (align_lane_scalar_write_g[g])
            );

            token_promotion_unit #(
                .NUM_SEQS   (TP_NUM_SEQS),
                .TILE_SIZE  (TP_TILE_SIZE),
                .ELEM_WIDTH (ELEM_WIDTH),
                .SHIFT_CFG_W(TP_SHIFT_CFG_W),
                .TILE_CNT_W (TP_TILE_CNT_W)
            ) i_token_promotion_unit (
                .clk_i                 (clk_i),
                .rst_ni                (rst_ni),
                .valid_i               (lane_issue_en && decode_token_promote_en),
                .token_start_i         (lane_issue_en && decode_token_promote_en && token_promote_instr_start),
                .vec_op_i              (curr_vec_op[g*LANES_PER_GROUP+:LANES_PER_GROUP]),
                .shared_exp_i          (curr_scalar_op[g][15:0]),
                .score_mode_i          (token_promote_score_mode),
                .shift_cfg_i           (token_promote_shift_cfg),
                .num_tiles_i           (token_promote_num_tiles_cfg),
                .num_seqs_i            (token_promote_num_seqs_cfg),
                .acc_thres_i           (token_promote_acc_thres_cfg),
                .ready_o               (token_promote_ready_g[g]),
                .busy_o                (token_promote_busy_g[g]),
                .instr_done_o          (token_promote_instr_done_g[g]),
                .done_o                (token_promote_done_g[g]),
                .promote_token_o       (token_promote_result_g[g]),
                .token_max_seq_id_o    (token_promote_seq_id_g[g]),
                .token_max_acc_o       (token_promote_acc_g[g]),
                .seq_idx_o             (token_promote_seq_idx_g[g]),
                .tile_idx_o            (token_promote_tile_idx_g[g]),
                .processed_tile_count_o(token_promote_processed_tile_count_g[g])
            );

            vector_quant_lane #(
                .VLEN        (LANES_PER_GROUP),
                .ELEM_WIDTH  (ELEM_WIDTH),
                .FUNC_WIDTH  (FUNC_WIDTH),
                .SCALAR_WIDTH(SCALAR_WIDTH)
            ) i_quant_lane (
                .clk_i          (clk_i),
                .rst_ni         (rst_ni),
                .valid_i        (lane_issue_en && decode_quant_en),
                .vec_op_i       (curr_vec_op[g*LANES_PER_GROUP+:LANES_PER_GROUP]),
                .func_i         (active_func),
                .ready_o        (quant_lane_ready_g[g]),
                .done_o         (quant_lane_done_g[g]),
                .vec_result_o   (quant_lane_vec_result_g[g]),
                .vec_write_o    (quant_lane_vec_write_g[g]),
                .scalar_result_o(quant_lane_scalar_result_g[g]),
                .scalar_write_o (quant_lane_scalar_write_g[g])
            );

            vector_bf16_add_lane #(
                .VLEN      (LANES_PER_GROUP),
                .ELEM_WIDTH(ELEM_WIDTH)
            ) i_bf16_add_lane (
                .clk_i       (clk_i),
                .rst_ni      (rst_ni),
                .valid_i     (lane_issue_en && decode_bf16_add_en),
                .vec_op0_i   (curr_vec_op[g*LANES_PER_GROUP+:LANES_PER_GROUP]),
                .vec_op1_i   (curr_vec_op1[g*LANES_PER_GROUP+:LANES_PER_GROUP]),
                .ready_o     (bf16_add_lane_ready_g[g]),
                .done_o      (bf16_add_lane_done_g[g]),
                .vec_result_o(bf16_add_lane_vec_result_g[g]),
                .vec_write_o (bf16_add_lane_vec_write_g[g])
            );

            vector_bf16_mul_lane #(
                .VLEN      (LANES_PER_GROUP),
                .ELEM_WIDTH(ELEM_WIDTH)
            ) i_bf16_mul_lane (
                .clk_i               (clk_i),
                .rst_ni              (rst_ni),
                .valid_i             (lane_issue_en && decode_bf16_mul_en),
                .vec_op0_i           (curr_vec_op[g*LANES_PER_GROUP+:LANES_PER_GROUP]),
                .vec_op1_i           (curr_vec_op1[g*LANES_PER_GROUP+:LANES_PER_GROUP]),
                .ready_o             (bf16_mul_lane_ready_g[g]),
                .done_o              (bf16_mul_lane_done_g[g]),
                .vec_result_o        (bf16_mul_lane_vec_result_g[g]),
                .vec_write_o         (bf16_mul_lane_vec_write_g[g]),
                .pe_array_mode_i     (pe_array_mode),
                .pe_array_wgt_i      (pe_array_wgt[g*LANES_PER_GROUP+:LANES_PER_GROUP]),
                .pe_array_act_i      (pe_array_act[g*LANES_PER_GROUP+:LANES_PER_GROUP]),
                .pe_array_acc_clear_i(pe_array_acc_clear),
                .pe_array_acc_en_i   (pe_array_acc_en),
                .pe_array_acc_o      (pe_array_acc[g*LANES_PER_GROUP+:LANES_PER_GROUP])
            );
        end
    endgenerate

    //-----------------------------------------------------------------------------
    // PE Array Controller
    //-----------------------------------------------------------------------------

    pe_array_ctrl #(
        .VLEN                (VLEN),
        .ELEM_WIDTH          (ELEM_WIDTH),
        .NUM_GROUPS          (NUM_GROUPS),
        .LANES_PER_GROUP     (LANES_PER_GROUP),
        .VECTOR_RF_ADDR_WIDTH(VECTOR_RF_ADDR_WIDTH)
    ) i_pe_array_ctrl (
        .clk_i           (clk_i),
        .rst_ni          (rst_ni),
        .trigger_i       (lane_issue_en && decode_pe_array_en),
        .writeback_mode_i(active_func[0]),
        .k_count_m1_i    (active_func[6:1]),
        .acc_clear_i     (active_func[7]),
        .int4x8_mode_i   (active_func[8]),
        .wgt_base_i      (active_vec_idx),
        .act_base_i      (active_vec1_idx),
        .ready_o         (pe_array_ready),
        .done_o          (pe_array_done),
        .vrf_read_en_o   (pe_array_vrf_read_en),
        .vrf_read_idx_o  (pe_array_vrf_read_idx),
        .vrf_read_data_i (vrf_rdata_unpacked),
        .pe_mode_o       (pe_array_mode),
        .pe_wgt_o        (pe_array_wgt),
        .pe_act_o        (pe_array_act),
        .pe_acc_clear_o  (pe_array_acc_clear),
        .pe_acc_en_o     (pe_array_acc_en),
        .pe_acc_i        (pe_array_acc),
        .wb_valid_o      (pe_array_wb_valid),
        .wb_vec_result_o (pe_array_wb_vec_result)
    );

    // Capture execution completion -- merge per-group results into full-width vectors.
    // All groups complete simultaneously so group 0 write/done is representative.
    always_comb begin
        integer gi;
        exec_vec_write_d     = exec_vec_write_q;
        exec_scalar_write_d  = exec_scalar_write_q;
        exec_vec_result_d    = exec_vec_result_q;
        exec_scalar_result_d = exec_scalar_result_q;

        if (exec_result_clear) begin
            exec_vec_write_d     = 1'b0;
            exec_scalar_write_d  = '0;
            exec_vec_result_d    = '0;
            exec_scalar_result_d = '0;
        end else if (align_lane_done) begin
            exec_vec_write_d = align_lane_vec_write_g[0];
            for (gi = 0; gi < NUM_GROUPS; gi = gi + 1) begin
                exec_vec_result_d[gi*LANES_PER_GROUP+:LANES_PER_GROUP] = align_lane_vec_result_g[gi];
                exec_scalar_write_d[gi]                                = align_lane_scalar_write_g[gi];
                exec_scalar_result_d[gi]                               = align_lane_scalar_result_g[gi];
            end
        end else if (quant_lane_done) begin
            exec_vec_write_d = quant_lane_vec_write_g[0];
            for (gi = 0; gi < NUM_GROUPS; gi = gi + 1) begin
                exec_vec_result_d[gi*LANES_PER_GROUP+:LANES_PER_GROUP] = quant_lane_vec_result_g[gi];
                exec_scalar_write_d[gi]                                = quant_lane_scalar_write_g[gi];
                exec_scalar_result_d[gi]                               = quant_lane_scalar_result_g[gi];
            end
        end else if (bf16_add_lane_done) begin
            exec_vec_write_d     = bf16_add_lane_vec_write_g[0];
            exec_scalar_write_d  = '0;
            exec_scalar_result_d = '0;
            for (gi = 0; gi < NUM_GROUPS; gi = gi + 1) begin
                exec_vec_result_d[gi*LANES_PER_GROUP+:LANES_PER_GROUP] = bf16_add_lane_vec_result_g[gi];
            end
        end else if (bf16_mul_lane_done) begin
            exec_vec_write_d     = bf16_mul_lane_vec_write_g[0];
            exec_scalar_write_d  = '0;
            exec_scalar_result_d = '0;
            for (gi = 0; gi < NUM_GROUPS; gi = gi + 1) begin
                exec_vec_result_d[gi*LANES_PER_GROUP+:LANES_PER_GROUP] = bf16_mul_lane_vec_result_g[gi];
            end
        end else if (pe_array_wb_valid) begin
            exec_vec_write_d     = 1'b1;
            exec_scalar_write_d  = '0;
            exec_vec_result_d    = pe_array_wb_vec_result;
            exec_scalar_result_d = '0;
        end else if (token_promote_instr_done) begin
            exec_vec_write_d     = 1'b0;
            exec_scalar_write_d  = '0;
            exec_vec_result_d    = '0;
            exec_scalar_result_d = '0;
        end else if (dma_instr_done) begin
            exec_vec_write_d     = 1'b0;
            exec_scalar_write_d  = '0;
            exec_vec_result_d    = '0;
            exec_scalar_result_d = '0;
        end else if (pe_array_done && !pe_array_wb_valid) begin
            // PE array compute (non-writeback) done -- no VRF write
            exec_vec_write_d     = 1'b0;
            exec_scalar_write_d  = '0;
            exec_vec_result_d    = '0;
            exec_scalar_result_d = '0;
        end
    end

    //-----------------------------------------------------------------------------
    // DMA Engine (iDMA backend)
    //-----------------------------------------------------------------------------

    // DMA busy aggregation
    assign dma_busy_aggregated = dma_idma_busy.buffer_busy   | dma_idma_busy.r_dp_busy     |
                                 dma_idma_busy.w_dp_busy     | dma_idma_busy.r_leg_busy     |
                                 dma_idma_busy.w_leg_busy    | dma_idma_busy.eh_fsm_busy    |
                                 dma_idma_busy.eh_cnt_busy   | dma_idma_busy.raw_coupler_busy;
    assign dma_busy = dma_busy_aggregated;
    assign dma_error = dma_idma_rsp.error;
    assign dma_ready = dma_idma_req_ready && !dma_busy_aggregated;
    assign dma_active = dma_busy_aggregated;

    // CPU launch uses the architectural DMA request registers directly.
    // DMA instructions instead build a one-shot backend request from the
    // instruction-mode base registers plus the encoded offset/resource fields.
    always_comb begin
        dma_req_src_addr = dma_src_addr;
        dma_req_dst_addr = dma_dst_addr;
        dma_req_length   = dma_length;
        dma_req_config   = dma_config;

        if (dma_instr_launch) begin
            dma_req_src_addr = dma_computed_src_addr;
            dma_req_dst_addr = dma_computed_dst_addr;
            dma_req_length   = dma_computed_length;
            dma_req_config   = 32'b0;
        end
    end

    // Map DMA config registers to iDMA request
    always_comb begin
        dma_idma_req                     = '0;
        dma_idma_req.src_addr            = dma_req_src_addr;
        dma_idma_req.dst_addr            = dma_req_dst_addr;
        dma_idma_req.length              = dma_req_length;
        dma_idma_req.user                = '0;
        dma_idma_req.opt.src_protocol    = idma_pkg::AXI;
        dma_idma_req.opt.dst_protocol    = idma_pkg::AXI;
        dma_idma_req.opt.src.burst       = axi_pkg::BURST_INCR;
        dma_idma_req.opt.dst.burst       = axi_pkg::BURST_INCR;
        dma_idma_req.opt.src.cache       = axi_pkg::CACHE_MODIFIABLE;
        dma_idma_req.opt.dst.cache       = axi_pkg::CACHE_MODIFIABLE;
        dma_idma_req.opt.beo.decouple_aw = dma_req_config[0];
        dma_idma_req.opt.beo.decouple_rw = dma_req_config[1];
        dma_idma_req.opt.last            = 1'b1;
    end

    assign dma_idma_req_valid = (dma_launch || dma_instr_launch) && !dma_busy_aggregated;

    idma_backend_rw_axi #(
        .DataWidth           (AXI_DATA_WIDTH),
        .AddrWidth           (AXI_ADDR_WIDTH),
        .UserWidth           (1),
        .AxiIdWidth          (4),
        .TFLenWidth          (AXI_ADDR_WIDTH),
        .idma_req_t          (vu_dma_idma_req_t),
        .idma_rsp_t          (vu_dma_idma_rsp_t),
        .idma_eh_req_t       (idma_pkg::idma_eh_req_t),
        .idma_busy_t         (idma_pkg::idma_busy_t),
        .axi_req_t           (vu_dma_axi_req_t),
        .axi_rsp_t           (vu_dma_axi_resp_t),
        .read_meta_channel_t (vu_dma_axi_ar_chan_t),
        .write_meta_channel_t(vu_dma_axi_aw_chan_t)
    ) i_idma_backend (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .testmode_i     (1'b0),
        .idma_req_i     (dma_idma_req),
        .req_valid_i    (dma_idma_req_valid),
        .req_ready_o    (dma_idma_req_ready),
        .idma_rsp_o     (dma_idma_rsp),
        .rsp_valid_o    (dma_idma_rsp_valid),
        .rsp_ready_i    (1'b1),
        .idma_eh_req_i  ('0),
        .eh_req_valid_i (1'b0),
        .eh_req_ready_o (),
        .axi_read_req_o (dma_axi_read_req),
        .axi_read_rsp_i (dma_axi_read_rsp),
        .axi_write_req_o(dma_axi_write_req),
        .axi_write_rsp_i(dma_axi_write_rsp),
        .busy_o         (dma_idma_busy)
    );

    // Combine read and write AXI channels into single master port
    always_comb begin
        dma_axi_m_req          = '0;
        // AR channel (from read port)
        dma_axi_m_req.ar       = dma_axi_read_req.ar;
        dma_axi_m_req.ar_valid = dma_axi_read_req.ar_valid;
        dma_axi_m_req.r_ready  = dma_axi_read_req.r_ready;
        // AW channel (from write port)
        dma_axi_m_req.aw       = dma_axi_write_req.aw;
        dma_axi_m_req.aw_valid = dma_axi_write_req.aw_valid;
        dma_axi_m_req.b_ready  = dma_axi_write_req.b_ready;
        // W channel (from write port)
        dma_axi_m_req.w        = dma_axi_write_req.w;
        dma_axi_m_req.w_valid  = dma_axi_write_req.w_valid;
    end

    // Split master response to read and write ports
    always_comb begin
        dma_axi_read_rsp           = '0;
        dma_axi_write_rsp          = '0;
        // Read response
        dma_axi_read_rsp.ar_ready  = dma_axi_m_rsp.ar_ready;
        dma_axi_read_rsp.r         = dma_axi_m_rsp.r;
        dma_axi_read_rsp.r_valid   = dma_axi_m_rsp.r_valid;
        // Write response
        dma_axi_write_rsp.aw_ready = dma_axi_m_rsp.aw_ready;
        dma_axi_write_rsp.w_ready  = dma_axi_m_rsp.w_ready;
        dma_axi_write_rsp.b        = dma_axi_m_rsp.b;
        dma_axi_write_rsp.b_valid  = dma_axi_m_rsp.b_valid;
    end

    `AXI_ASSIGN_FROM_REQ(master, dma_axi_m_req)
    `AXI_ASSIGN_TO_RESP(dma_axi_m_rsp, master)

endmodule
