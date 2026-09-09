`timescale 1ns / 1ps

module cache_PE_array(
    input  wire                         clk                        ,
    input  wire                         en_i                       ,
    input  wire                         precision_i                ,
    input  wire                         broadcast_i                ,

    input  wire          [  15: 0]      W_update_i                 ,
    input  wire          [ 127: 0]      W_i                        ,

    input  wire                         Cache0_idx_update_i        ,
    input  wire                         Cache1_idx_update_i        ,
    input  wire          [   1: 0]      Cache_idx_addr_i           ,
    input  wire          [  63: 0]      Cache_idx_data_i           ,

    input  wire          [  63: 0]      IA0_i                      ,
    input  wire          [  63: 0]      IA1_i                      ,

    output wire          [ 383: 0]      Result_o                   ,

    input  wire                         C2C_A0_input_sel_i         ,
    input  wire                         C2C_A0_bypass_i            ,
    input  wire                         C2C_A0_recv_en_i           ,
    input  wire          [  79: 0]      C2C_A0_recv_i              ,
    input  wire                         C2C_A0_send_en_i           ,
    output wire          [  79: 0]      C2C_A0_send_o              ,
    input  wire                         C2C_A1_input_sel_i         ,
    input  wire                         C2C_A1_bypass_i            ,
    input  wire                         C2C_A1_recv_en_i           ,
    input  wire          [  79: 0]      C2C_A1_recv_i              ,
    input  wire                         C2C_A1_send_en_i           ,
    output wire          [  79: 0]      C2C_A1_send_o              ,
    input  wire                         C2C_A1_encode_en_i
);

    wire                 [  63: 0]      IA0                         ;
    wire                 [  15: 0]      Cache0_update               ;
    wire                 [  15: 0]      Cache0_hit                  ;
    wire                 [  31: 0]      Cache0_code                 ;

    wire                 [  63: 0]      IA1                         ;
    wire                 [  15: 0]      Cache1_update               ;
    wire                 [  15: 0]      Cache1_hit                  ;
    wire                 [  31: 0]      Cache1_code                 ;

    wire                 [  63: 0]      IA1_sel                     ;
    wire                 [  15: 0]      Cache1_update_sel           ;
    wire                 [  15: 0]      Cache1_hit_sel              ;
    wire                 [  31: 0]      Cache1_code_sel             ;

    wire                 [  15: 0]      gclk                        ;

    act_gen_column u_act_gen_column(
        .clk                                (clk                       ),
        .en_i                               (en_i                      ),
        .precision_i                        (precision_i               ),

        .Cache0_idx_update_i                (Cache0_idx_update_i       ),
        .Cache1_idx_update_i                (Cache1_idx_update_i       ),
        .Cache_idx_addr_i                   (Cache_idx_addr_i          ),
        .Cache_idx_data_i                   (Cache_idx_data_i[63:0]    ),

        .IA0_i                              (IA0_i                     ),
        .IA0_o                              (IA0                       ),
        .Cache0_update_o                    (Cache0_update             ),
        .Cache0_hit_o                       (Cache0_hit                ),
        .Cache0_code_o                      (Cache0_code               ),

        .IA1_i                              (IA1_i                     ),
        .IA1_o                              (IA1                       ),
        .Cache1_update_o                    (Cache1_update             ),
        .Cache1_hit_o                       (Cache1_hit                ),
        .Cache1_code_o                      (Cache1_code               ),

        .W_update_i                         (|W_update_i               ),
        .gclk                               (gclk                      ),

        .C2C_A0_input_sel_i                 (C2C_A0_input_sel_i        ),
        .C2C_A0_bypass_i                    (C2C_A0_bypass_i           ),
        .C2C_A0_recv_en_i                   (C2C_A0_recv_en_i          ),
        .C2C_A0_recv_i                      (C2C_A0_recv_i             ),
        .C2C_A0_send_en_i                   (C2C_A0_send_en_i          ),
        .C2C_A0_send_o                      (C2C_A0_send_o             ),
        .C2C_A1_input_sel_i                 (C2C_A1_input_sel_i        ),
        .C2C_A1_bypass_i                    (C2C_A1_bypass_i           ),
        .C2C_A1_recv_en_i                   (C2C_A1_recv_en_i          ),
        .C2C_A1_recv_i                      (C2C_A1_recv_i             ),
        .C2C_A1_send_en_i                   (C2C_A1_send_en_i          ),
        .C2C_A1_send_o                      (C2C_A1_send_o             ),
        .C2C_A1_encode_en_i                 (C2C_A1_encode_en_i        )
    );

    assign                              IA1_sel                     = broadcast_i ? IA0 : IA1;
    assign                              Cache1_update_sel           = broadcast_i ? Cache0_update : Cache1_update;
    assign                              Cache1_hit_sel              = broadcast_i ? Cache0_hit : Cache1_hit;
    assign                              Cache1_code_sel             = broadcast_i ? Cache0_code : Cache1_code;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : GEN_PE_COL
            cache_PE_column u_cache_PE_column(
                .gclk                               (gclk                      ),
                .precision_i                        (precision_i               ),
                .W_update_i                         (W_update_i[i]             ),
                .W_i                                (W_i                       ),

                .IA0_i                              (IA0                       ),
                .Cache0_update_i                    (Cache0_update             ),
                .Cache0_hit_i                       (Cache0_hit                ),
                .Cache0_code_i                      (Cache0_code               ),

                .IA1_i                              (IA1_sel                   ),
                .Cache1_update_i                    (Cache1_update_sel         ),
                .Cache1_hit_i                       (Cache1_hit_sel            ),
                .Cache1_code_i                      (Cache1_code_sel           ),

                .Result_o                           (Result_o[24*i+23:24*i]    ) 
            );
        end
    endgenerate                                                                 
                                                                   
endmodule
