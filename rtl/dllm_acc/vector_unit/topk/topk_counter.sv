`timescale 1ns / 1ps

module topk_counter #(
    parameter int CNT_WIDTH = 8
) (
    input  logic               clk,
    input  logic               en_i,
    input  logic               rst_n,
    input  logic               hit,
    input  logic               min_cnt,
    input  logic [        3:0] A,
    output logic [CNT_WIDTH:0] CNT,
    output logic [        3:0] AS,
    input  logic               fsm_en,
    input  logic [CNT_WIDTH:0] CNT_fsm,
    input  logic [        3:0] A_fsm
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) CNT <= '0;
        else if (fsm_en) CNT <= CNT_fsm;
        else if (en_i) begin
            if (hit) CNT <= CNT + 1;
            else if (min_cnt) CNT <= 0;
        end

    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) AS <= 0;
        else if (fsm_en) AS <= A_fsm;
        else if (en_i & min_cnt) AS <= A;

    end
endmodule



