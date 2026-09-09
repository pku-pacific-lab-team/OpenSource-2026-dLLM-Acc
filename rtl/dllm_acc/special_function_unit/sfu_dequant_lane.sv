//-----------------------------------------------------------------------------
// File: sfu_dequant_lane.sv
// Date Created: 2026-04-04
// Description: SFU dequantization lane. Wraps VLEN bf16_dequant cells with a
//              fixed-latency FSM that provides the valid/ready/done contract.
//-----------------------------------------------------------------------------

module sfu_dequant_lane #(
    parameter integer VLEN       = 16,
    parameter integer ELEM_WIDTH = 16
) (
    input logic clk_i,
    input logic rst_ni,

    // Lane control
    input  logic valid_i,
    output logic ready_o,
    output logic done_o,

    // Operands
    input logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_op_i,
    input logic [VLEN-1:0][ELEM_WIDTH-1:0] scale_vec_i,
    input logic                            dequant_type_i,

    // Result
    output logic [VLEN-1:0][ELEM_WIDTH-1:0] dequant_result_o
);

    typedef enum logic [1:0] {
        DEQUANT_IDLE,
        DEQUANT_WAIT_STAGE1,
        DEQUANT_WAIT_STAGE2,
        DEQUANT_DONE
    } dequant_state_t;

    dequant_state_t state_d, state_q;
    logic                            accept_req;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] result_int;

    assign accept_req = valid_i && ready_o;

    // -------------------------------------------------------------------------
    // Dequant cell array (VLEN instances, full-rate)
    // -------------------------------------------------------------------------

    generate
        genvar i;
        for (i = 0; i < VLEN; i = i + 1) begin : gen_bf16_dequant
            bf16_dequant i_bf16_dequant (
                .clk_i         (clk_i),
                .en_i          (accept_req),
                .dequant_type_i(dequant_type_i),
                .quant_i       (vec_op_i[i]),
                .scale_i       (scale_vec_i[i]),
                .dequant_o     (result_int[i])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // FSM control logic
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= DEQUANT_IDLE;
        end else begin
            state_q <= state_d;
        end
    end

    always_comb begin
        state_d = state_q;

        case (state_q)
            DEQUANT_IDLE: begin
                if (accept_req) begin
                    state_d = DEQUANT_WAIT_STAGE1;
                end
            end
            DEQUANT_WAIT_STAGE1: begin
                state_d = DEQUANT_WAIT_STAGE2;
            end
            DEQUANT_WAIT_STAGE2: begin
                state_d = DEQUANT_DONE;
            end
            DEQUANT_DONE: begin
                state_d = DEQUANT_IDLE;
            end
            default: begin
                state_d = DEQUANT_IDLE;
            end
        endcase

        ready_o          = (state_q == DEQUANT_IDLE);
        done_o           = (state_q == DEQUANT_DONE);
        dequant_result_o = result_int;
    end

endmodule
