//-----------------------------------------------------------------------------
// File: vector_unit_ctrl.sv
// Description: Scheduler and retire control FSM for vector_unit.
//              Supports binary ops (BF16 add/mul) via VU_FILL_ACTIVE_VEC2
//              state and extended shadow prefill (PREFILL_VEC2).
//              Supports PE array execution via dedicated done path.
//-----------------------------------------------------------------------------

module vector_unit_ctrl #(
    parameter integer VECTOR_RF_ADDR_WIDTH = 5,
    parameter integer SCALAR_RF_ADDR_WIDTH = 5,
    parameter integer INSTR_COUNT_WIDTH    = 6
) (
    input logic clk_i,
    input logic rst_ni,

    input logic                         start_pulse_i,
    input logic                         clear_done_pulse_i,
    input logic                         loop_mode_i,
    input logic [INSTR_COUNT_WIDTH-1:0] instr_count_i,

    input logic                                                 decode_dma_en_i,
    input logic                                                 decode_binary_op_i,
    input logic                                                 decode_pe_array_en_i,
    input logic                                                 decode_token_promote_en_i,
    input logic                                                 shadow_decode_token_promote_en_i,
    input logic                                                 shadow_decode_binary_op_i,
    input logic                                                 active_lane_supported_i,
    input logic                                                 selected_lane_ready_i,
    input logic                                                 active_scalar_half_sel_i,
    input logic                      [VECTOR_RF_ADDR_WIDTH-1:0] active_dst_idx_i,
    input logic                      [SCALAR_RF_ADDR_WIDTH-1:0] active_scalar_idx_i,
    input vector_unit_pkg::op_type_t                            active_op_i,

    input logic exec_done_i,
    input logic exec_vec_write_pending_i,

    output vector_unit_pkg::vu_state_t                              vu_state_o,
    output vector_unit_pkg::prefill_state_t                         prefill_state_o,
    output logic                                                    active_bank_o,
    output logic                            [                  1:0] bank_valid_o,
    output logic                                                    run_active_o,
    output logic                                                    done_o,
    output logic                            [INSTR_COUNT_WIDTH-1:0] pc_o,
    output logic                                                    instr_valid_o,
    output logic                                                    exec_pending_o,

    output logic instr_req_o,
    output logic lane_issue_en_o,
    output logic vrf_read_vec_en_o,
    output logic vrf_read_vec1_en_o,
    output logic vrf_writeback_en_o,
    output logic scalar_rf_read_active_en_o,
    output logic scalar_rf_read_shadow_en_o,
    output logic capture_active_vec_o,
    output logic capture_active_vec1_o,
    output logic capture_shadow_vec_o,
    output logic capture_shadow_vec1_o,
    output logic capture_active_scalar_o,
    output logic capture_shadow_scalar_o,
    output logic exec_result_clear_o,

    output logic                      [VECTOR_RF_ADDR_WIDTH-1:0] issued_dst_idx_o,
    output logic                      [SCALAR_RF_ADDR_WIDTH-1:0] issued_scalar_idx_o,
    output vector_unit_pkg::op_type_t                            issued_op_o,
    output logic                                                 issued_scalar_half_sel_o
);

    import vector_unit_pkg::*;

    // -------------------------------------------------------------------------
    // Control state
    // -------------------------------------------------------------------------

    vu_state_t vu_state_d, vu_state_q;
    prefill_state_t prefill_state_d, prefill_state_q;
    logic active_bank_d, active_bank_q;
    logic [1:0] bank_valid_d, bank_valid_q;
    logic run_active_d, run_active_q;
    logic done_d, done_q;
    logic [INSTR_COUNT_WIDTH-1:0] pc_d, pc_q;
    logic instr_valid_d, instr_valid_q;
    logic exec_pending_d, exec_pending_q;
    logic [VECTOR_RF_ADDR_WIDTH-1:0] issued_dst_idx_d, issued_dst_idx_q;
    logic [SCALAR_RF_ADDR_WIDTH-1:0] issued_scalar_idx_d, issued_scalar_idx_q;
    op_type_t issued_op_d, issued_op_q;
    logic issued_scalar_half_sel_d, issued_scalar_half_sel_q;
    logic capture_active_vec_d, capture_active_vec_q;
    logic capture_active_vec1_d, capture_active_vec1_q;
    logic capture_shadow_vec_d, capture_shadow_vec_q;
    logic capture_shadow_vec1_d, capture_shadow_vec1_q;
    logic capture_active_scalar_d, capture_active_scalar_q;
    logic capture_shadow_scalar_d, capture_shadow_scalar_q;
    logic shadow_ready;
    logic fetch_next_instr;
    logic start_run_req;

    // -------------------------------------------------------------------------
    // Control helpers
    // -------------------------------------------------------------------------

    assign shadow_ready     = bank_valid_q[~active_bank_q];
    assign fetch_next_instr = run_active_q && (pc_q < instr_count_i);
    assign start_run_req    = start_pulse_i && !run_active_q && (instr_count_i != '0);

    // -------------------------------------------------------------------------
    // State registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            vu_state_q               <= VU_IDLE;
            prefill_state_q          <= PREFILL_IDLE;
            active_bank_q            <= 1'b0;
            bank_valid_q             <= 2'b00;
            run_active_q             <= 1'b0;
            done_q                   <= 1'b0;
            pc_q                     <= '0;
            instr_valid_q            <= 1'b0;
            exec_pending_q           <= 1'b0;
            issued_dst_idx_q         <= '0;
            issued_scalar_idx_q      <= '0;
            issued_op_q              <= OP_TYPE_QUANT;
            issued_scalar_half_sel_q <= 1'b0;
            capture_active_vec_q     <= 1'b0;
            capture_active_vec1_q    <= 1'b0;
            capture_shadow_vec_q     <= 1'b0;
            capture_shadow_vec1_q    <= 1'b0;
            capture_active_scalar_q  <= 1'b0;
            capture_shadow_scalar_q  <= 1'b0;
        end else begin
            vu_state_q               <= vu_state_d;
            prefill_state_q          <= prefill_state_d;
            active_bank_q            <= active_bank_d;
            bank_valid_q             <= bank_valid_d;
            run_active_q             <= run_active_d;
            done_q                   <= done_d;
            pc_q                     <= pc_d;
            instr_valid_q            <= instr_valid_d;
            exec_pending_q           <= exec_pending_d;
            issued_dst_idx_q         <= issued_dst_idx_d;
            issued_scalar_idx_q      <= issued_scalar_idx_d;
            issued_op_q              <= issued_op_d;
            issued_scalar_half_sel_q <= issued_scalar_half_sel_d;
            capture_active_vec_q     <= capture_active_vec_d;
            capture_active_vec1_q    <= capture_active_vec1_d;
            capture_shadow_vec_q     <= capture_shadow_vec_d;
            capture_shadow_vec1_q    <= capture_shadow_vec1_d;
            capture_active_scalar_q  <= capture_active_scalar_d;
            capture_shadow_scalar_q  <= capture_shadow_scalar_d;
        end
    end

    // -------------------------------------------------------------------------
    // Scheduler and retire control
    // -------------------------------------------------------------------------

    always_comb begin
        vu_state_d                 = vu_state_q;
        prefill_state_d            = prefill_state_q;
        active_bank_d              = active_bank_q;
        bank_valid_d               = bank_valid_q;
        run_active_d               = run_active_q;
        done_d                     = done_q;
        pc_d                       = pc_q;
        instr_valid_d              = 1'b0;
        exec_pending_d             = exec_pending_q;
        issued_dst_idx_d           = issued_dst_idx_q;
        issued_scalar_idx_d        = issued_scalar_idx_q;
        issued_op_d                = issued_op_q;
        issued_scalar_half_sel_d   = issued_scalar_half_sel_q;
        capture_active_vec_d       = 1'b0;
        capture_active_vec1_d      = 1'b0;
        capture_shadow_vec_d       = 1'b0;
        capture_shadow_vec1_d      = 1'b0;
        capture_active_scalar_d    = 1'b0;
        capture_shadow_scalar_d    = 1'b0;

        lane_issue_en_o            = 1'b0;
        instr_req_o                = 1'b0;
        vrf_read_vec_en_o          = 1'b0;
        vrf_read_vec1_en_o         = 1'b0;
        vrf_writeback_en_o         = 1'b0;
        scalar_rf_read_active_en_o = (vu_state_q == VU_FILL_ACTIVE_VEC) && decode_token_promote_en_i;
        scalar_rf_read_shadow_en_o = (vu_state_q == VU_EXEC_ACTIVE) && (prefill_state_q == PREFILL_VEC) && shadow_decode_token_promote_en_i;
        capture_active_vec_o       = capture_active_vec_q;
        capture_active_vec1_o      = capture_active_vec1_q;
        capture_shadow_vec_o       = capture_shadow_vec_q;
        capture_shadow_vec1_o      = capture_shadow_vec1_q;
        capture_active_scalar_o    = capture_active_scalar_q;
        capture_shadow_scalar_o    = capture_shadow_scalar_q;
        exec_result_clear_o        = 1'b0;

        case (vu_state_q)
            VU_IDLE: begin
                if (instr_valid_q) begin
                    vu_state_d = VU_FILL_ACTIVE_VEC;
                end else if (start_run_req) begin
                    run_active_d = 1'b1;
                    done_d       = 1'b0;
                    pc_d         = '0;
                    vu_state_d   = VU_FETCH_ACTIVE;
                end else if (fetch_next_instr) begin
                    vu_state_d = VU_FETCH_ACTIVE;
                end else if (run_active_q && loop_mode_i && (instr_count_i != '0)) begin
                    pc_d       = '0;
                    vu_state_d = VU_FETCH_ACTIVE;
                end else if (run_active_q) begin
                    run_active_d = 1'b0;
                    done_d       = 1'b1;
                end
            end
            VU_FETCH_ACTIVE: begin
                if (pc_q < instr_count_i) begin
                    instr_req_o   = 1'b1;
                    instr_valid_d = 1'b1;
                    pc_d          = pc_q + 1'b1;
                end
                vu_state_d = VU_IDLE;
            end
            VU_FILL_ACTIVE_VEC: begin
                if (decode_dma_en_i || decode_pe_array_en_i) begin
                    // DMA and PE array instructions don't use standard vector operands
                    bank_valid_d[active_bank_q] = 1'b1;
                    vu_state_d                  = VU_ISSUE_ACTIVE;
                end else begin
                    vrf_read_vec_en_o           = 1'b1;
                    bank_valid_d[active_bank_q] = 1'b1;
                    capture_active_vec_d        = 1'b1;
                    capture_active_scalar_d     = decode_token_promote_en_i;
                    if (decode_binary_op_i) begin
                        // Binary ops need a second VRF read for src1
                        vu_state_d = VU_FILL_ACTIVE_VEC2;
                    end else begin
                        vu_state_d = VU_ISSUE_ACTIVE;
                    end
                end
            end
            VU_FILL_ACTIVE_VEC2: begin
                // Read src1 from VRF (address from scalar_idx field, repurposed)
                vrf_read_vec1_en_o    = 1'b1;
                capture_active_vec1_d = 1'b1;
                vu_state_d            = VU_ISSUE_ACTIVE;
            end
            VU_ISSUE_ACTIVE: begin
                if (active_lane_supported_i && selected_lane_ready_i) begin
                    lane_issue_en_o          = 1'b1;
                    issued_dst_idx_d         = active_dst_idx_i;
                    issued_scalar_idx_d      = active_scalar_idx_i;
                    issued_op_d              = active_op_i;
                    issued_scalar_half_sel_d = active_scalar_half_sel_i;
                    vu_state_d               = VU_EXEC_ACTIVE;
                end else if (!active_lane_supported_i) begin
                    bank_valid_d[active_bank_q] = 1'b0;
                    vu_state_d                  = VU_IDLE;
                end
            end
            VU_EXEC_ACTIVE: begin
                case (prefill_state_q)
                    PREFILL_IDLE: begin
                        if (!shadow_ready && instr_valid_q) begin
                            prefill_state_d = PREFILL_VEC;
                        end else if (!shadow_ready && fetch_next_instr) begin
                            instr_req_o   = 1'b1;
                            instr_valid_d = 1'b1;
                            pc_d          = pc_q + 1'b1;
                        end
                    end
                    PREFILL_VEC: begin
                        vrf_read_vec_en_o            = 1'b1;
                        bank_valid_d[~active_bank_q] = 1'b1;
                        capture_shadow_vec_d         = 1'b1;
                        capture_shadow_scalar_d      = shadow_decode_token_promote_en_i;
                        if (shadow_decode_binary_op_i) begin
                            // Shadow instruction is binary -- need src1 prefill too
                            prefill_state_d = PREFILL_VEC2;
                        end else begin
                            prefill_state_d = PREFILL_READY;
                        end
                    end
                    PREFILL_VEC2: begin
                        // Shadow src1 prefill
                        vrf_read_vec1_en_o    = 1'b1;
                        capture_shadow_vec1_d = 1'b1;
                        prefill_state_d       = PREFILL_READY;
                    end
                    PREFILL_READY: begin
                    end
                    default: begin
                        prefill_state_d = PREFILL_IDLE;
                    end
                endcase

                if (exec_done_i) begin
                    exec_pending_d = 1'b1;
                end

                if (exec_pending_q && (((prefill_state_q == PREFILL_IDLE) && (prefill_state_d == PREFILL_IDLE)) || (prefill_state_q == PREFILL_READY))) begin
                    vu_state_d = VU_WRITEBACK_ACTIVE;
                end
            end
            VU_WRITEBACK_ACTIVE: begin
                vrf_writeback_en_o = exec_vec_write_pending_i;

                if (shadow_ready && (prefill_state_q == PREFILL_READY)) begin
                    exec_result_clear_o         = 1'b1;
                    exec_pending_d              = 1'b0;
                    bank_valid_d[active_bank_q] = 1'b0;
                    active_bank_d               = ~active_bank_q;
                    prefill_state_d             = PREFILL_IDLE;
                    vu_state_d                  = VU_ISSUE_ACTIVE;
                end else if (!shadow_ready && (prefill_state_q == PREFILL_IDLE)) begin
                    exec_result_clear_o         = 1'b1;
                    exec_pending_d              = 1'b0;
                    bank_valid_d[active_bank_q] = 1'b0;
                    prefill_state_d             = PREFILL_IDLE;
                    vu_state_d                  = VU_IDLE;
                end
            end
            default: begin
                vu_state_d      = VU_IDLE;
                prefill_state_d = PREFILL_IDLE;
            end
        endcase

        if (clear_done_pulse_i) begin
            done_d = 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // State exports
    // -------------------------------------------------------------------------

    assign vu_state_o               = vu_state_q;
    assign prefill_state_o          = prefill_state_q;
    assign active_bank_o            = active_bank_q;
    assign bank_valid_o             = bank_valid_q;
    assign run_active_o             = run_active_q;
    assign done_o                   = done_q;
    assign pc_o                     = pc_q;
    assign instr_valid_o            = instr_valid_q;
    assign exec_pending_o           = exec_pending_q;
    assign issued_dst_idx_o         = issued_dst_idx_q;
    assign issued_scalar_idx_o      = issued_scalar_idx_q;
    assign issued_op_o              = issued_op_q;
    assign issued_scalar_half_sel_o = issued_scalar_half_sel_q;

endmodule

