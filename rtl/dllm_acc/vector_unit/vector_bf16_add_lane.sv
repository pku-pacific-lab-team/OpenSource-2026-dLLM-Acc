//-----------------------------------------------------------------------------
// File: vector_bf16_add_lane.sv
// Description: VLEN-wide BF16 element-wise adder lane for vector_unit.
//              Instantiates VLEN bf16_adder cells (3-stage pipelined).
//              Binary operation: vec_result = vec_op0 + vec_op1 (per-element BF16 add).
//              No scalar result output.
//-----------------------------------------------------------------------------

module vector_bf16_add_lane #(
    parameter integer VLEN       = 16,
    parameter integer ELEM_WIDTH = 16
) (
    input  logic                            clk_i,
    input  logic                            rst_ni,
    input  logic                            valid_i,
    input  logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_op0_i,
    input  logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_op1_i,
    output logic                            ready_o,
    output logic                            done_o,
    output logic [VLEN-1:0][ELEM_WIDTH-1:0] vec_result_o,
    output logic                            vec_write_o
);

    localparam integer LATENCY = 3;

    logic                            busy_q;
    logic [     1:0]                 count_q;
    logic                            en_pulse;
    logic                            done_pulse;
    logic [VLEN-1:0][ELEM_WIDTH-1:0] adder_sum;

    assign ready_o  = !busy_q;
    assign en_pulse = valid_i && !busy_q;

    // -------------------------------------------------------------------------
    // Lane control
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            busy_q  <= 1'b0;
            count_q <= '0;
        end else if (en_pulse) begin
            busy_q  <= 1'b1;
            count_q <= 2'd1;
        end else if (busy_q) begin
            if (count_q == 2'(LATENCY - 1)) begin
                busy_q  <= 1'b0;
                count_q <= '0;
            end else begin
                count_q <= count_q + 2'd1;
            end
        end
    end

    assign done_pulse = busy_q && (count_q == 2'(LATENCY - 1));

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            done_o      <= 1'b0;
            vec_write_o <= 1'b0;
        end else begin
            done_o      <= done_pulse;
            vec_write_o <= done_pulse;
        end
    end

    // -------------------------------------------------------------------------
    // VLEN parallel bf16_adder instances
    // -------------------------------------------------------------------------

    genvar i;
    generate
        for (i = 0; i < VLEN; i = i + 1) begin : gen_adder
            bf16_adder i_bf16_adder (
                .clk_i(clk_i),
                .en_i (en_pulse),
                .a_i  (vec_op0_i[i]),
                .b_i  (vec_op1_i[i]),
                .sum_o(adder_sum[i])
            );
        end
    endgenerate

    assign vec_result_o = adder_sum;

endmodule
