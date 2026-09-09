//-----------------------------------------------------------------------------
// File: sfu_acc_lane.sv
// Date Created: 2026-04-04
// Description: SFU BF16 accumulation lane. Wraps VLEN bf16_adder cells with a
//              fixed-latency FSM that provides the valid/ready/done contract.
//              Used for cross-core PSUM accumulation in the SFU.
//-----------------------------------------------------------------------------

module sfu_acc_lane #(
    parameter integer VLEN       = 16,
    parameter integer ELEM_WIDTH = 16
) (
    input logic clk_i,
    input logic rst_ni,

    // Lane control
    input  logic valid_i,
    output logic ready_o,
    output logic done_o,
    input  logic acc_clear_i, // zeroes accumulator feedback (op_b path)

    // Operands
    input logic [VLEN-1:0][ELEM_WIDTH-1:0] op_a_i,  // dequant result
    input logic [VLEN-1:0][ELEM_WIDTH-1:0] op_b_i,  // accumulator value

    // Result
    output logic [VLEN-1:0][ELEM_WIDTH-1:0] acc_result_o
);

    typedef enum logic [1:0] {
        ACC_IDLE,
        ACC_WAIT_STAGE1,
        ACC_WAIT_STAGE2,
        ACC_DONE
    } acc_state_t;

    acc_state_t state_d, state_q;
    logic                            accept_req;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] result_int;

    assign accept_req = valid_i && ready_o;

    // -------------------------------------------------------------------------
    // BF16 adder array (VLEN instances)
    // -------------------------------------------------------------------------

    logic [VLEN-1:0][ELEM_WIDTH-1:0] op_b_gated;

    always_comb begin
        for (int j = 0; j < VLEN; j++) begin
            op_b_gated[j] = acc_clear_i ? '0 : op_b_i[j];
        end
    end

    generate
        genvar i;
        for (i = 0; i < VLEN; i = i + 1) begin : gen_bf16_acc
            bf16_adder i_bf16_adder (
                .clk_i(clk_i),
                .en_i (accept_req),
                .a_i  (op_a_i[i]),
                .b_i  (op_b_gated[i]),
                .sum_o(result_int[i])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // FSM control logic
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= ACC_IDLE;
        end else begin
            state_q <= state_d;
        end
    end

    always_comb begin
        state_d = state_q;

        case (state_q)
            ACC_IDLE: begin
                if (accept_req) begin
                    state_d = ACC_WAIT_STAGE1;
                end
            end
            ACC_WAIT_STAGE1: begin
                state_d = ACC_WAIT_STAGE2;
            end
            ACC_WAIT_STAGE2: begin
                state_d = ACC_DONE;
            end
            ACC_DONE: begin
                state_d = ACC_IDLE;
            end
            default: begin
                state_d = ACC_IDLE;
            end
        endcase

        ready_o      = (state_q == ACC_IDLE);
        done_o       = (state_q == ACC_DONE);
        acc_result_o = result_int;
    end

endmodule
