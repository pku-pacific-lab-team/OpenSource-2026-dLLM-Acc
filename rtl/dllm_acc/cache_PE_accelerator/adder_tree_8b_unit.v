`timescale 1ns / 1ps

module adder_tree_8b_unit(
    input                               sign_i                     ,  //1'b0-unsigned, 1'b1-signed
    input                [16*8-1: 0]    data_i                     ,
    output               [  11: 0]      data_o
);

    genvar i;

    wire                 [   8: 0]      data_ext[0:15]              ;
    wire                 [   9: 0]      sum_lv1[0:7]                ;
    wire                 [  10: 0]      sum_lv2[0:3]                ;
    wire                 [  11: 0]      sum_lv3[0:1]                ;

    generate
        for (i = 0; i < 16; i = i + 1) begin : GEN_DATA_EXT
            assign data_ext[i] = {sign_i & data_i[8*i+7], data_i[8*i+7:8*i]};
        end
    endgenerate

    generate
        for (i = 0; i < 8; i = i + 1) begin : GEN_SUM_LV1
            assign sum_lv1[i] = $signed({data_ext[2*i][8],data_ext[2*i]}) + $signed({data_ext[2*i+1][8],data_ext[2*i+1]});
        end
    endgenerate

    generate
        for (i = 0; i < 4; i = i + 1) begin : GEN_SUM_LV2
            assign sum_lv2[i] = $signed({sum_lv1[2*i][9],sum_lv1[2*i]}) + $signed({sum_lv1[2*i+1][9],sum_lv1[2*i+1]});
        end
    endgenerate

    generate
        for (i = 0; i < 2; i = i + 1) begin : GEN_SUM_LV3
            assign sum_lv3[i] = $signed({sum_lv2[2*i][10],sum_lv2[2*i]}) + $signed({sum_lv2[2*i+1][10],sum_lv2[2*i+1]});
        end
    endgenerate

    assign data_o = $signed({sum_lv3[0][11],sum_lv3[0]}) + $signed({sum_lv3[1][11],sum_lv3[1]});

endmodule