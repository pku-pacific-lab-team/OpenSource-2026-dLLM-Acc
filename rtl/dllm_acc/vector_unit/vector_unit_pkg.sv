//-----------------------------------------------------------------------------
// File: vector_unit_pkg.sv
// Description: Shared enum types for vector_unit control and status paths.
//-----------------------------------------------------------------------------

`timescale 1ps / 1ps

`include "axi_typedef.svh"

package vector_unit_pkg;

    // Group architecture constants (VLEN=64 = NUM_GROUPS x LANES_PER_GROUP)
    localparam integer NUM_GROUPS = 4;
    localparam integer LANES_PER_GROUP = 16;

    typedef enum logic [2:0] {
        VU_IDLE             = 3'd0,
        VU_FETCH_ACTIVE     = 3'd1,
        VU_FILL_ACTIVE_VEC  = 3'd2,
        VU_FILL_ACTIVE_VEC2 = 3'd3,  // src1 fill for binary ops (BF16 add/mul)
        VU_ISSUE_ACTIVE     = 3'd4,
        VU_EXEC_ACTIVE      = 3'd5,
        VU_WRITEBACK_ACTIVE = 3'd6
    } vu_state_t;

    typedef enum logic [1:0] {
        PREFILL_IDLE  = 2'd0,
        PREFILL_VEC   = 2'd1,
        PREFILL_VEC2  = 2'd2,  // shadow src1 fill for binary ops
        PREFILL_READY = 2'd3
    } prefill_state_t;

    typedef enum logic [2:0] {
        OP_TYPE_QUANT         = 3'd0,
        OP_TYPE_ALIGN         = 3'd1,
        OP_TYPE_TOKEN_PROMOTE = 3'd2,
        OP_TYPE_DMA           = 3'd3,
        OP_TYPE_BF16_ADD      = 3'd4,
        OP_TYPE_BF16_MUL      = 3'd5,
        OP_TYPE_PE_ARRAY      = 3'd6
    } op_type_t;

    typedef enum logic [3:0] {
        AXI_RD_NONE,
        AXI_RD_CTRL_STATUS,
        AXI_RD_LOOP_MODE,
        AXI_RD_INSTR_COUNT,
        AXI_RD_DEBUG,
        AXI_RD_INSTR_BUF,
        AXI_RD_SCALAR_RF,
        AXI_RD_VECTOR_RF,
        AXI_RD_TOKEN_PROMOTE_CTRL_STATUS,
        AXI_RD_TOKEN_PROMOTE_SHIFT_CFG,
        AXI_RD_TOKEN_PROMOTE_TILE_CFG,
        AXI_RD_TOKEN_PROMOTE_RESULT,
        AXI_RD_TOKEN_PROMOTE_DEBUG,
        AXI_RD_DMA_REGS,
        AXI_RD_INVALID
    } axi_read_src_t;

    // -------------------------------------------------------------------------
    // DMA AXI master types (64-bit addr, 64-bit data, 4-bit ID, 1-bit user)
    // Generated via AXI_TYPEDEF_ALL macro from axi_typedef.svh.
    // Types: vu_dma_axi_{aw,w,b,ar,r}_chan_t, vu_dma_axi_req_t, vu_dma_axi_resp_t
    // -------------------------------------------------------------------------
    `AXI_TYPEDEF_ALL(vu_dma_axi, logic [63:0], logic [3:0], logic [63:0], logic [7:0], logic [63:0])

    // iDMA request/response types (matching dma_wrapper.sv:84-103)
    typedef struct packed {
        logic [63:0] src_addr;
        logic [63:0] dst_addr;
        logic [63:0] length;
        logic [63:0] user;
        struct packed {
            idma_pkg::protocol_e        src_protocol;
            idma_pkg::protocol_e        dst_protocol;
            idma_pkg::axi_options_t     src;
            idma_pkg::axi_options_t     dst;
            idma_pkg::backend_options_t beo;
            logic                       last;
        } opt;
    } vu_dma_idma_req_t;

    typedef struct packed {
        logic last;
        logic error;
        struct packed {idma_pkg::err_type_e err_type;} pld;
    } vu_dma_idma_rsp_t;

endpackage
