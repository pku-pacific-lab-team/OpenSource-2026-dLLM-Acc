//-----------------------------------------------------------------------------
// File: my_counter.sv
// Date Created: 2025-03-12
// Description: Configurable counter with enable signal that accumulates on positive clock edges.
//-----------------------------------------------------------------------------

module my_counter #(
    parameter integer WIDTH = 32
) (
    input  logic             clk_i,
    input  logic             rst_ni,
    input  logic             enable_i,
    input  logic             clear_i,
    input  logic [WIDTH-1:0] reset_value_i,
    input  logic [WIDTH-1:0] increment_i,
    output logic [WIDTH-1:0] count_o
);

    logic [WIDTH-1:0] count_d, count_q;

    always_comb begin
        if (clear_i) begin
            count_d = reset_value_i;
        end else if (enable_i) begin
            count_d = count_q + increment_i;
        end else begin
            count_d = count_q;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            count_q <= reset_value_i;
        end else begin
            count_q <= count_d;
        end
    end

    assign count_o = count_q;

endmodule

