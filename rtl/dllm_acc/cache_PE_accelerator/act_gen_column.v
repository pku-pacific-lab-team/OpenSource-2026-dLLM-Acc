`timescale 1ns / 1ps

module act_gen_column(
    input  wire                         clk                        ,
    input  wire                         en_i                       ,
    input  wire                         precision_i                ,

    input  wire                         Cache0_idx_update_i        ,
    input  wire                         Cache1_idx_update_i        ,
    input  wire          [   1: 0]      Cache_idx_addr_i           ,
    input  wire          [16*4-1: 0]    Cache_idx_data_i           ,

    input  wire          [16*4-1: 0]    IA0_i                      ,
    output wire          [16*4-1: 0]    IA0_o                      ,
    output wire          [16-1: 0]      Cache0_update_o            ,
    output wire          [16-1: 0]      Cache0_hit_o               ,
    output wire          [16*2-1: 0]    Cache0_code_o              ,

    input  wire          [16*4-1: 0]    IA1_i                      ,
    output wire          [16*4-1: 0]    IA1_o                      ,
    output wire          [16-1: 0]      Cache1_update_o            ,
    output wire          [16-1: 0]      Cache1_hit_o               ,
    output wire          [16*2-1: 0]    Cache1_code_o              ,

    input  wire                         W_update_i                 ,
    output wire          [  15: 0]      gclk                       ,

    input  wire                         C2C_A0_input_sel_i         ,
    input  wire                         C2C_A0_bypass_i            ,
    input  wire                         C2C_A0_recv_en_i           ,
    input  wire          [16*5-1: 0]    C2C_A0_recv_i              ,
    input  wire                         C2C_A0_send_en_i           ,
    output wire          [16*5-1: 0]    C2C_A0_send_o              ,
    input  wire                         C2C_A1_input_sel_i         ,
    input  wire                         C2C_A1_bypass_i            ,
    input  wire                         C2C_A1_recv_en_i           ,
    input  wire          [16*5-1: 0]    C2C_A1_recv_i              ,
    input  wire                         C2C_A1_send_en_i           ,
    output wire          [16*5-1: 0]    C2C_A1_send_o              ,
    input  wire                         C2C_A1_encode_en_i
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : GEN_ACT_GEN
           act_gen_unit u_act_gen_unit(
                .clk                                (clk                       ),
                .en_i                               (en_i                      ),
                .precision_i                        (precision_i               ),

                .Cache0_idx_update_i                (Cache0_idx_update_i       ),
                .Cache1_idx_update_i                (Cache1_idx_update_i       ),
                .Cache_idx_addr_i                   (Cache_idx_addr_i          ),
                .Cache_idx_data_i                   (Cache_idx_data_i[4*i+3:4*i]),

                .IA0_i                              (IA0_i[4*i+3:4*i]          ),
                .IA0_o                              (IA0_o[4*i+3:4*i]          ),
                .Cache0_update_o                    (Cache0_update_o[i]        ),
                .Cache0_hit_o                       (Cache0_hit_o[i]           ),
                .Cache0_code_o                      (Cache0_code_o[2*i+1:2*i]  ),

                .IA1_i                              (IA1_i[4*i+3:4*i]          ),
                .IA1_o                              (IA1_o[4*i+3:4*i]          ),
                .Cache1_update_o                    (Cache1_update_o[i]        ),
                .Cache1_hit_o                       (Cache1_hit_o[i]           ),
                .Cache1_code_o                      (Cache1_code_o[2*i+1:2*i]  ),

                .C2C_A0_input_sel_i                 (C2C_A0_input_sel_i        ),
                .C2C_A0_bypass_i                    (C2C_A0_bypass_i           ),
                .C2C_A0_recv_en_i                   (C2C_A0_recv_en_i          ),
                .C2C_A0_recv_i                      (C2C_A0_recv_i[5*i+4:5*i]  ),
                .C2C_A0_send_en_i                   (C2C_A0_send_en_i          ),
                .C2C_A0_send_o                      (C2C_A0_send_o[5*i+4:5*i]  ),
                .C2C_A1_input_sel_i                 (C2C_A1_input_sel_i        ),
                .C2C_A1_bypass_i                    (C2C_A1_bypass_i           ),
                .C2C_A1_recv_en_i                   (C2C_A1_recv_en_i          ),
                .C2C_A1_recv_i                      (C2C_A1_recv_i[5*i+4:5*i]  ),
                .C2C_A1_send_en_i                   (C2C_A1_send_en_i          ),
                .C2C_A1_send_o                      (C2C_A1_send_o[5*i+4:5*i]  ),
                .C2C_A1_encode_en_i                 (C2C_A1_encode_en_i        )
            );

            gclk_unit u_gclk_unit(
                .clk_i                              (clk                       ),
                .en_i                               (Cache0_update_o[i]|Cache1_update_o[i]|W_update_i),
                .test_en_i                          (1'b0                      ),
                .gclk_o                             (gclk[i]                   ) 
            );
        end
    endgenerate
                                                                                                                                      
endmodule
