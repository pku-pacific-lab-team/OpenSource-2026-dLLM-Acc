`timescale 1ns / 1ps

module cache_PE_column(
    input  wire          [16-1: 0]      gclk                       ,
    input  wire                         precision_i                ,
    input  wire                         W_update_i                 ,
    input  wire          [16*8-1: 0]    W_i                        ,

    input  wire          [16*4-1: 0]    IA0_i                      ,
    input  wire          [16-1: 0]      Cache0_update_i            ,
    input  wire          [16-1: 0]      Cache0_hit_i               ,
    input  wire          [16*2-1: 0]    Cache0_code_i              ,

    input  wire          [16*4-1: 0]    IA1_i                      ,
    input  wire          [16-1: 0]      Cache1_update_i            ,
    input  wire          [16-1: 0]      Cache1_hit_i               ,
    input  wire          [16*2-1: 0]    Cache1_code_i              ,
    
    output wire          [24-1: 0]      Result_o                    
);
    wire                 [16*8-1: 0]    OA0                         ;
    wire                 [16*8-1: 0]    OA1                         ;
    wire                 [16*12-1: 0]   OA                          ;
    wire                 [16*8-1: 0]    AT_data0_8b                 ;
    wire                 [16*8-1: 0]    AT_data1_8b                 ;
    wire                 [  11: 0]      Result0_8b                  ;
    wire                 [  11: 0]      Result1_8b                  ;
    wire                 [  15: 0]      Result_12b                  ;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : GEN_PE

            cache_PE_unit u_cache_PE_unit(
                .gclk                               (gclk[i]                   ),
                .precision_i                        (precision_i               ),
                .W_update_i                         (W_update_i                ),
                .W_i                                (W_i[8*i+7:8*i]            ),

                .IA0_i                              (IA0_i[4*i+3:4*i]          ),
                .Cache0_update_i                    (Cache0_update_i[i]        ),
                .Cache0_hit_i                       (Cache0_hit_i[i]           ),
                .Cache0_code_i                      (Cache0_code_i[2*i+1:2*i]  ),
                .OA0_o                              (OA0[8*i+7:8*i]            ),

                .IA1_i                              (IA1_i[4*i+3:4*i]          ),
                .Cache1_update_i                    (Cache1_update_i[i]        ),
                .Cache1_hit_i                       (Cache1_hit_i[i]           ),
                .Cache1_code_i                      (Cache1_code_i[2*i+1:2*i]  ),
                .OA1_o                              (OA1[8*i+7:8*i]            ),

                .OA_o                               (OA[12*i+11:12*i]          )
            );

            assign AT_data0_8b[8*i+7:8*i] = precision_i ? OA[12*i+7:12*i] : OA0[8*i+7:8*i];
            assign AT_data1_8b[8*i+7:8*i] = precision_i ? {OA[12*i+11:12*i+8],4'b0000} : OA1[8*i+7:8*i];
        
        end

    endgenerate

    adder_tree_8b_unit u_adder_tree_8b_unit0(
        .sign_i                             (~precision_i              ),
        .data_i                             (AT_data0_8b               ),
        .data_o                             (Result0_8b                )
    );

    adder_tree_8b_unit u_adder_tree_8b_unit1(
        .sign_i                             (1'b1                      ),
        .data_i                             (AT_data1_8b               ),
        .data_o                             (Result1_8b                )
    );

    assign Result_12b = $signed({{12{precision_i}}&Result1_8b,4'b0000}) + $unsigned({12{precision_i}}&Result0_8b);
    assign Result_o = precision_i ? {8'b0,Result_12b} : {Result1_8b,Result0_8b};

endmodule