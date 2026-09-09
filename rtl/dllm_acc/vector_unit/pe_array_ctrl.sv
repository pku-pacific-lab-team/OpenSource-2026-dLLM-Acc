//-----------------------------------------------------------------------------
// File: pe_array_ctrl.sv
// Description: Controller for the 4x16 output-stationary PE array.
//              Manages the K-loop iteration, VRF reads for activation and
//              weight data, sub-row operand extraction, and writeback.
//
//              Weight is always INT4 (4 packed per 16-bit element).
//              Activation is INT4 (4 packed) or INT8 (2 packed) per config.
//
//              K-loop flow (accounting for 1-cycle SRAM read latency):
//                1. PE_LOAD_ACT:  Drive VRF address for activation row
//                2. PE_CAP_ACT:   Capture activation data (available 1 cycle later).
//                                 Simultaneously drive VRF address for weight row.
//                3. PE_CAP_WGT:   Capture weight data.
//                4. PE_COMPUTE:   Process K-batches from buffered data (1 cycle/batch).
//                5. When weight row exhausted: PE_LOAD_WGT -> PE_CAP_WGT -> PE_COMPUTE
//                6. When act row exhausted: back to PE_LOAD_ACT
//                7. On completion: PE_DONE
//
//              VRF data layout (INT4x4 mode, dense packed):
//                Weight row:  elements [b*16+c] = 4 INT4 weights for column c, K-batch b
//                             4 K-batches per row (16 K-elements per row)
//                Act row:     elements [b*4+r] = 4 INT4 acts for row r, K-batch b
//                             16 K-batches per row (64 K-elements per row)
//
//              INT4x8 mode: same weight packing. Activation uses 2xINT8 per element.
//                Weight row:  8 K-batches per row (16 K-elements per row, 2 per batch)
//                Act row:     16 K-batches per row (32 K-elements per row)
//-----------------------------------------------------------------------------

module pe_array_ctrl #(
    parameter integer VLEN                 = 64,
    parameter integer ELEM_WIDTH           = 16,
    parameter integer NUM_GROUPS           = 4,
    parameter integer LANES_PER_GROUP      = 16,
    parameter integer VECTOR_RF_ADDR_WIDTH = 6
) (
    input logic clk_i,
    input logic rst_ni,

    // Instruction interface (from VU top-level decode)
    input logic                            trigger_i,         // lane_issue_en for PE_ARRAY op
    input logic                            writeback_mode_i,  // func[0]: 0=compute, 1=writeback
    input logic [                     5:0] k_count_m1_i,      // func[6:1]: k_count - 1
    input logic                            acc_clear_i,       // func[7]
    input logic                            int4x8_mode_i,     // func[8]: 0=INT4x4, 1=INT4x8
    input logic [VECTOR_RF_ADDR_WIDTH-1:0] wgt_base_i,        // src0: weight base VRF row
    input logic [VECTOR_RF_ADDR_WIDTH-1:0] act_base_i,        // scalar_idx: act base VRF row

    // Status
    output logic ready_o,
    output logic done_o,

    // VRF read port (active during K-loop)
    output logic                                            vrf_read_en_o,
    output logic [VECTOR_RF_ADDR_WIDTH-1:0]                 vrf_read_idx_o,
    input  logic [                VLEN-1:0][ELEM_WIDTH-1:0] vrf_read_data_i, // raw unpacked SRAM rdata

    // PE interface (drives the configurable_mul_pe array in BF16 mul lane)
    output logic [     1:0]       pe_mode_o,
    output logic [VLEN-1:0][15:0] pe_wgt_o,
    output logic [VLEN-1:0][15:0] pe_act_o,
    output logic                  pe_acc_clear_o,
    output logic                  pe_acc_en_o,

    // Writeback: 64 accumulator values -> exec result
    input  logic signed [VLEN-1:0][          15:0] pe_acc_i,
    output logic                                   wb_valid_o,
    output logic        [VLEN-1:0][ELEM_WIDTH-1:0] wb_vec_result_o
);

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------
    typedef enum logic [3:0] {
        PE_IDLE,
        PE_CLEAR_ACC,
        PE_LOAD_ACT,   // Drive VRF addr for activation row
        PE_CAP_ACT,    // Capture act data; drive VRF addr for weight row
        PE_CAP_WGT,    // Capture weight data
        PE_COMPUTE,    // Process K-batches from buffered data
        PE_LOAD_WGT,   // Drive VRF addr for next weight row (mid K-loop)
        PE_WRITEBACK,
        PE_DONE
    } pe_state_t;

    pe_state_t state_d, state_q;

    logic [5:0] k_total_d, k_total_q;  // total K-batches to process
    logic [5:0] k_done_d, k_done_q;  // K-batches completed so far
    logic [2:0] k_sub_d, k_sub_q;  // sub-batch within current weight row
    logic [4:0] act_sub_d, act_sub_q;  // sub-batch within current activation row
    logic [VECTOR_RF_ADDR_WIDTH-1:0] wgt_row_d, wgt_row_q;  // current weight VRF row
    logic [VECTOR_RF_ADDR_WIDTH-1:0] act_row_d, act_row_q;  // current activation VRF row
    logic mode_d, mode_q;  // 0=INT4x4, 1=INT4x8

    logic [VLEN-1:0][ELEM_WIDTH-1:0] act_reg_d, act_reg_q;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] wgt_reg_d, wgt_reg_q;

    // K-batches per row
    // Weight (always INT4, 4 per element, 16 elements per K-batch):
    //   INT4x4: 4 K-batches/row (each uses all 4 nibbles per element)
    //   INT4x8: 8 K-batches/row (each uses 2 nibbles per element)
    // Activation:
    //   INT4x4: 16 K-batches/row (4 elements per batch, 64/4 = 16)
    //   INT4x8: 16 K-batches/row (4 elements per batch of 2 INT8, 64/4 = 16)
    localparam integer WGT_BATCHES_INT4X4 = 4;
    localparam integer WGT_BATCHES_INT4X8 = 8;
    localparam integer ACT_BATCHES_PER_ROW = 16;  // same for both modes

    logic   [3:0] wgt_batches_per_row;
    logic         wgt_row_exhausted;
    logic         act_row_exhausted;
    logic         k_loop_done;

    integer       pe_row_iter;
    integer       pe_lane_iter;

    assign wgt_batches_per_row = mode_q ? 4'(WGT_BATCHES_INT4X8) : 4'(WGT_BATCHES_INT4X4);
    assign wgt_row_exhausted   = (k_sub_q == (wgt_batches_per_row[2:0] - 3'd1));
    assign act_row_exhausted   = (act_sub_q == 5'(ACT_BATCHES_PER_ROW - 1));
    assign k_loop_done         = (k_done_q == (k_total_q - 6'd1));

    function automatic logic [15:0] int4x8_weight_slice(input logic [15:0] packed_wgt_i, input logic sub_batch_sel_i);
        if (sub_batch_sel_i) begin
            int4x8_weight_slice = {8'b0, packed_wgt_i[15:8]};
        end else begin
            int4x8_weight_slice = {8'b0, packed_wgt_i[7:0]};
        end
    endfunction

    // -------------------------------------------------------------------------
    // Status outputs
    // -------------------------------------------------------------------------
    assign ready_o   = (state_q == PE_IDLE);
    assign done_o    = (state_q == PE_DONE) || (state_q == PE_WRITEBACK);

    // -------------------------------------------------------------------------
    // PE mode output
    // -------------------------------------------------------------------------
    assign pe_mode_o = (state_q == PE_IDLE) ? 2'b00 : mode_q ? 2'b01 : 2'b10;

    // -------------------------------------------------------------------------
    // Controller state
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q   <= PE_IDLE;
            k_total_q <= '0;
            k_done_q  <= '0;
            k_sub_q   <= '0;
            act_sub_q <= '0;
            wgt_row_q <= '0;
            act_row_q <= '0;
            mode_q    <= 1'b0;
        end else begin
            state_q   <= state_d;
            k_total_q <= k_total_d;
            k_done_q  <= k_done_d;
            k_sub_q   <= k_sub_d;
            act_sub_q <= act_sub_d;
            wgt_row_q <= wgt_row_d;
            act_row_q <= act_row_d;
            mode_q    <= mode_d;
        end
    end

    always_comb begin
        state_d   = state_q;
        k_total_d = k_total_q;
        k_done_d  = k_done_q;
        k_sub_d   = k_sub_q;
        act_sub_d = act_sub_q;
        wgt_row_d = wgt_row_q;
        act_row_d = act_row_q;
        mode_d    = mode_q;

        case (state_q)
            PE_IDLE: begin
                if (trigger_i && writeback_mode_i) begin
                    state_d = PE_WRITEBACK;
                end else if (trigger_i && !writeback_mode_i) begin
                    state_d   = acc_clear_i ? PE_CLEAR_ACC : PE_LOAD_ACT;
                    k_total_d = k_count_m1_i + 6'd1;
                    k_done_d  = '0;
                    k_sub_d   = '0;
                    act_sub_d = '0;
                    wgt_row_d = wgt_base_i;
                    act_row_d = act_base_i;
                    mode_d    = int4x8_mode_i;
                end
            end
            PE_CLEAR_ACC: begin
                state_d = PE_LOAD_ACT;
            end
            PE_LOAD_ACT: begin
                state_d = PE_CAP_ACT;
            end
            PE_CAP_ACT: begin
                state_d = PE_CAP_WGT;
            end
            PE_CAP_WGT: begin
                state_d = PE_COMPUTE;
                k_sub_d = '0;
            end
            PE_COMPUTE: begin
                k_done_d  = k_done_q + 6'd1;
                k_sub_d   = k_sub_q + 3'd1;
                act_sub_d = act_sub_q + 5'd1;

                if (wgt_row_exhausted && !k_loop_done) begin
                    wgt_row_d = wgt_row_q + VECTOR_RF_ADDR_WIDTH'(1);
                end
                if (act_row_exhausted && !k_loop_done) begin
                    act_row_d = act_row_q + VECTOR_RF_ADDR_WIDTH'(1);
                end

                if (k_loop_done) begin
                    state_d = PE_DONE;
                end else if (wgt_row_exhausted && act_row_exhausted) begin
                    state_d = PE_LOAD_ACT;
                end else if (wgt_row_exhausted) begin
                    state_d = PE_LOAD_WGT;
                end
            end
            PE_LOAD_WGT: begin
                state_d = PE_CAP_WGT;
            end
            PE_WRITEBACK: begin
                // Go directly to IDLE -- done_o is already asserted in this state,
                // so exec_done and wb_valid fire on the same cycle.
                state_d = PE_IDLE;
            end
            PE_DONE: begin
                state_d = PE_IDLE;
            end
            default: begin
                state_d = PE_IDLE;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Buffered VRF rows
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            act_reg_q <= '0;
            wgt_reg_q <= '0;
        end else begin
            act_reg_q <= act_reg_d;
            wgt_reg_q <= wgt_reg_d;
        end
    end

    always_comb begin
        act_reg_d = act_reg_q;
        wgt_reg_d = wgt_reg_q;

        if (state_q == PE_CAP_ACT) begin
            act_reg_d = vrf_read_data_i;
        end
        if (state_q == PE_CAP_WGT) begin
            wgt_reg_d = vrf_read_data_i;
        end
    end

    // -------------------------------------------------------------------------
    // VRF read control
    // -------------------------------------------------------------------------
    always_comb begin
        vrf_read_en_o  = 1'b0;
        vrf_read_idx_o = '0;

        case (state_q)
            PE_LOAD_ACT: begin
                vrf_read_en_o  = 1'b1;
                vrf_read_idx_o = act_row_q;
            end
            PE_CAP_ACT: begin
                // Pipeline: while capturing act, drive weight address
                vrf_read_en_o  = 1'b1;
                vrf_read_idx_o = wgt_row_q;
            end
            PE_LOAD_WGT: begin
                vrf_read_en_o  = 1'b1;
                vrf_read_idx_o = wgt_row_q;
            end
            default: ;
        endcase
    end

    // -------------------------------------------------------------------------
    // Operand extraction: from buffered rows to per-PE inputs
    // -------------------------------------------------------------------------
    always_comb begin
        pe_wgt_o = '0;
        pe_act_o = '0;

        if (state_q == PE_COMPUTE) begin
            if (!mode_q) begin
                // ---- INT4x4 mode ----
                for (pe_row_iter = 0; pe_row_iter < NUM_GROUPS; pe_row_iter = pe_row_iter + 1) begin
                    for (pe_lane_iter = 0; pe_lane_iter < LANES_PER_GROUP; pe_lane_iter = pe_lane_iter + 1) begin
                        pe_wgt_o[pe_row_iter*LANES_PER_GROUP+pe_lane_iter] = wgt_reg_q[{k_sub_q[1:0], 4'(pe_lane_iter)}];
                        pe_act_o[pe_row_iter*LANES_PER_GROUP+pe_lane_iter] = act_reg_q[{act_sub_q[3:0], 2'(pe_row_iter)}];
                    end
                end
            end else begin
                // ---- INT4x8 mode ----
                for (pe_row_iter = 0; pe_row_iter < NUM_GROUPS; pe_row_iter = pe_row_iter + 1) begin
                    for (pe_lane_iter = 0; pe_lane_iter < LANES_PER_GROUP; pe_lane_iter = pe_lane_iter + 1) begin
                        pe_wgt_o[pe_row_iter*LANES_PER_GROUP+pe_lane_iter] = int4x8_weight_slice(wgt_reg_q[{k_sub_q[2:1], 4'(pe_lane_iter)}], k_sub_q[0]);
                        pe_act_o[pe_row_iter*LANES_PER_GROUP+pe_lane_iter] = act_reg_q[{act_sub_q[3:0], 2'(pe_row_iter)}];
                    end
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // PE accumulator control
    // -------------------------------------------------------------------------
    assign pe_acc_clear_o = (state_q == PE_CLEAR_ACC);
    assign pe_acc_en_o    = (state_q == PE_COMPUTE);

    // -------------------------------------------------------------------------
    // Writeback: accumulator values -> VRF result vector
    // -------------------------------------------------------------------------
    assign wb_valid_o     = (state_q == PE_WRITEBACK);

    genvar idx;
    generate
        for (idx = 0; idx < VLEN; idx = idx + 1) begin : gen_wb
            assign wb_vec_result_o[idx] = pe_acc_i[idx][ELEM_WIDTH-1:0];
        end
    endgenerate

endmodule
