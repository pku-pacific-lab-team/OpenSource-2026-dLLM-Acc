`timescale 1ns / 1ps



module topk_SEL_6_5 #(
    parameter int WIDTH = 7
)(
    input   logic [WIDTH:0]     data_i [5:0],
    input   logic     [4:0]     sel_i,
    output  logic [WIDTH:0]     data_o [4:0]
);
    logic [4:0] sel;
    always_comb begin
        for(int i=0;i<5;i++)begin
            sel[i] = 1'b0;
            for (int j = 0; j <= i; j++) begin
                sel[i] = sel[i] | sel_i[j];
            end
        end
    end
    
    genvar b;

    generate
        for (b = 0; b <= WIDTH; b++) begin : g_topk_sel_6_5
            logic [5:0] data_i_bit;
            logic [4:0] data_o_bit;

            assign data_i_bit = {
                data_i[5][b],
                data_i[4][b],
                data_i[3][b],
                data_i[2][b],
                data_i[1][b],
                data_i[0][b]
            };

            assign {
                data_o[4][b],
                data_o[3][b],
                data_o[2][b],
                data_o[1][b],
                data_o[0][b]
            } = data_o_bit;

            topk_sel_6_5 u_topk_sel_6_5 (
                .sel_i  (sel),
                .data_i (data_i_bit),
                .data_o (data_o_bit)
            );
        end
    endgenerate
endmodule


module topk_sel_6_5 (
    input   logic   [4:0]       sel_i,
    input   logic   [5:0]       data_i,
    output  logic   [4:0]       data_o
);
    genvar i;
    generate
        for (i = 0; i < 5; i++) begin
            assign data_o[i] = sel_i[i] ? data_i[i+1] : data_i[i];
        end
    endgenerate
endmodule
