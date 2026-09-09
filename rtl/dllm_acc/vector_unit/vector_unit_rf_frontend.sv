//-----------------------------------------------------------------------------
// File: vector_unit_rf_frontend.sv
// Description: RF and instruction-buffer staging frontend for vector_unit.
//              Supports dual vector operands (src0 + src1) for binary ops
//              (BF16 add/mul). Also provides VRF read port for PE array.
//-----------------------------------------------------------------------------

module vector_unit_rf_frontend #(
    parameter integer INSTR_WIDTH          = 32,
    parameter integer INSTR_DEPTH          = 32,
    parameter integer SCALAR_WIDTH         = 32,
    parameter integer SCALAR_RF_DEPTH      = 32,
    parameter integer VLEN                 = 64,
    parameter integer ELEM_WIDTH           = 16,
    parameter integer VECTOR_RF_DEPTH      = 32,
    parameter integer VECTOR_RF_BANK_WIDTH = 64,
    parameter integer NUM_GROUPS           = 4
) (
    input logic                           clk_i,
    input logic                           rst_ni,
    input logic                           exec_active_i,
    input logic                           active_bank_i,
    input logic                           instr_req_i,
    input logic                           instr_valid_i,
    input logic [$clog2(INSTR_DEPTH)-1:0] instr_pc_i,

    input logic vrf_read_vec_en_i,
    input logic vrf_read_vec1_en_i,
    input logic vrf_writeback_en_i,
    input logic capture_active_vec_i,
    input logic capture_active_vec1_i,
    input logic capture_shadow_vec_i,
    input logic capture_shadow_vec1_i,
    input logic scalar_rf_read_active_en_i,
    input logic scalar_rf_read_shadow_en_i,
    input logic capture_active_scalar_i,
    input logic capture_shadow_scalar_i,

    input logic [$clog2(VECTOR_RF_DEPTH)-1:0] active_vec_idx_i,
    input logic [$clog2(VECTOR_RF_DEPTH)-1:0] active_vec1_idx_i,
    input logic [$clog2(VECTOR_RF_DEPTH)-1:0] shadow_vec_idx_i,
    input logic [$clog2(VECTOR_RF_DEPTH)-1:0] shadow_vec1_idx_i,
    input logic [$clog2(SCALAR_RF_DEPTH)-1:0] active_scalar_idx_i,
    input logic [$clog2(SCALAR_RF_DEPTH)-1:0] shadow_scalar_idx_i,

    // PE array VRF read port (used during PE array K-loop)
    input logic                               pe_array_vrf_read_en_i,
    input logic [$clog2(VECTOR_RF_DEPTH)-1:0] pe_array_vrf_read_idx_i,

    input logic                                                                      exec_vec_write_i,
    input logic                      [             NUM_GROUPS-1:0]                   exec_scalar_write_g_i,
    input logic                      [                   VLEN-1:0][  ELEM_WIDTH-1:0] exec_vec_result_i,
    input logic                      [             NUM_GROUPS-1:0][SCALAR_WIDTH-1:0] exec_scalar_result_g_i,
    input logic                      [$clog2(VECTOR_RF_DEPTH)-1:0]                   issued_dst_idx_i,
    input logic                      [$clog2(SCALAR_RF_DEPTH)-1:0]                   issued_scalar_idx_i,
    input vector_unit_pkg::op_type_t                                                 issued_op_i,
    input logic                                                                      issued_scalar_half_sel_i,

    input logic                                                      axi_read_instr_buf_en_i,
    input logic [                           $clog2(INSTR_DEPTH)-1:0] axi_read_instr_buf_idx_i,
    input logic                                                      axi_read_scalar_rf_en_i,
    input logic [                       $clog2(SCALAR_RF_DEPTH)-1:0] axi_read_scalar_rf_idx_i,
    input logic [                            $clog2(NUM_GROUPS)-1:0] axi_read_scalar_group_idx_i,
    input logic                                                      axi_read_vector_rf_en_i,
    input logic [                       $clog2(VECTOR_RF_DEPTH)-1:0] axi_read_vector_rf_idx_i,
    input logic [$clog2((VLEN*ELEM_WIDTH)/VECTOR_RF_BANK_WIDTH)-1:0] axi_read_vector_bank_idx_i,

    input logic                                                      axi_write_instr_buf_en_i,
    input logic [                           $clog2(INSTR_DEPTH)-1:0] axi_write_instr_buf_idx_i,
    input logic [                                   INSTR_WIDTH-1:0] axi_write_instr_buf_data_i,
    input logic [                                              31:0] axi_write_instr_buf_be_i,
    input logic                                                      axi_write_scalar_rf_en_i,
    input logic [                       $clog2(SCALAR_RF_DEPTH)-1:0] axi_write_scalar_rf_idx_i,
    input logic [                            $clog2(NUM_GROUPS)-1:0] axi_write_scalar_group_idx_i,
    input logic [                                  SCALAR_WIDTH-1:0] axi_write_scalar_rf_data_i,
    input logic [                                              31:0] axi_write_scalar_rf_be_i,
    input logic                                                      axi_write_vector_rf_en_i,
    input logic [                       $clog2(VECTOR_RF_DEPTH)-1:0] axi_write_vector_rf_idx_i,
    input logic [$clog2((VLEN*ELEM_WIDTH)/VECTOR_RF_BANK_WIDTH)-1:0] axi_write_vector_rf_bank_idx_i,
    input logic [                          VECTOR_RF_BANK_WIDTH-1:0] axi_write_vector_rf_data_i,

    output logic                           instr_buf_req_o,
    output logic                           instr_buf_we_o,
    output logic [$clog2(INSTR_DEPTH)-1:0] instr_buf_addr_o,
    output logic [        INSTR_WIDTH-1:0] instr_buf_wdata_o,
    output logic [                   31:0] instr_buf_be_o,
    input  logic [        INSTR_WIDTH-1:0] instr_buf_rdata_i,

    output logic [NUM_GROUPS-1:0]                              scalar_rf_req_o,
    output logic [NUM_GROUPS-1:0]                              scalar_rf_we_o,
    output logic [NUM_GROUPS-1:0][$clog2(SCALAR_RF_DEPTH)-1:0] scalar_rf_addr_o,
    output logic [NUM_GROUPS-1:0][           SCALAR_WIDTH-1:0] scalar_rf_wdata_o,
    output logic [NUM_GROUPS-1:0][                       31:0] scalar_rf_be_o,
    input  logic [NUM_GROUPS-1:0][           SCALAR_WIDTH-1:0] scalar_rf_rdata_i,

    output logic [(VLEN*ELEM_WIDTH)/VECTOR_RF_BANK_WIDTH-1:0]                              vector_rf_req_o,
    output logic [(VLEN*ELEM_WIDTH)/VECTOR_RF_BANK_WIDTH-1:0]                              vector_rf_we_o,
    output logic [(VLEN*ELEM_WIDTH)/VECTOR_RF_BANK_WIDTH-1:0][$clog2(VECTOR_RF_DEPTH)-1:0] vector_rf_addr_o,
    output logic [(VLEN*ELEM_WIDTH)/VECTOR_RF_BANK_WIDTH-1:0][   VECTOR_RF_BANK_WIDTH-1:0] vector_rf_wdata_o,
    input  logic [(VLEN*ELEM_WIDTH)/VECTOR_RF_BANK_WIDTH-1:0][   VECTOR_RF_BANK_WIDTH-1:0] vector_rf_rdata_i,

    output logic [           1:0][ INSTR_WIDTH-1:0] instr_bank_o,
    output logic [      VLEN-1:0][  ELEM_WIDTH-1:0] curr_vec_op_o,
    output logic [      VLEN-1:0][  ELEM_WIDTH-1:0] curr_vec_op1_o,
    output logic [NUM_GROUPS-1:0][SCALAR_WIDTH-1:0] curr_scalar_op_o,
    // Raw unpacked VRF read data (1-cycle latency from request)
    output logic [      VLEN-1:0][  ELEM_WIDTH-1:0] vrf_rdata_unpacked_o
);

    import vector_unit_pkg::*;

    localparam integer NUM_VECTOR_RF_BANKS = (VLEN * ELEM_WIDTH) / VECTOR_RF_BANK_WIDTH;
    localparam integer ELEMS_PER_BANK = VECTOR_RF_BANK_WIDTH / ELEM_WIDTH;
    localparam integer SCALAR_RF_GROUP_IDX_WIDTH = (NUM_GROUPS > 1) ? $clog2(NUM_GROUPS) : 1;

    typedef logic [VLEN-1:0][ELEM_WIDTH-1:0] vector_data_t;
    typedef logic [NUM_VECTOR_RF_BANKS-1:0][VECTOR_RF_BANK_WIDTH-1:0] vector_bank_data_t;

    logic fetch_target_bank_d, fetch_target_bank_q;
    logic [1:0][INSTR_WIDTH-1:0] instr_bank_d, instr_bank_q;
    logic [1:0][VLEN-1:0][ELEM_WIDTH-1:0] vec_op_bank_d, vec_op_bank_q;
    logic [1:0][VLEN-1:0][ELEM_WIDTH-1:0] vec_op1_bank_d, vec_op1_bank_q;
    logic [1:0][NUM_GROUPS-1:0][SCALAR_WIDTH-1:0] scalar_op_bank_d, scalar_op_bank_q;
    integer vrf_bank_iter;
    integer srf_group_iter;

    function automatic vector_data_t unpack_vector_rf_banks(input vector_bank_data_t bank_data_i);
        integer bank_idx;
        integer elem_idx;
        begin
            unpack_vector_rf_banks = '0;
            for (bank_idx = 0; bank_idx < NUM_VECTOR_RF_BANKS; bank_idx = bank_idx + 1) begin
                for (elem_idx = 0; elem_idx < ELEMS_PER_BANK; elem_idx = elem_idx + 1) begin
                    unpack_vector_rf_banks[bank_idx*ELEMS_PER_BANK+elem_idx] = bank_data_i[bank_idx][elem_idx*ELEM_WIDTH+:ELEM_WIDTH];
                end
            end
        end
    endfunction

    function automatic vector_bank_data_t pack_vector_rf_banks(input vector_data_t vec_i);
        integer bank_idx;
        integer elem_idx;
        begin
            pack_vector_rf_banks = '0;
            for (bank_idx = 0; bank_idx < NUM_VECTOR_RF_BANKS; bank_idx = bank_idx + 1) begin
                for (elem_idx = 0; elem_idx < ELEMS_PER_BANK; elem_idx = elem_idx + 1) begin
                    pack_vector_rf_banks[bank_idx][elem_idx*ELEM_WIDTH+:ELEM_WIDTH] = vec_i[bank_idx*ELEMS_PER_BANK+elem_idx];
                end
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // Instruction buffer port logic
    // -------------------------------------------------------------------------

    always_comb begin
        instr_buf_req_o   = instr_req_i;
        instr_buf_we_o    = 1'b0;
        instr_buf_addr_o  = instr_pc_i;
        instr_buf_wdata_o = '0;
        instr_buf_be_o    = '0;

        if (axi_read_instr_buf_en_i) begin
            instr_buf_req_o  = 1'b1;
            instr_buf_addr_o = axi_read_instr_buf_idx_i;
        end

        if (axi_write_instr_buf_en_i) begin
            instr_buf_req_o   = 1'b1;
            instr_buf_we_o    = 1'b1;
            instr_buf_addr_o  = axi_write_instr_buf_idx_i;
            instr_buf_wdata_o = axi_write_instr_buf_data_i;
            instr_buf_be_o    = axi_write_instr_buf_be_i;
        end
    end

    // -------------------------------------------------------------------------
    // Scalar RF port logic (per-group)
    // -------------------------------------------------------------------------

    always_comb begin
        scalar_rf_req_o   = '0;
        scalar_rf_we_o    = '0;
        scalar_rf_addr_o  = '0;
        scalar_rf_wdata_o = '0;
        scalar_rf_be_o    = '0;

        // Compute path: broadcast same address to all groups
        if (|exec_scalar_write_g_i) begin
            for (srf_group_iter = 0; srf_group_iter < NUM_GROUPS; srf_group_iter = srf_group_iter + 1) begin
                if (exec_scalar_write_g_i[srf_group_iter]) begin
                    scalar_rf_req_o[srf_group_iter]  = 1'b1;
                    scalar_rf_we_o[srf_group_iter]   = 1'b1;
                    scalar_rf_addr_o[srf_group_iter] = issued_scalar_idx_i;
                    if (issued_op_i == OP_TYPE_ALIGN) begin
                        scalar_rf_wdata_o[srf_group_iter] = issued_scalar_half_sel_i
                            ? {exec_scalar_result_g_i[srf_group_iter][15:0], 16'h0000}
                            : {16'h0000, exec_scalar_result_g_i[srf_group_iter][15:0]};
                        scalar_rf_be_o[srf_group_iter] = issued_scalar_half_sel_i ? 32'hFFFF_0000 : 32'h0000_FFFF;
                    end else if (issued_op_i == OP_TYPE_QUANT) begin
                        scalar_rf_wdata_o[srf_group_iter] = {16'h0000, exec_scalar_result_g_i[srf_group_iter][15:0]};
                        scalar_rf_be_o[srf_group_iter]    = 32'h0000_FFFF;
                    end else begin
                        scalar_rf_wdata_o[srf_group_iter] = exec_scalar_result_g_i[srf_group_iter];
                        scalar_rf_be_o[srf_group_iter]    = '1;
                    end
                end
            end
        end else if (scalar_rf_read_active_en_i) begin
            for (srf_group_iter = 0; srf_group_iter < NUM_GROUPS; srf_group_iter = srf_group_iter + 1) begin
                scalar_rf_req_o[srf_group_iter]  = 1'b1;
                scalar_rf_addr_o[srf_group_iter] = active_scalar_idx_i;
            end
        end else if (scalar_rf_read_shadow_en_i) begin
            for (srf_group_iter = 0; srf_group_iter < NUM_GROUPS; srf_group_iter = srf_group_iter + 1) begin
                scalar_rf_req_o[srf_group_iter]  = 1'b1;
                scalar_rf_addr_o[srf_group_iter] = shadow_scalar_idx_i;
            end
        end

        // AXI path: target a specific group
        if (axi_read_scalar_rf_en_i) begin
            scalar_rf_req_o[axi_read_scalar_group_idx_i]  = 1'b1;
            scalar_rf_addr_o[axi_read_scalar_group_idx_i] = axi_read_scalar_rf_idx_i;
        end

        if (axi_write_scalar_rf_en_i) begin
            scalar_rf_req_o[axi_write_scalar_group_idx_i]   = 1'b1;
            scalar_rf_we_o[axi_write_scalar_group_idx_i]    = 1'b1;
            scalar_rf_addr_o[axi_write_scalar_group_idx_i]  = axi_write_scalar_rf_idx_i;
            scalar_rf_wdata_o[axi_write_scalar_group_idx_i] = axi_write_scalar_rf_data_i;
            scalar_rf_be_o[axi_write_scalar_group_idx_i]    = axi_write_scalar_rf_be_i;
        end
    end

    // -------------------------------------------------------------------------
    // Vector RF port logic
    // -------------------------------------------------------------------------

    always_comb begin
        vector_rf_req_o   = '0;
        vector_rf_we_o    = '0;
        vector_rf_addr_o  = '0;
        vector_rf_wdata_o = '0;

        if (pe_array_vrf_read_en_i) begin
            // PE array K-loop VRF read takes priority during execution
            vector_rf_req_o = '1;
            for (vrf_bank_iter = 0; vrf_bank_iter < NUM_VECTOR_RF_BANKS; vrf_bank_iter = vrf_bank_iter + 1) begin
                vector_rf_addr_o[vrf_bank_iter] = pe_array_vrf_read_idx_i;
            end
        end else if (vrf_read_vec_en_i) begin
            vector_rf_req_o = '1;
            for (vrf_bank_iter = 0; vrf_bank_iter < NUM_VECTOR_RF_BANKS; vrf_bank_iter = vrf_bank_iter + 1) begin
                vector_rf_addr_o[vrf_bank_iter] = exec_active_i ? shadow_vec_idx_i : active_vec_idx_i;
            end
        end else if (vrf_read_vec1_en_i) begin
            // src1 read: address from vec1_idx (repurposed scalar_idx field)
            vector_rf_req_o = '1;
            for (vrf_bank_iter = 0; vrf_bank_iter < NUM_VECTOR_RF_BANKS; vrf_bank_iter = vrf_bank_iter + 1) begin
                vector_rf_addr_o[vrf_bank_iter] = exec_active_i ? shadow_vec1_idx_i : active_vec1_idx_i;
            end
        end

        if (vrf_writeback_en_i) begin
            for (vrf_bank_iter = 0; vrf_bank_iter < NUM_VECTOR_RF_BANKS; vrf_bank_iter = vrf_bank_iter + 1) begin
                vector_rf_addr_o[vrf_bank_iter] = issued_dst_idx_i;
            end

            if (exec_vec_write_i) begin
                vector_rf_req_o   = '1;
                vector_rf_we_o    = '1;
                vector_rf_wdata_o = pack_vector_rf_banks(exec_vec_result_i);
            end
        end

        if (axi_read_vector_rf_en_i) begin
            vector_rf_req_o[axi_read_vector_bank_idx_i]  = 1'b1;
            vector_rf_addr_o[axi_read_vector_bank_idx_i] = axi_read_vector_rf_idx_i;
        end

        if (axi_write_vector_rf_en_i) begin
            vector_rf_req_o[axi_write_vector_rf_bank_idx_i]   = 1'b1;
            vector_rf_we_o[axi_write_vector_rf_bank_idx_i]    = 1'b1;
            vector_rf_addr_o[axi_write_vector_rf_bank_idx_i]  = axi_write_vector_rf_idx_i;
            vector_rf_wdata_o[axi_write_vector_rf_bank_idx_i] = axi_write_vector_rf_data_i;
        end
    end

    // -------------------------------------------------------------------------
    // Operand bank registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            fetch_target_bank_q <= 1'b0;
        end else begin
            fetch_target_bank_q <= fetch_target_bank_d;
        end
    end

    always_ff @(posedge clk_i) begin
        instr_bank_q     <= instr_bank_d;
        vec_op_bank_q    <= vec_op_bank_d;
        vec_op1_bank_q   <= vec_op1_bank_d;
        scalar_op_bank_q <= scalar_op_bank_d;
    end

    always_comb begin
        instr_bank_d        = instr_bank_q;
        fetch_target_bank_d = fetch_target_bank_q;
        vec_op_bank_d       = vec_op_bank_q;
        vec_op1_bank_d      = vec_op1_bank_q;
        scalar_op_bank_d    = scalar_op_bank_q;

        if (instr_req_i) begin
            fetch_target_bank_d = exec_active_i ? ~active_bank_i : active_bank_i;
        end

        if (instr_valid_i) begin
            instr_bank_d[fetch_target_bank_q] = instr_buf_rdata_i;
        end

        if (capture_active_vec_i) begin
            vec_op_bank_d[active_bank_i] = unpack_vector_rf_banks(vector_rf_rdata_i);
        end

        if (capture_active_vec1_i) begin
            vec_op1_bank_d[active_bank_i] = unpack_vector_rf_banks(vector_rf_rdata_i);
        end

        if (capture_shadow_vec_i) begin
            vec_op_bank_d[~active_bank_i] = unpack_vector_rf_banks(vector_rf_rdata_i);
        end

        if (capture_shadow_vec1_i) begin
            vec_op1_bank_d[~active_bank_i] = unpack_vector_rf_banks(vector_rf_rdata_i);
        end

        if (capture_active_scalar_i) begin
            scalar_op_bank_d[active_bank_i] = scalar_rf_rdata_i;
        end

        if (capture_shadow_scalar_i) begin
            scalar_op_bank_d[~active_bank_i] = scalar_rf_rdata_i;
        end
    end

    // -------------------------------------------------------------------------
    // Output assignments
    // -------------------------------------------------------------------------

    assign instr_bank_o         = instr_bank_q;
    assign curr_vec_op_o        = capture_active_vec_i ? vec_op_bank_d[active_bank_i] : vec_op_bank_q[active_bank_i];
    assign curr_vec_op1_o       = capture_active_vec1_i ? vec_op1_bank_d[active_bank_i] : vec_op1_bank_q[active_bank_i];
    assign curr_scalar_op_o     = capture_active_scalar_i ? scalar_op_bank_d[active_bank_i] : scalar_op_bank_q[active_bank_i];
    // Raw VRF read data -- available 1 cycle after any VRF read request.
    // Used by PE array controller which reads VRF directly during K-loop.
    assign vrf_rdata_unpacked_o = unpack_vector_rf_banks(vector_rf_rdata_i);

endmodule
