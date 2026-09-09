`timescale 1ns / 1ps

module cache_PE_accelerator(
    input  wire                         clk                        ,
    input  wire                         rst_n                      ,

    input  wire                         core0_axi_req_i            ,
    input  wire                         core0_axi_we_i             ,
    input  wire          [  63: 0]      core0_axi_addr_i           ,
    input  wire          [  63: 0]      core0_axi_wdata_i          ,
    output wire          [  63: 0]      core0_axi_rdata_o          ,
    input  wire          [   1: 0]      core0_csr_en_i             ,
    input  wire          [  41: 0]      core0_csr_cfg_i            ,
    output wire          [   1: 0]      core0_csr_flag_o           ,

    input  wire                         core1_axi_req_i            ,
    input  wire                         core1_axi_we_i             ,
    input  wire          [  63: 0]      core1_axi_addr_i           ,
    input  wire          [  63: 0]      core1_axi_wdata_i          ,
    output  wire         [  63: 0]      core1_axi_rdata_o          ,
    input  wire          [   1: 0]      core1_csr_en_i             ,
    input  wire          [  41: 0]      core1_csr_cfg_i            ,
    output wire          [   1: 0]      core1_csr_flag_o           ,
    
    input  wire                         core2_axi_req_i            ,
    input  wire                         core2_axi_we_i             ,
    input  wire          [  63: 0]      core2_axi_addr_i           ,
    input  wire          [  63: 0]      core2_axi_wdata_i          ,
    output wire          [  63: 0]      core2_axi_rdata_o          ,
    input  wire          [   1: 0]      core2_csr_en_i             ,
    input  wire          [  41: 0]      core2_csr_cfg_i            ,
    output wire          [   1: 0]      core2_csr_flag_o           ,

    input  wire                         core3_axi_req_i            ,
    input  wire                         core3_axi_we_i             ,
    input  wire          [  63: 0]      core3_axi_addr_i           ,
    input  wire          [  63: 0]      core3_axi_wdata_i          ,
    output wire          [  63: 0]      core3_axi_rdata_o          ,
    input  wire          [   1: 0]      core3_csr_en_i             ,
    input  wire          [  41: 0]      core3_csr_cfg_i            ,
    output wire          [   1: 0]      core3_csr_flag_o           ,

    input  wire                         core4_axi_req_i            ,
    input  wire                         core4_axi_we_i             ,
    input  wire          [  63: 0]      core4_axi_addr_i           ,
    input  wire          [  63: 0]      core4_axi_wdata_i          ,
    output wire          [  63: 0]      core4_axi_rdata_o          ,
    input  wire          [   1: 0]      core4_csr_en_i             ,
    input  wire          [  41: 0]      core4_csr_cfg_i            ,
    output wire          [   1: 0]      core4_csr_flag_o           ,

    input  wire                         core5_axi_req_i            ,
    input  wire                         core5_axi_we_i             ,
    input  wire          [  63: 0]      core5_axi_addr_i           ,
    input  wire          [  63: 0]      core5_axi_wdata_i          ,
    output wire          [  63: 0]      core5_axi_rdata_o          ,
    input  wire          [   1: 0]      core5_csr_en_i             ,
    input  wire          [  41: 0]      core5_csr_cfg_i            ,
    output wire          [   1: 0]      core5_csr_flag_o           ,

    input  wire                         core6_axi_req_i            ,
    input  wire                         core6_axi_we_i             ,
    input  wire          [  63: 0]      core6_axi_addr_i           ,
    input  wire          [  63: 0]      core6_axi_wdata_i          ,
    output wire          [  63: 0]      core6_axi_rdata_o          ,
    input  wire          [   1: 0]      core6_csr_en_i             ,
    input  wire          [  41: 0]      core6_csr_cfg_i            ,
    output wire          [   1: 0]      core6_csr_flag_o           ,

    input  wire                         core7_axi_req_i            ,
    input  wire                         core7_axi_we_i             ,
    input  wire          [  63: 0]      core7_axi_addr_i           ,
    input  wire          [  63: 0]      core7_axi_wdata_i          ,
    output wire          [  63: 0]      core7_axi_rdata_o          ,
    input  wire          [   1: 0]      core7_csr_en_i             ,
    input  wire          [  41: 0]      core7_csr_cfg_i            ,
    output wire          [   1: 0]      core7_csr_flag_o           ,

    input  wire                         core8_axi_req_i            ,
    input  wire                         core8_axi_we_i             ,
    input  wire          [  63: 0]      core8_axi_addr_i           ,
    input  wire          [  63: 0]      core8_axi_wdata_i          ,
    output wire          [  63: 0]      core8_axi_rdata_o          ,
    input  wire          [   1: 0]      core8_csr_en_i             ,
    input  wire          [  41: 0]      core8_csr_cfg_i            ,
    output wire          [   1: 0]      core8_csr_flag_o           ,

    input  wire                         core9_axi_req_i            ,
    input  wire                         core9_axi_we_i             ,
    input  wire          [  63: 0]      core9_axi_addr_i           ,
    input  wire          [  63: 0]      core9_axi_wdata_i          ,
    output wire          [  63: 0]      core9_axi_rdata_o          ,
    input  wire          [   1: 0]      core9_csr_en_i             ,
    input  wire          [  41: 0]      core9_csr_cfg_i            ,
    output wire          [   1: 0]      core9_csr_flag_o           ,

    input  wire                         core10_axi_req_i           ,
    input  wire                         core10_axi_we_i            ,
    input  wire          [  63: 0]      core10_axi_addr_i          ,
    input  wire          [  63: 0]      core10_axi_wdata_i         ,
    output wire          [  63: 0]      core10_axi_rdata_o         ,
    input  wire          [   1: 0]      core10_csr_en_i            ,
    input  wire          [  41: 0]      core10_csr_cfg_i           ,
    output wire          [   1: 0]      core10_csr_flag_o          ,

    input  wire                         core11_axi_req_i           ,
    input  wire                         core11_axi_we_i            ,
    input  wire          [  63: 0]      core11_axi_addr_i          ,
    input  wire          [  63: 0]      core11_axi_wdata_i         ,
    output wire          [  63: 0]      core11_axi_rdata_o         ,
    input  wire          [   1: 0]      core11_csr_en_i            ,
    input  wire          [  41: 0]      core11_csr_cfg_i           ,
    output wire          [   1: 0]      core11_csr_flag_o          ,

    input  wire                         core12_axi_req_i           ,
    input  wire                         core12_axi_we_i            ,
    input  wire          [  63: 0]      core12_axi_addr_i          ,
    input  wire          [  63: 0]      core12_axi_wdata_i         ,
    output wire          [  63: 0]      core12_axi_rdata_o         ,
    input  wire          [   1: 0]      core12_csr_en_i            ,
    input  wire          [  41: 0]      core12_csr_cfg_i           ,
    output wire          [   1: 0]      core12_csr_flag_o          ,

    input  wire                         core13_axi_req_i           ,
    input  wire                         core13_axi_we_i            ,
    input  wire          [  63: 0]      core13_axi_addr_i          ,
    input  wire          [  63: 0]      core13_axi_wdata_i         ,
    output wire          [  63: 0]      core13_axi_rdata_o         ,
    input  wire          [   1: 0]      core13_csr_en_i            ,
    input  wire          [  41: 0]      core13_csr_cfg_i           ,
    output wire          [   1: 0]      core13_csr_flag_o          ,

    input  wire                         core14_axi_req_i           ,
    input  wire                         core14_axi_we_i            ,
    input  wire          [  63: 0]      core14_axi_addr_i          ,
    input  wire          [  63: 0]      core14_axi_wdata_i         ,
    output wire          [  63: 0]      core14_axi_rdata_o         ,
    input  wire          [   1: 0]      core14_csr_en_i            ,
    input  wire          [  41: 0]      core14_csr_cfg_i           ,
    output wire          [   1: 0]      core14_csr_flag_o          ,

    input  wire                         core15_axi_req_i           ,
    input  wire                         core15_axi_we_i            ,
    input  wire          [  63: 0]      core15_axi_addr_i          ,
    input  wire          [  63: 0]      core15_axi_wdata_i         ,
    output wire          [  63: 0]      core15_axi_rdata_o         ,
    input  wire          [   1: 0]      core15_csr_en_i            ,
    input  wire          [  41: 0]      core15_csr_cfg_i           ,
    output wire          [   1: 0]      core15_csr_flag_o           
);

//////////////////////////////// Core0(0,0) ////////////////////////////////
    wire                                core0_csr_precision        ;
    wire                                core0_csr_broadcast        ;
    wire                 [   8: 0]      core0_csr_W_addr           ;
    wire                 [   6: 0]      core0_csr_A_addr           ;
    wire                 [   6: 0]      core0_csr_A_cnt            ;
    wire                                core0_csr_test_en          ;
    wire                                core0_csr_O_wen            ;
    wire                                core0_csr_W_load_done      ;
    wire                                core0_csr_cal_done         ;
    wire                                core0_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core0_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core0_csr_C2C_A1_recv      ;
    wire                                core0_csr_C2C_A0_input_sel ;
    wire                                core0_csr_C2C_A1_input_sel ;
    wire                                core0_csr_C2C_A0_recv_en   ;
    wire                                core0_csr_C2C_A1_recv_en   ;
    wire                                core0_csr_C2C_A0_bypass    ;
    wire                                core0_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core0_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core0_csr_C2C_A1_send      ;

    assign                              core0_csr_W_addr            = core0_csr_cfg_i[8:0] ;
    assign                              core0_csr_A_addr            = core0_csr_cfg_i[15:9];
    assign                              core0_csr_A_cnt             = core0_csr_cfg_i[22:16];
    assign                              core0_csr_precision         = core0_csr_cfg_i[23]  ;
    assign                              core0_csr_broadcast         = core0_csr_cfg_i[24]  ;
    assign                              core0_csr_test_en           = core0_csr_cfg_i[25]  ;
    assign                              core0_csr_O_wen             = core0_csr_cfg_i[26]  ;

    assign                              core0_csr_C2C_A1_encode_en  = core0_csr_cfg_i[27]  ;
    assign                              core0_csr_C2C_A0_recv       = core0_csr_cfg_i[29:28];
    assign                              core0_csr_C2C_A1_recv       = core0_csr_cfg_i[31:30];
    assign                              core0_csr_C2C_A0_input_sel  = core0_csr_cfg_i[32]  ;
    assign                              core0_csr_C2C_A1_input_sel  = core0_csr_cfg_i[33]  ;
    assign                              core0_csr_C2C_A0_recv_en    = core0_csr_cfg_i[34]  ;
    assign                              core0_csr_C2C_A1_recv_en    = core0_csr_cfg_i[35]  ;
    assign                              core0_csr_C2C_A0_bypass     = core0_csr_cfg_i[36]  ;
    assign                              core0_csr_C2C_A1_bypass     = core0_csr_cfg_i[37]  ;
    assign                              core0_csr_C2C_A0_send       = core0_csr_cfg_i[39:38];
    assign                              core0_csr_C2C_A1_send       = core0_csr_cfg_i[41:40];

    assign                              core0_csr_flag_o[0]         = core0_csr_cal_done   ;
    assign                              core0_csr_flag_o[1]         = core0_csr_W_load_done;

    wire                 [  79: 0]      core0_C2C_A0_send_E        ;
    wire                 [  79: 0]      core0_C2C_A1_send_E        ;
    wire                 [  79: 0]      core0_C2C_A0_send_S        ;
    wire                 [  79: 0]      core0_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_0(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core0_csr_precision       ),
    .csr_broadcast_i                    (core0_csr_broadcast       ),
    .csr_W_addr_i                       (core0_csr_W_addr          ),
    .csr_A_addr_i                       (core0_csr_A_addr          ),
    .csr_A_cnt_i                        (core0_csr_A_cnt           ),
    .csr_W_load_en_i                    (core0_csr_en_i[0]         ),
    .csr_cal_en_i                       (core0_csr_en_i[1]         ),
    .csr_test_en_i                      (core0_csr_test_en         ),
    .csr_O_wen_i                        (core0_csr_O_wen           ),
    .csr_W_load_done_o                  (core0_csr_W_load_done     ),
    .csr_cal_done_o                     (core0_csr_cal_done        ),
    .axi_req_i                          (core0_axi_req_i           ),
    .axi_we_i                           (core0_axi_we_i            ),
    .axi_addr_i                         (core0_axi_addr_i          ),
    .axi_wdata_i                        (core0_axi_wdata_i         ),
    .axi_rdata_o                        (core0_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core0_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core0_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core0_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core0_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core0_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core0_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core0_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core0_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core0_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core0_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core0_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (80'd0                     ),
    .C2C_A1_recv_W_i                    (80'd0                     ),
    .C2C_A0_recv_N_i                    (80'd0                     ),
    .C2C_A1_recv_N_i                    (80'd0                     ),
    .C2C_A0_send_E_o                    (core0_C2C_A0_send_E       ),
    .C2C_A1_send_E_o                    (core0_C2C_A1_send_E       ),
    .C2C_A0_send_S_o                    (core0_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core0_C2C_A1_send_S       ) 
);

//////////////////////////////// Core1(0,1) ////////////////////////////////
    wire                                core1_csr_precision        ;
    wire                                core1_csr_broadcast        ;
    wire                 [   8: 0]      core1_csr_W_addr           ;
    wire                 [   6: 0]      core1_csr_A_addr           ;
    wire                 [   6: 0]      core1_csr_A_cnt            ;
    wire                                core1_csr_test_en          ;
    wire                                core1_csr_O_wen            ;
    wire                                core1_csr_W_load_done      ;
    wire                                core1_csr_cal_done         ;
    wire                                core1_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core1_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core1_csr_C2C_A1_recv      ;
    wire                                core1_csr_C2C_A0_input_sel ;
    wire                                core1_csr_C2C_A1_input_sel ;
    wire                                core1_csr_C2C_A0_recv_en   ;
    wire                                core1_csr_C2C_A1_recv_en   ;
    wire                                core1_csr_C2C_A0_bypass    ;
    wire                                core1_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core1_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core1_csr_C2C_A1_send      ;

    assign                              core1_csr_W_addr            = core1_csr_cfg_i[8:0] ;
    assign                              core1_csr_A_addr            = core1_csr_cfg_i[15:9];
    assign                              core1_csr_A_cnt             = core1_csr_cfg_i[22:16];
    assign                              core1_csr_precision         = core1_csr_cfg_i[23]  ;
    assign                              core1_csr_broadcast         = core1_csr_cfg_i[24]  ;
    assign                              core1_csr_test_en           = core1_csr_cfg_i[25]  ;
    assign                              core1_csr_O_wen             = core1_csr_cfg_i[26]  ;

    assign                              core1_csr_C2C_A1_encode_en  = core1_csr_cfg_i[27]  ;
    assign                              core1_csr_C2C_A0_recv       = core1_csr_cfg_i[29:28];
    assign                              core1_csr_C2C_A1_recv       = core1_csr_cfg_i[31:30];
    assign                              core1_csr_C2C_A0_input_sel  = core1_csr_cfg_i[32]  ;
    assign                              core1_csr_C2C_A1_input_sel  = core1_csr_cfg_i[33]  ;
    assign                              core1_csr_C2C_A0_recv_en    = core1_csr_cfg_i[34]  ;
    assign                              core1_csr_C2C_A1_recv_en    = core1_csr_cfg_i[35]  ;
    assign                              core1_csr_C2C_A0_bypass     = core1_csr_cfg_i[36]  ;
    assign                              core1_csr_C2C_A1_bypass     = core1_csr_cfg_i[37]  ;
    assign                              core1_csr_C2C_A0_send       = core1_csr_cfg_i[39:38];
    assign                              core1_csr_C2C_A1_send       = core1_csr_cfg_i[41:40];

    assign                              core1_csr_flag_o[0]         = core1_csr_cal_done   ;
    assign                              core1_csr_flag_o[1]         = core1_csr_W_load_done;

    wire                 [  79: 0]      core1_C2C_A0_send_E        ;
    wire                 [  79: 0]      core1_C2C_A1_send_E        ;
    wire                 [  79: 0]      core1_C2C_A0_send_S        ;
    wire                 [  79: 0]      core1_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_1(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core1_csr_precision       ),
    .csr_broadcast_i                    (core1_csr_broadcast       ),
    .csr_W_addr_i                       (core1_csr_W_addr          ),
    .csr_A_addr_i                       (core1_csr_A_addr          ),
    .csr_A_cnt_i                        (core1_csr_A_cnt           ),
    .csr_W_load_en_i                    (core1_csr_en_i[0]         ),
    .csr_cal_en_i                       (core1_csr_en_i[1]         ),
    .csr_test_en_i                      (core1_csr_test_en         ),
    .csr_O_wen_i                        (core1_csr_O_wen           ),
    .csr_W_load_done_o                  (core1_csr_W_load_done     ),
    .csr_cal_done_o                     (core1_csr_cal_done        ),
    .axi_req_i                          (core1_axi_req_i           ),
    .axi_we_i                           (core1_axi_we_i            ),
    .axi_addr_i                         (core1_axi_addr_i          ),
    .axi_wdata_i                        (core1_axi_wdata_i         ),
    .axi_rdata_o                        (core1_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core1_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core1_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core1_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core1_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core1_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core1_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core1_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core1_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core1_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core1_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core1_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (core0_C2C_A0_send_E       ),
    .C2C_A1_recv_W_i                    (core0_C2C_A1_send_E       ),
    .C2C_A0_recv_N_i                    (80'd0                     ),
    .C2C_A1_recv_N_i                    (80'd0                     ),
    .C2C_A0_send_E_o                    (core1_C2C_A0_send_E       ),
    .C2C_A1_send_E_o                    (core1_C2C_A1_send_E       ),
    .C2C_A0_send_S_o                    (core1_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core1_C2C_A1_send_S       ) 
);

//////////////////////////////// Core2(0,2) ////////////////////////////////
    wire                                core2_csr_precision        ;
    wire                                core2_csr_broadcast        ;
    wire                 [   8: 0]      core2_csr_W_addr           ;
    wire                 [   6: 0]      core2_csr_A_addr           ;
    wire                 [   6: 0]      core2_csr_A_cnt            ;
    wire                                core2_csr_test_en          ;
    wire                                core2_csr_O_wen            ;
    wire                                core2_csr_W_load_done      ;
    wire                                core2_csr_cal_done         ;
    wire                                core2_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core2_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core2_csr_C2C_A1_recv      ;
    wire                                core2_csr_C2C_A0_input_sel ;
    wire                                core2_csr_C2C_A1_input_sel ;
    wire                                core2_csr_C2C_A0_recv_en   ;
    wire                                core2_csr_C2C_A1_recv_en   ;
    wire                                core2_csr_C2C_A0_bypass    ;
    wire                                core2_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core2_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core2_csr_C2C_A1_send      ;

    assign                              core2_csr_W_addr            = core2_csr_cfg_i[8:0] ;
    assign                              core2_csr_A_addr            = core2_csr_cfg_i[15:9];
    assign                              core2_csr_A_cnt             = core2_csr_cfg_i[22:16];
    assign                              core2_csr_precision         = core2_csr_cfg_i[23]  ;
    assign                              core2_csr_broadcast         = core2_csr_cfg_i[24]  ;
    assign                              core2_csr_test_en           = core2_csr_cfg_i[25]  ;
    assign                              core2_csr_O_wen             = core2_csr_cfg_i[26]  ;

    assign                              core2_csr_C2C_A1_encode_en  = core2_csr_cfg_i[27]  ;
    assign                              core2_csr_C2C_A0_recv       = core2_csr_cfg_i[29:28];
    assign                              core2_csr_C2C_A1_recv       = core2_csr_cfg_i[31:30];
    assign                              core2_csr_C2C_A0_input_sel  = core2_csr_cfg_i[32]  ;
    assign                              core2_csr_C2C_A1_input_sel  = core2_csr_cfg_i[33]  ;
    assign                              core2_csr_C2C_A0_recv_en    = core2_csr_cfg_i[34]  ;
    assign                              core2_csr_C2C_A1_recv_en    = core2_csr_cfg_i[35]  ;
    assign                              core2_csr_C2C_A0_bypass     = core2_csr_cfg_i[36]  ;
    assign                              core2_csr_C2C_A1_bypass     = core2_csr_cfg_i[37]  ;
    assign                              core2_csr_C2C_A0_send       = core2_csr_cfg_i[39:38];
    assign                              core2_csr_C2C_A1_send       = core2_csr_cfg_i[41:40];

    assign                              core2_csr_flag_o[0]         = core2_csr_cal_done   ;
    assign                              core2_csr_flag_o[1]         = core2_csr_W_load_done;

    wire                 [  79: 0]      core2_C2C_A0_send_E        ;
    wire                 [  79: 0]      core2_C2C_A1_send_E        ;
    wire                 [  79: 0]      core2_C2C_A0_send_S        ;
    wire                 [  79: 0]      core2_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_2(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core2_csr_precision       ),
    .csr_broadcast_i                    (core2_csr_broadcast       ),
    .csr_W_addr_i                       (core2_csr_W_addr          ),
    .csr_A_addr_i                       (core2_csr_A_addr          ),
    .csr_A_cnt_i                        (core2_csr_A_cnt           ),
    .csr_W_load_en_i                    (core2_csr_en_i[0]         ),
    .csr_cal_en_i                       (core2_csr_en_i[1]         ),
    .csr_test_en_i                      (core2_csr_test_en         ),
    .csr_O_wen_i                        (core2_csr_O_wen           ),
    .csr_W_load_done_o                  (core2_csr_W_load_done     ),
    .csr_cal_done_o                     (core2_csr_cal_done        ),
    .axi_req_i                          (core2_axi_req_i           ),
    .axi_we_i                           (core2_axi_we_i            ),
    .axi_addr_i                         (core2_axi_addr_i          ),
    .axi_wdata_i                        (core2_axi_wdata_i         ),
    .axi_rdata_o                        (core2_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core2_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core2_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core2_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core2_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core2_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core2_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core2_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core2_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core2_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core2_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core2_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (core1_C2C_A0_send_E       ),
    .C2C_A1_recv_W_i                    (core1_C2C_A1_send_E       ),
    .C2C_A0_recv_N_i                    (80'd0                     ),
    .C2C_A1_recv_N_i                    (80'd0                     ),
    .C2C_A0_send_E_o                    (core2_C2C_A0_send_E       ),
    .C2C_A1_send_E_o                    (core2_C2C_A1_send_E       ),
    .C2C_A0_send_S_o                    (core2_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core2_C2C_A1_send_S       ) 
);

//////////////////////////////// Core3(0,3) ////////////////////////////////
    wire                                core3_csr_precision        ;
    wire                                core3_csr_broadcast        ;
    wire                 [   8: 0]      core3_csr_W_addr           ;
    wire                 [   6: 0]      core3_csr_A_addr           ;
    wire                 [   6: 0]      core3_csr_A_cnt            ;
    wire                                core3_csr_test_en          ;
    wire                                core3_csr_O_wen            ;
    wire                                core3_csr_W_load_done      ;
    wire                                core3_csr_cal_done         ;
    wire                                core3_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core3_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core3_csr_C2C_A1_recv      ;
    wire                                core3_csr_C2C_A0_input_sel ;
    wire                                core3_csr_C2C_A1_input_sel ;
    wire                                core3_csr_C2C_A0_recv_en   ;
    wire                                core3_csr_C2C_A1_recv_en   ;
    wire                                core3_csr_C2C_A0_bypass    ;
    wire                                core3_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core3_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core3_csr_C2C_A1_send      ;

    assign                              core3_csr_W_addr            = core3_csr_cfg_i[8:0] ;
    assign                              core3_csr_A_addr            = core3_csr_cfg_i[15:9];
    assign                              core3_csr_A_cnt             = core3_csr_cfg_i[22:16];
    assign                              core3_csr_precision         = core3_csr_cfg_i[23]  ;
    assign                              core3_csr_broadcast         = core3_csr_cfg_i[24]  ;
    assign                              core3_csr_test_en           = core3_csr_cfg_i[25]  ;
    assign                              core3_csr_O_wen             = core3_csr_cfg_i[26]  ;

    assign                              core3_csr_C2C_A1_encode_en  = core3_csr_cfg_i[27]  ;
    assign                              core3_csr_C2C_A0_recv       = core3_csr_cfg_i[29:28];
    assign                              core3_csr_C2C_A1_recv       = core3_csr_cfg_i[31:30];
    assign                              core3_csr_C2C_A0_input_sel  = core3_csr_cfg_i[32]  ;
    assign                              core3_csr_C2C_A1_input_sel  = core3_csr_cfg_i[33]  ;
    assign                              core3_csr_C2C_A0_recv_en    = core3_csr_cfg_i[34]  ;
    assign                              core3_csr_C2C_A1_recv_en    = core3_csr_cfg_i[35]  ;
    assign                              core3_csr_C2C_A0_bypass     = core3_csr_cfg_i[36]  ;
    assign                              core3_csr_C2C_A1_bypass     = core3_csr_cfg_i[37]  ;
    assign                              core3_csr_C2C_A0_send       = core3_csr_cfg_i[39:38];
    assign                              core3_csr_C2C_A1_send       = core3_csr_cfg_i[41:40];

    assign                              core3_csr_flag_o[0]         = core3_csr_cal_done   ;
    assign                              core3_csr_flag_o[1]         = core3_csr_W_load_done;

    wire                 [  79: 0]      core3_C2C_A0_send_S        ;
    wire                 [  79: 0]      core3_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_3(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core3_csr_precision       ),
    .csr_broadcast_i                    (core3_csr_broadcast       ),
    .csr_W_addr_i                       (core3_csr_W_addr          ),
    .csr_A_addr_i                       (core3_csr_A_addr          ),
    .csr_A_cnt_i                        (core3_csr_A_cnt           ),
    .csr_W_load_en_i                    (core3_csr_en_i[0]         ),
    .csr_cal_en_i                       (core3_csr_en_i[1]         ),
    .csr_test_en_i                      (core3_csr_test_en         ),
    .csr_O_wen_i                        (core3_csr_O_wen           ),
    .csr_W_load_done_o                  (core3_csr_W_load_done     ),
    .csr_cal_done_o                     (core3_csr_cal_done        ),
    .axi_req_i                          (core3_axi_req_i           ),
    .axi_we_i                           (core3_axi_we_i            ),
    .axi_addr_i                         (core3_axi_addr_i          ),
    .axi_wdata_i                        (core3_axi_wdata_i         ),
    .axi_rdata_o                        (core3_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core3_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core3_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core3_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core3_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core3_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core3_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core3_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core3_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core3_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core3_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core3_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (core2_C2C_A0_send_E       ),
    .C2C_A1_recv_W_i                    (core2_C2C_A1_send_E       ),
    .C2C_A0_recv_N_i                    (80'd0                     ),
    .C2C_A1_recv_N_i                    (80'd0                     ),
    .C2C_A0_send_E_o                    (                          ),
    .C2C_A1_send_E_o                    (                          ),
    .C2C_A0_send_S_o                    (core3_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core3_C2C_A1_send_S       ) 
);

//////////////////////////////// Core4(1,0) ////////////////////////////////
    wire                                core4_csr_precision        ;
    wire                                core4_csr_broadcast        ;
    wire                 [   8: 0]      core4_csr_W_addr           ;
    wire                 [   6: 0]      core4_csr_A_addr           ;
    wire                 [   6: 0]      core4_csr_A_cnt            ;
    wire                                core4_csr_test_en          ;
    wire                                core4_csr_O_wen            ;
    wire                                core4_csr_W_load_done      ;
    wire                                core4_csr_cal_done         ;
    wire                                core4_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core4_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core4_csr_C2C_A1_recv      ;
    wire                                core4_csr_C2C_A0_input_sel ;
    wire                                core4_csr_C2C_A1_input_sel ;
    wire                                core4_csr_C2C_A0_recv_en   ;
    wire                                core4_csr_C2C_A1_recv_en   ;
    wire                                core4_csr_C2C_A0_bypass    ;
    wire                                core4_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core4_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core4_csr_C2C_A1_send      ;

    assign                              core4_csr_W_addr            = core4_csr_cfg_i[8:0] ;
    assign                              core4_csr_A_addr            = core4_csr_cfg_i[15:9];
    assign                              core4_csr_A_cnt             = core4_csr_cfg_i[22:16];
    assign                              core4_csr_precision         = core4_csr_cfg_i[23]  ;
    assign                              core4_csr_broadcast         = core4_csr_cfg_i[24]  ;
    assign                              core4_csr_test_en           = core4_csr_cfg_i[25]  ;
    assign                              core4_csr_O_wen             = core4_csr_cfg_i[26]  ;

    assign                              core4_csr_C2C_A1_encode_en  = core4_csr_cfg_i[27]  ;
    assign                              core4_csr_C2C_A0_recv       = core4_csr_cfg_i[29:28];
    assign                              core4_csr_C2C_A1_recv       = core4_csr_cfg_i[31:30];
    assign                              core4_csr_C2C_A0_input_sel  = core4_csr_cfg_i[32]  ;
    assign                              core4_csr_C2C_A1_input_sel  = core4_csr_cfg_i[33]  ;
    assign                              core4_csr_C2C_A0_recv_en    = core4_csr_cfg_i[34]  ;
    assign                              core4_csr_C2C_A1_recv_en    = core4_csr_cfg_i[35]  ;
    assign                              core4_csr_C2C_A0_bypass     = core4_csr_cfg_i[36]  ;
    assign                              core4_csr_C2C_A1_bypass     = core4_csr_cfg_i[37]  ;
    assign                              core4_csr_C2C_A0_send       = core4_csr_cfg_i[39:38];
    assign                              core4_csr_C2C_A1_send       = core4_csr_cfg_i[41:40];

    assign                              core4_csr_flag_o[0]         = core4_csr_cal_done   ;
    assign                              core4_csr_flag_o[1]         = core4_csr_W_load_done;

    wire                 [  79: 0]      core4_C2C_A0_send_E        ;
    wire                 [  79: 0]      core4_C2C_A1_send_E        ;
    wire                 [  79: 0]      core4_C2C_A0_send_S        ;
    wire                 [  79: 0]      core4_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_4(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core4_csr_precision       ),
    .csr_broadcast_i                    (core4_csr_broadcast       ),
    .csr_W_addr_i                       (core4_csr_W_addr          ),
    .csr_A_addr_i                       (core4_csr_A_addr          ),
    .csr_A_cnt_i                        (core4_csr_A_cnt           ),
    .csr_W_load_en_i                    (core4_csr_en_i[0]         ),
    .csr_cal_en_i                       (core4_csr_en_i[1]         ),
    .csr_test_en_i                      (core4_csr_test_en         ),
    .csr_O_wen_i                        (core4_csr_O_wen           ),
    .csr_W_load_done_o                  (core4_csr_W_load_done     ),
    .csr_cal_done_o                     (core4_csr_cal_done        ),
    .axi_req_i                          (core4_axi_req_i           ),
    .axi_we_i                           (core4_axi_we_i            ),
    .axi_addr_i                         (core4_axi_addr_i          ),
    .axi_wdata_i                        (core4_axi_wdata_i         ),
    .axi_rdata_o                        (core4_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core4_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core4_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core4_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core4_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core4_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core4_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core4_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core4_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core4_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core4_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core4_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (80'd0                     ),
    .C2C_A1_recv_W_i                    (80'd0                     ),
    .C2C_A0_recv_N_i                    (core0_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core0_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (core4_C2C_A0_send_E       ),
    .C2C_A1_send_E_o                    (core4_C2C_A1_send_E       ),
    .C2C_A0_send_S_o                    (core4_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core4_C2C_A1_send_S       ) 
);

//////////////////////////////// Core5(1,1) ////////////////////////////////
    wire                                core5_csr_precision        ;
    wire                                core5_csr_broadcast        ;
    wire                 [   8: 0]      core5_csr_W_addr           ;
    wire                 [   6: 0]      core5_csr_A_addr           ;
    wire                 [   6: 0]      core5_csr_A_cnt            ;
    wire                                core5_csr_test_en          ;
    wire                                core5_csr_O_wen            ;
    wire                                core5_csr_W_load_done      ;
    wire                                core5_csr_cal_done         ;
    wire                                core5_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core5_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core5_csr_C2C_A1_recv      ;
    wire                                core5_csr_C2C_A0_input_sel ;
    wire                                core5_csr_C2C_A1_input_sel ;
    wire                                core5_csr_C2C_A0_recv_en   ;
    wire                                core5_csr_C2C_A1_recv_en   ;
    wire                                core5_csr_C2C_A0_bypass    ;
    wire                                core5_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core5_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core5_csr_C2C_A1_send      ;

    assign                              core5_csr_W_addr            = core5_csr_cfg_i[8:0] ;
    assign                              core5_csr_A_addr            = core5_csr_cfg_i[15:9];
    assign                              core5_csr_A_cnt             = core5_csr_cfg_i[22:16];
    assign                              core5_csr_precision         = core5_csr_cfg_i[23]  ;
    assign                              core5_csr_broadcast         = core5_csr_cfg_i[24]  ;
    assign                              core5_csr_test_en           = core5_csr_cfg_i[25]  ;
    assign                              core5_csr_O_wen             = core5_csr_cfg_i[26]  ;

    assign                              core5_csr_C2C_A1_encode_en  = core5_csr_cfg_i[27]  ;
    assign                              core5_csr_C2C_A0_recv       = core5_csr_cfg_i[29:28];
    assign                              core5_csr_C2C_A1_recv       = core5_csr_cfg_i[31:30];
    assign                              core5_csr_C2C_A0_input_sel  = core5_csr_cfg_i[32]  ;
    assign                              core5_csr_C2C_A1_input_sel  = core5_csr_cfg_i[33]  ;
    assign                              core5_csr_C2C_A0_recv_en    = core5_csr_cfg_i[34]  ;
    assign                              core5_csr_C2C_A1_recv_en    = core5_csr_cfg_i[35]  ;
    assign                              core5_csr_C2C_A0_bypass     = core5_csr_cfg_i[36]  ;
    assign                              core5_csr_C2C_A1_bypass     = core5_csr_cfg_i[37]  ;
    assign                              core5_csr_C2C_A0_send       = core5_csr_cfg_i[39:38];
    assign                              core5_csr_C2C_A1_send       = core5_csr_cfg_i[41:40];

    assign                              core5_csr_flag_o[0]         = core5_csr_cal_done   ;
    assign                              core5_csr_flag_o[1]         = core5_csr_W_load_done;

    wire                 [  79: 0]      core5_C2C_A0_send_E        ;
    wire                 [  79: 0]      core5_C2C_A1_send_E        ;
    wire                 [  79: 0]      core5_C2C_A0_send_S        ;
    wire                 [  79: 0]      core5_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_5(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core5_csr_precision       ),
    .csr_broadcast_i                    (core5_csr_broadcast       ),
    .csr_W_addr_i                       (core5_csr_W_addr          ),
    .csr_A_addr_i                       (core5_csr_A_addr          ),
    .csr_A_cnt_i                        (core5_csr_A_cnt           ),
    .csr_W_load_en_i                    (core5_csr_en_i[0]         ),
    .csr_cal_en_i                       (core5_csr_en_i[1]         ),
    .csr_test_en_i                      (core5_csr_test_en         ),
    .csr_O_wen_i                        (core5_csr_O_wen           ),
    .csr_W_load_done_o                  (core5_csr_W_load_done     ),
    .csr_cal_done_o                     (core5_csr_cal_done        ),
    .axi_req_i                          (core5_axi_req_i           ),
    .axi_we_i                           (core5_axi_we_i            ),
    .axi_addr_i                         (core5_axi_addr_i          ),
    .axi_wdata_i                        (core5_axi_wdata_i         ),
    .axi_rdata_o                        (core5_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core5_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core5_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core5_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core5_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core5_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core5_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core5_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core5_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core5_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core5_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core5_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (core4_C2C_A0_send_E       ),
    .C2C_A1_recv_W_i                    (core4_C2C_A1_send_E       ),
    .C2C_A0_recv_N_i                    (core1_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core1_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (core5_C2C_A0_send_E       ),
    .C2C_A1_send_E_o                    (core5_C2C_A1_send_E       ),
    .C2C_A0_send_S_o                    (core5_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core5_C2C_A1_send_S       ) 
);

//////////////////////////////// Core6(1,2) ////////////////////////////////
    wire                                core6_csr_precision        ;
    wire                                core6_csr_broadcast        ;
    wire                 [   8: 0]      core6_csr_W_addr           ;
    wire                 [   6: 0]      core6_csr_A_addr           ;
    wire                 [   6: 0]      core6_csr_A_cnt            ;
    wire                                core6_csr_test_en          ;
    wire                                core6_csr_O_wen            ;
    wire                                core6_csr_W_load_done      ;
    wire                                core6_csr_cal_done         ;
    wire                                core6_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core6_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core6_csr_C2C_A1_recv      ;
    wire                                core6_csr_C2C_A0_input_sel ;
    wire                                core6_csr_C2C_A1_input_sel ;
    wire                                core6_csr_C2C_A0_recv_en   ;
    wire                                core6_csr_C2C_A1_recv_en   ;
    wire                                core6_csr_C2C_A0_bypass    ;
    wire                                core6_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core6_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core6_csr_C2C_A1_send      ;

    assign                              core6_csr_W_addr            = core6_csr_cfg_i[8:0] ;
    assign                              core6_csr_A_addr            = core6_csr_cfg_i[15:9];
    assign                              core6_csr_A_cnt             = core6_csr_cfg_i[22:16];
    assign                              core6_csr_precision         = core6_csr_cfg_i[23]  ;
    assign                              core6_csr_broadcast         = core6_csr_cfg_i[24]  ;
    assign                              core6_csr_test_en           = core6_csr_cfg_i[25]  ;
    assign                              core6_csr_O_wen             = core6_csr_cfg_i[26]  ;

    assign                              core6_csr_C2C_A1_encode_en  = core6_csr_cfg_i[27]  ;
    assign                              core6_csr_C2C_A0_recv       = core6_csr_cfg_i[29:28];
    assign                              core6_csr_C2C_A1_recv       = core6_csr_cfg_i[31:30];
    assign                              core6_csr_C2C_A0_input_sel  = core6_csr_cfg_i[32]  ;
    assign                              core6_csr_C2C_A1_input_sel  = core6_csr_cfg_i[33]  ;
    assign                              core6_csr_C2C_A0_recv_en    = core6_csr_cfg_i[34]  ;
    assign                              core6_csr_C2C_A1_recv_en    = core6_csr_cfg_i[35]  ;
    assign                              core6_csr_C2C_A0_bypass     = core6_csr_cfg_i[36]  ;
    assign                              core6_csr_C2C_A1_bypass     = core6_csr_cfg_i[37]  ;
    assign                              core6_csr_C2C_A0_send       = core6_csr_cfg_i[39:38];
    assign                              core6_csr_C2C_A1_send       = core6_csr_cfg_i[41:40];

    assign                              core6_csr_flag_o[0]         = core6_csr_cal_done   ;
    assign                              core6_csr_flag_o[1]         = core6_csr_W_load_done;

    wire                 [  79: 0]      core6_C2C_A0_send_E        ;
    wire                 [  79: 0]      core6_C2C_A1_send_E        ;
    wire                 [  79: 0]      core6_C2C_A0_send_S        ;
    wire                 [  79: 0]      core6_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_6(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core6_csr_precision       ),
    .csr_broadcast_i                    (core6_csr_broadcast       ),
    .csr_W_addr_i                       (core6_csr_W_addr          ),
    .csr_A_addr_i                       (core6_csr_A_addr          ),
    .csr_A_cnt_i                        (core6_csr_A_cnt           ),
    .csr_W_load_en_i                    (core6_csr_en_i[0]         ),
    .csr_cal_en_i                       (core6_csr_en_i[1]         ),
    .csr_test_en_i                      (core6_csr_test_en         ),
    .csr_O_wen_i                        (core6_csr_O_wen           ),
    .csr_W_load_done_o                  (core6_csr_W_load_done     ),
    .csr_cal_done_o                     (core6_csr_cal_done        ),
    .axi_req_i                          (core6_axi_req_i           ),
    .axi_we_i                           (core6_axi_we_i            ),
    .axi_addr_i                         (core6_axi_addr_i          ),
    .axi_wdata_i                        (core6_axi_wdata_i         ),
    .axi_rdata_o                        (core6_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core6_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core6_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core6_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core6_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core6_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core6_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core6_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core6_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core6_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core6_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core6_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (core5_C2C_A0_send_E       ),
    .C2C_A1_recv_W_i                    (core5_C2C_A1_send_E       ),
    .C2C_A0_recv_N_i                    (core2_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core2_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (core6_C2C_A0_send_E       ),
    .C2C_A1_send_E_o                    (core6_C2C_A1_send_E       ),
    .C2C_A0_send_S_o                    (core6_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core6_C2C_A1_send_S       ) 
);

//////////////////////////////// Core7(1,3) ////////////////////////////////
    wire                                core7_csr_precision        ;
    wire                                core7_csr_broadcast        ;
    wire                 [   8: 0]      core7_csr_W_addr           ;
    wire                 [   6: 0]      core7_csr_A_addr           ;
    wire                 [   6: 0]      core7_csr_A_cnt            ;
    wire                                core7_csr_test_en          ;
    wire                                core7_csr_O_wen            ;
    wire                                core7_csr_W_load_done      ;
    wire                                core7_csr_cal_done         ;
    wire                                core7_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core7_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core7_csr_C2C_A1_recv      ;
    wire                                core7_csr_C2C_A0_input_sel ;
    wire                                core7_csr_C2C_A1_input_sel ;
    wire                                core7_csr_C2C_A0_recv_en   ;
    wire                                core7_csr_C2C_A1_recv_en   ;
    wire                                core7_csr_C2C_A0_bypass    ;
    wire                                core7_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core7_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core7_csr_C2C_A1_send      ;

    assign                              core7_csr_W_addr            = core7_csr_cfg_i[8:0] ;
    assign                              core7_csr_A_addr            = core7_csr_cfg_i[15:9];
    assign                              core7_csr_A_cnt             = core7_csr_cfg_i[22:16];
    assign                              core7_csr_precision         = core7_csr_cfg_i[23]  ;
    assign                              core7_csr_broadcast         = core7_csr_cfg_i[24]  ;
    assign                              core7_csr_test_en           = core7_csr_cfg_i[25]  ;
    assign                              core7_csr_O_wen             = core7_csr_cfg_i[26]  ;

    assign                              core7_csr_C2C_A1_encode_en  = core7_csr_cfg_i[27]  ;
    assign                              core7_csr_C2C_A0_recv       = core7_csr_cfg_i[29:28];
    assign                              core7_csr_C2C_A1_recv       = core7_csr_cfg_i[31:30];
    assign                              core7_csr_C2C_A0_input_sel  = core7_csr_cfg_i[32]  ;
    assign                              core7_csr_C2C_A1_input_sel  = core7_csr_cfg_i[33]  ;
    assign                              core7_csr_C2C_A0_recv_en    = core7_csr_cfg_i[34]  ;
    assign                              core7_csr_C2C_A1_recv_en    = core7_csr_cfg_i[35]  ;
    assign                              core7_csr_C2C_A0_bypass     = core7_csr_cfg_i[36]  ;
    assign                              core7_csr_C2C_A1_bypass     = core7_csr_cfg_i[37]  ;
    assign                              core7_csr_C2C_A0_send       = core7_csr_cfg_i[39:38];
    assign                              core7_csr_C2C_A1_send       = core7_csr_cfg_i[41:40];

    assign                              core7_csr_flag_o[0]         = core7_csr_cal_done   ;
    assign                              core7_csr_flag_o[1]         = core7_csr_W_load_done;

    wire                 [  79: 0]      core7_C2C_A0_send_S        ;
    wire                 [  79: 0]      core7_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_7(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core7_csr_precision       ),
    .csr_broadcast_i                    (core7_csr_broadcast       ),
    .csr_W_addr_i                       (core7_csr_W_addr          ),
    .csr_A_addr_i                       (core7_csr_A_addr          ),
    .csr_A_cnt_i                        (core7_csr_A_cnt           ),
    .csr_W_load_en_i                    (core7_csr_en_i[0]         ),
    .csr_cal_en_i                       (core7_csr_en_i[1]         ),
    .csr_test_en_i                      (core7_csr_test_en         ),
    .csr_O_wen_i                        (core7_csr_O_wen           ),
    .csr_W_load_done_o                  (core7_csr_W_load_done     ),
    .csr_cal_done_o                     (core7_csr_cal_done        ),
    .axi_req_i                          (core7_axi_req_i           ),
    .axi_we_i                           (core7_axi_we_i            ),
    .axi_addr_i                         (core7_axi_addr_i          ),
    .axi_wdata_i                        (core7_axi_wdata_i         ),
    .axi_rdata_o                        (core7_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core7_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core7_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core7_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core7_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core7_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core7_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core7_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core7_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core7_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core7_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core7_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (core6_C2C_A0_send_E       ),
    .C2C_A1_recv_W_i                    (core6_C2C_A1_send_E       ),
    .C2C_A0_recv_N_i                    (core3_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core3_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (                          ),
    .C2C_A1_send_E_o                    (                          ),
    .C2C_A0_send_S_o                    (core7_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core7_C2C_A1_send_S       ) 
);

//////////////////////////////// Core8(2,0) ////////////////////////////////
    wire                                core8_csr_precision        ;
    wire                                core8_csr_broadcast        ;
    wire                 [   8: 0]      core8_csr_W_addr           ;
    wire                 [   6: 0]      core8_csr_A_addr           ;
    wire                 [   6: 0]      core8_csr_A_cnt            ;
    wire                                core8_csr_test_en          ;
    wire                                core8_csr_O_wen            ;
    wire                                core8_csr_W_load_done      ;
    wire                                core8_csr_cal_done         ;
    wire                                core8_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core8_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core8_csr_C2C_A1_recv      ;
    wire                                core8_csr_C2C_A0_input_sel ;
    wire                                core8_csr_C2C_A1_input_sel ;
    wire                                core8_csr_C2C_A0_recv_en   ;
    wire                                core8_csr_C2C_A1_recv_en   ;
    wire                                core8_csr_C2C_A0_bypass    ;
    wire                                core8_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core8_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core8_csr_C2C_A1_send      ;

    assign                              core8_csr_W_addr            = core8_csr_cfg_i[8:0] ;
    assign                              core8_csr_A_addr            = core8_csr_cfg_i[15:9];
    assign                              core8_csr_A_cnt             = core8_csr_cfg_i[22:16];
    assign                              core8_csr_precision         = core8_csr_cfg_i[23]  ;
    assign                              core8_csr_broadcast         = core8_csr_cfg_i[24]  ;
    assign                              core8_csr_test_en           = core8_csr_cfg_i[25]  ;
    assign                              core8_csr_O_wen             = core8_csr_cfg_i[26]  ;

    assign                              core8_csr_C2C_A1_encode_en  = core8_csr_cfg_i[27]  ;
    assign                              core8_csr_C2C_A0_recv       = core8_csr_cfg_i[29:28];
    assign                              core8_csr_C2C_A1_recv       = core8_csr_cfg_i[31:30];
    assign                              core8_csr_C2C_A0_input_sel  = core8_csr_cfg_i[32]  ;
    assign                              core8_csr_C2C_A1_input_sel  = core8_csr_cfg_i[33]  ;
    assign                              core8_csr_C2C_A0_recv_en    = core8_csr_cfg_i[34]  ;
    assign                              core8_csr_C2C_A1_recv_en    = core8_csr_cfg_i[35]  ;
    assign                              core8_csr_C2C_A0_bypass     = core8_csr_cfg_i[36]  ;
    assign                              core8_csr_C2C_A1_bypass     = core8_csr_cfg_i[37]  ;
    assign                              core8_csr_C2C_A0_send       = core8_csr_cfg_i[39:38];
    assign                              core8_csr_C2C_A1_send       = core8_csr_cfg_i[41:40];

    assign                              core8_csr_flag_o[0]         = core8_csr_cal_done   ;
    assign                              core8_csr_flag_o[1]         = core8_csr_W_load_done;

    wire                 [  79: 0]      core8_C2C_A0_send_E        ;
    wire                 [  79: 0]      core8_C2C_A1_send_E        ;
    wire                 [  79: 0]      core8_C2C_A0_send_S        ;
    wire                 [  79: 0]      core8_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_8(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core8_csr_precision       ),
    .csr_broadcast_i                    (core8_csr_broadcast       ),
    .csr_W_addr_i                       (core8_csr_W_addr          ),
    .csr_A_addr_i                       (core8_csr_A_addr          ),
    .csr_A_cnt_i                        (core8_csr_A_cnt           ),
    .csr_W_load_en_i                    (core8_csr_en_i[0]         ),
    .csr_cal_en_i                       (core8_csr_en_i[1]         ),
    .csr_test_en_i                      (core8_csr_test_en         ),
    .csr_O_wen_i                        (core8_csr_O_wen           ),
    .csr_W_load_done_o                  (core8_csr_W_load_done     ),
    .csr_cal_done_o                     (core8_csr_cal_done        ),
    .axi_req_i                          (core8_axi_req_i           ),
    .axi_we_i                           (core8_axi_we_i            ),
    .axi_addr_i                         (core8_axi_addr_i          ),
    .axi_wdata_i                        (core8_axi_wdata_i         ),
    .axi_rdata_o                        (core8_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core8_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core8_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core8_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core8_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core8_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core8_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core8_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core8_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core8_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core8_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core8_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (80'd0                     ),
    .C2C_A1_recv_W_i                    (80'd0                     ),
    .C2C_A0_recv_N_i                    (core4_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core4_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (core8_C2C_A0_send_E       ),
    .C2C_A1_send_E_o                    (core8_C2C_A1_send_E       ),
    .C2C_A0_send_S_o                    (core8_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core8_C2C_A1_send_S       ) 
);

//////////////////////////////// Core9(2,1) ////////////////////////////////
    wire                                core9_csr_precision        ;
    wire                                core9_csr_broadcast        ;
    wire                 [   8: 0]      core9_csr_W_addr           ;
    wire                 [   6: 0]      core9_csr_A_addr           ;
    wire                 [   6: 0]      core9_csr_A_cnt            ;
    wire                                core9_csr_test_en          ;
    wire                                core9_csr_O_wen            ;
    wire                                core9_csr_W_load_done      ;
    wire                                core9_csr_cal_done         ;
    wire                                core9_csr_C2C_A1_encode_en ;
    wire                 [   1: 0]      core9_csr_C2C_A0_recv      ;
    wire                 [   1: 0]      core9_csr_C2C_A1_recv      ;
    wire                                core9_csr_C2C_A0_input_sel ;
    wire                                core9_csr_C2C_A1_input_sel ;
    wire                                core9_csr_C2C_A0_recv_en   ;
    wire                                core9_csr_C2C_A1_recv_en   ;
    wire                                core9_csr_C2C_A0_bypass    ;
    wire                                core9_csr_C2C_A1_bypass    ;
    wire                 [   1: 0]      core9_csr_C2C_A0_send      ;
    wire                 [   1: 0]      core9_csr_C2C_A1_send      ;

    assign                              core9_csr_W_addr            = core9_csr_cfg_i[8:0] ;
    assign                              core9_csr_A_addr            = core9_csr_cfg_i[15:9];
    assign                              core9_csr_A_cnt             = core9_csr_cfg_i[22:16];
    assign                              core9_csr_precision         = core9_csr_cfg_i[23]  ;
    assign                              core9_csr_broadcast         = core9_csr_cfg_i[24]  ;
    assign                              core9_csr_test_en           = core9_csr_cfg_i[25]  ;
    assign                              core9_csr_O_wen             = core9_csr_cfg_i[26]  ;

    assign                              core9_csr_C2C_A1_encode_en  = core9_csr_cfg_i[27]  ;
    assign                              core9_csr_C2C_A0_recv       = core9_csr_cfg_i[29:28];
    assign                              core9_csr_C2C_A1_recv       = core9_csr_cfg_i[31:30];
    assign                              core9_csr_C2C_A0_input_sel  = core9_csr_cfg_i[32]  ;
    assign                              core9_csr_C2C_A1_input_sel  = core9_csr_cfg_i[33]  ;
    assign                              core9_csr_C2C_A0_recv_en    = core9_csr_cfg_i[34]  ;
    assign                              core9_csr_C2C_A1_recv_en    = core9_csr_cfg_i[35]  ;
    assign                              core9_csr_C2C_A0_bypass     = core9_csr_cfg_i[36]  ;
    assign                              core9_csr_C2C_A1_bypass     = core9_csr_cfg_i[37]  ;
    assign                              core9_csr_C2C_A0_send       = core9_csr_cfg_i[39:38];
    assign                              core9_csr_C2C_A1_send       = core9_csr_cfg_i[41:40];

    assign                              core9_csr_flag_o[0]         = core9_csr_cal_done   ;
    assign                              core9_csr_flag_o[1]         = core9_csr_W_load_done;

    wire                 [  79: 0]      core9_C2C_A0_send_E        ;
    wire                 [  79: 0]      core9_C2C_A1_send_E        ;
    wire                 [  79: 0]      core9_C2C_A0_send_S        ;
    wire                 [  79: 0]      core9_C2C_A1_send_S        ;
cache_PE_core u_cache_PE_core_9(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core9_csr_precision       ),
    .csr_broadcast_i                    (core9_csr_broadcast       ),
    .csr_W_addr_i                       (core9_csr_W_addr          ),
    .csr_A_addr_i                       (core9_csr_A_addr          ),
    .csr_A_cnt_i                        (core9_csr_A_cnt           ),
    .csr_W_load_en_i                    (core9_csr_en_i[0]         ),
    .csr_cal_en_i                       (core9_csr_en_i[1]         ),
    .csr_test_en_i                      (core9_csr_test_en         ),
    .csr_O_wen_i                        (core9_csr_O_wen           ),
    .csr_W_load_done_o                  (core9_csr_W_load_done     ),
    .csr_cal_done_o                     (core9_csr_cal_done        ),
    .axi_req_i                          (core9_axi_req_i           ),
    .axi_we_i                           (core9_axi_we_i            ),
    .axi_addr_i                         (core9_axi_addr_i          ),
    .axi_wdata_i                        (core9_axi_wdata_i         ),
    .axi_rdata_o                        (core9_axi_rdata_o         ),
    .csr_C2C_A1_encode_en_i             (core9_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core9_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core9_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core9_csr_C2C_A0_recv_en  ),
    .csr_C2C_A1_recv_en_i               (core9_csr_C2C_A1_recv_en  ),
    .csr_C2C_A0_bypass_i                (core9_csr_C2C_A0_bypass   ),
    .csr_C2C_A1_bypass_i                (core9_csr_C2C_A1_bypass   ),
    .csr_C2C_A0_send_i                  (core9_csr_C2C_A0_send     ),
    .csr_C2C_A1_send_i                  (core9_csr_C2C_A1_send     ),
    .csr_C2C_A0_recv_i                  (core9_csr_C2C_A0_recv     ),
    .csr_C2C_A1_recv_i                  (core9_csr_C2C_A1_recv     ),
    .C2C_A0_recv_W_i                    (core8_C2C_A0_send_E       ),
    .C2C_A1_recv_W_i                    (core8_C2C_A1_send_E       ),
    .C2C_A0_recv_N_i                    (core5_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core5_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (core9_C2C_A0_send_E       ),
    .C2C_A1_send_E_o                    (core9_C2C_A1_send_E       ),
    .C2C_A0_send_S_o                    (core9_C2C_A0_send_S       ),
    .C2C_A1_send_S_o                    (core9_C2C_A1_send_S       ) 
);

//////////////////////////////// Core10(2,2) ///////////////////////////////
    wire                                core10_csr_precision       ;
    wire                                core10_csr_broadcast       ;
    wire                 [   8: 0]      core10_csr_W_addr          ;
    wire                 [   6: 0]      core10_csr_A_addr          ;
    wire                 [   6: 0]      core10_csr_A_cnt           ;
    wire                                core10_csr_test_en         ;
    wire                                core10_csr_O_wen           ;
    wire                                core10_csr_W_load_done     ;
    wire                                core10_csr_cal_done        ;
    wire                                core10_csr_C2C_A1_encode_en;
    wire                 [   1: 0]      core10_csr_C2C_A0_recv     ;
    wire                 [   1: 0]      core10_csr_C2C_A1_recv     ;
    wire                                core10_csr_C2C_A0_input_sel;
    wire                                core10_csr_C2C_A1_input_sel;
    wire                                core10_csr_C2C_A0_recv_en  ;
    wire                                core10_csr_C2C_A1_recv_en  ;
    wire                                core10_csr_C2C_A0_bypass   ;
    wire                                core10_csr_C2C_A1_bypass   ;
    wire                 [   1: 0]      core10_csr_C2C_A0_send     ;
    wire                 [   1: 0]      core10_csr_C2C_A1_send     ;

    assign                              core10_csr_W_addr           = core10_csr_cfg_i[8:0] ;
    assign                              core10_csr_A_addr           = core10_csr_cfg_i[15:9];
    assign                              core10_csr_A_cnt            = core10_csr_cfg_i[22:16];
    assign                              core10_csr_precision        = core10_csr_cfg_i[23]  ;
    assign                              core10_csr_broadcast        = core10_csr_cfg_i[24]  ;
    assign                              core10_csr_test_en          = core10_csr_cfg_i[25]  ;
    assign                              core10_csr_O_wen            = core10_csr_cfg_i[26]  ;
    
    assign                              core10_csr_C2C_A1_encode_en = core10_csr_cfg_i[27]  ;
    assign                              core10_csr_C2C_A0_recv      = core10_csr_cfg_i[29:28];
    assign                              core10_csr_C2C_A1_recv      = core10_csr_cfg_i[31:30];
    assign                              core10_csr_C2C_A0_input_sel = core10_csr_cfg_i[32]  ;
    assign                              core10_csr_C2C_A1_input_sel = core10_csr_cfg_i[33]  ;
    assign                              core10_csr_C2C_A0_recv_en   = core10_csr_cfg_i[34]  ;
    assign                              core10_csr_C2C_A1_recv_en   = core10_csr_cfg_i[35]  ;
    assign                              core10_csr_C2C_A0_bypass    = core10_csr_cfg_i[36]  ;
    assign                              core10_csr_C2C_A1_bypass    = core10_csr_cfg_i[37]  ;
    assign                              core10_csr_C2C_A0_send      = core10_csr_cfg_i[39:38];
    assign                              core10_csr_C2C_A1_send      = core10_csr_cfg_i[41:40];

    assign                              core10_csr_flag_o[0]        = core10_csr_cal_done  ;
    assign                              core10_csr_flag_o[1]        = core10_csr_W_load_done;

    wire                 [  79: 0]      core10_C2C_A0_send_E       ;
    wire                 [  79: 0]      core10_C2C_A1_send_E       ;
    wire                 [  79: 0]      core10_C2C_A0_send_S       ;
    wire                 [  79: 0]      core10_C2C_A1_send_S       ;
cache_PE_core u_cache_PE_core_10(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core10_csr_precision      ),
    .csr_broadcast_i                    (core10_csr_broadcast      ),
    .csr_W_addr_i                       (core10_csr_W_addr         ),
    .csr_A_addr_i                       (core10_csr_A_addr         ),
    .csr_A_cnt_i                        (core10_csr_A_cnt          ),
    .csr_W_load_en_i                    (core10_csr_en_i[0]        ),
    .csr_cal_en_i                       (core10_csr_en_i[1]        ),
    .csr_test_en_i                      (core10_csr_test_en        ),
    .csr_O_wen_i                        (core10_csr_O_wen          ),
    .csr_W_load_done_o                  (core10_csr_W_load_done    ),
    .csr_cal_done_o                     (core10_csr_cal_done       ),
    .axi_req_i                          (core10_axi_req_i          ),
    .axi_we_i                           (core10_axi_we_i           ),
    .axi_addr_i                         (core10_axi_addr_i         ),
    .axi_wdata_i                        (core10_axi_wdata_i        ),
    .axi_rdata_o                        (core10_axi_rdata_o        ),
    .csr_C2C_A1_encode_en_i             (core10_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core10_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core10_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core10_csr_C2C_A0_recv_en ),
    .csr_C2C_A1_recv_en_i               (core10_csr_C2C_A1_recv_en ),
    .csr_C2C_A0_bypass_i                (core10_csr_C2C_A0_bypass  ),
    .csr_C2C_A1_bypass_i                (core10_csr_C2C_A1_bypass  ),
    .csr_C2C_A0_send_i                  (core10_csr_C2C_A0_send    ),
    .csr_C2C_A1_send_i                  (core10_csr_C2C_A1_send    ),
    .csr_C2C_A0_recv_i                  (core10_csr_C2C_A0_recv    ),
    .csr_C2C_A1_recv_i                  (core10_csr_C2C_A1_recv    ),
    .C2C_A0_recv_W_i                    (core9_C2C_A0_send_E       ),
    .C2C_A1_recv_W_i                    (core9_C2C_A1_send_E       ),
    .C2C_A0_recv_N_i                    (core6_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core6_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (core10_C2C_A0_send_E      ),
    .C2C_A1_send_E_o                    (core10_C2C_A1_send_E      ),
    .C2C_A0_send_S_o                    (core10_C2C_A0_send_S      ),
    .C2C_A1_send_S_o                    (core10_C2C_A1_send_S      ) 
);

//////////////////////////////// Core11(2,3) ///////////////////////////////
    wire                                core11_csr_precision       ;
    wire                                core11_csr_broadcast       ;
    wire                 [   8: 0]      core11_csr_W_addr          ;
    wire                 [   6: 0]      core11_csr_A_addr          ;
    wire                 [   6: 0]      core11_csr_A_cnt           ;
    wire                                core11_csr_test_en         ;
    wire                                core11_csr_O_wen           ;
    wire                                core11_csr_W_load_done     ;
    wire                                core11_csr_cal_done        ;
    wire                                core11_csr_C2C_A1_encode_en;
    wire                 [   1: 0]      core11_csr_C2C_A0_recv     ;
    wire                 [   1: 0]      core11_csr_C2C_A1_recv     ;
    wire                                core11_csr_C2C_A0_input_sel;
    wire                                core11_csr_C2C_A1_input_sel;
    wire                                core11_csr_C2C_A0_recv_en  ;
    wire                                core11_csr_C2C_A1_recv_en  ;
    wire                                core11_csr_C2C_A0_bypass   ;
    wire                                core11_csr_C2C_A1_bypass   ;
    wire                 [   1: 0]      core11_csr_C2C_A0_send     ;
    wire                 [   1: 0]      core11_csr_C2C_A1_send     ;

    assign                              core11_csr_W_addr           = core11_csr_cfg_i[8:0] ;
    assign                              core11_csr_A_addr           = core11_csr_cfg_i[15:9];
    assign                              core11_csr_A_cnt            = core11_csr_cfg_i[22:16];
    assign                              core11_csr_precision        = core11_csr_cfg_i[23]  ;
    assign                              core11_csr_broadcast        = core11_csr_cfg_i[24]  ;
    assign                              core11_csr_test_en          = core11_csr_cfg_i[25]  ;
    assign                              core11_csr_O_wen            = core11_csr_cfg_i[26]  ;
    
    assign                              core11_csr_C2C_A1_encode_en = core11_csr_cfg_i[27]  ;
    assign                              core11_csr_C2C_A0_recv      = core11_csr_cfg_i[29:28];
    assign                              core11_csr_C2C_A1_recv      = core11_csr_cfg_i[31:30];
    assign                              core11_csr_C2C_A0_input_sel = core11_csr_cfg_i[32]  ;
    assign                              core11_csr_C2C_A1_input_sel = core11_csr_cfg_i[33]  ;
    assign                              core11_csr_C2C_A0_recv_en   = core11_csr_cfg_i[34]  ;
    assign                              core11_csr_C2C_A1_recv_en   = core11_csr_cfg_i[35]  ;
    assign                              core11_csr_C2C_A0_bypass    = core11_csr_cfg_i[36]  ;
    assign                              core11_csr_C2C_A1_bypass    = core11_csr_cfg_i[37]  ;
    assign                              core11_csr_C2C_A0_send      = core11_csr_cfg_i[39:38];
    assign                              core11_csr_C2C_A1_send      = core11_csr_cfg_i[41:40];

    assign                              core11_csr_flag_o[0]        = core11_csr_cal_done  ;
    assign                              core11_csr_flag_o[1]        = core11_csr_W_load_done;

    wire                 [  79: 0]      core11_C2C_A0_send_S       ;
    wire                 [  79: 0]      core11_C2C_A1_send_S       ;
cache_PE_core u_cache_PE_core_11(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core11_csr_precision      ),
    .csr_broadcast_i                    (core11_csr_broadcast      ),
    .csr_W_addr_i                       (core11_csr_W_addr         ),
    .csr_A_addr_i                       (core11_csr_A_addr         ),
    .csr_A_cnt_i                        (core11_csr_A_cnt          ),
    .csr_W_load_en_i                    (core11_csr_en_i[0]        ),
    .csr_cal_en_i                       (core11_csr_en_i[1]        ),
    .csr_test_en_i                      (core11_csr_test_en        ),
    .csr_O_wen_i                        (core11_csr_O_wen          ),
    .csr_W_load_done_o                  (core11_csr_W_load_done    ),
    .csr_cal_done_o                     (core11_csr_cal_done       ),
    .axi_req_i                          (core11_axi_req_i          ),
    .axi_we_i                           (core11_axi_we_i           ),
    .axi_addr_i                         (core11_axi_addr_i         ),
    .axi_wdata_i                        (core11_axi_wdata_i        ),
    .axi_rdata_o                        (core11_axi_rdata_o        ),
    .csr_C2C_A1_encode_en_i             (core11_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core11_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core11_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core11_csr_C2C_A0_recv_en ),
    .csr_C2C_A1_recv_en_i               (core11_csr_C2C_A1_recv_en ),
    .csr_C2C_A0_bypass_i                (core11_csr_C2C_A0_bypass  ),
    .csr_C2C_A1_bypass_i                (core11_csr_C2C_A1_bypass  ),
    .csr_C2C_A0_send_i                  (core11_csr_C2C_A0_send    ),
    .csr_C2C_A1_send_i                  (core11_csr_C2C_A1_send    ),
    .csr_C2C_A0_recv_i                  (core11_csr_C2C_A0_recv    ),
    .csr_C2C_A1_recv_i                  (core11_csr_C2C_A1_recv    ),
    .C2C_A0_recv_W_i                    (core10_C2C_A0_send_E      ),
    .C2C_A1_recv_W_i                    (core10_C2C_A1_send_E      ),
    .C2C_A0_recv_N_i                    (core7_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core7_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (                          ),
    .C2C_A1_send_E_o                    (                          ),
    .C2C_A0_send_S_o                    (core11_C2C_A0_send_S      ),
    .C2C_A1_send_S_o                    (core11_C2C_A1_send_S      ) 
);

//////////////////////////////// Core12(3,0) ///////////////////////////////
    wire                                core12_csr_precision       ;
    wire                                core12_csr_broadcast       ;
    wire                 [   8: 0]      core12_csr_W_addr          ;
    wire                 [   6: 0]      core12_csr_A_addr          ;
    wire                 [   6: 0]      core12_csr_A_cnt           ;
    wire                                core12_csr_test_en         ;
    wire                                core12_csr_O_wen           ;
    wire                                core12_csr_W_load_done     ;
    wire                                core12_csr_cal_done        ;
    wire                                core12_csr_C2C_A1_encode_en;
    wire                 [   1: 0]      core12_csr_C2C_A0_recv     ;
    wire                 [   1: 0]      core12_csr_C2C_A1_recv     ;
    wire                                core12_csr_C2C_A0_input_sel;
    wire                                core12_csr_C2C_A1_input_sel;
    wire                                core12_csr_C2C_A0_recv_en  ;
    wire                                core12_csr_C2C_A1_recv_en  ;
    wire                                core12_csr_C2C_A0_bypass   ;
    wire                                core12_csr_C2C_A1_bypass   ;
    wire                 [   1: 0]      core12_csr_C2C_A0_send     ;
    wire                 [   1: 0]      core12_csr_C2C_A1_send     ;

    assign                              core12_csr_W_addr           = core12_csr_cfg_i[8:0] ;
    assign                              core12_csr_A_addr           = core12_csr_cfg_i[15:9];
    assign                              core12_csr_A_cnt            = core12_csr_cfg_i[22:16];
    assign                              core12_csr_precision        = core12_csr_cfg_i[23]  ;
    assign                              core12_csr_broadcast        = core12_csr_cfg_i[24]  ;
    assign                              core12_csr_test_en          = core12_csr_cfg_i[25]  ;
    assign                              core12_csr_O_wen            = core12_csr_cfg_i[26]  ;
    
    assign                              core12_csr_C2C_A1_encode_en = core12_csr_cfg_i[27]  ;
    assign                              core12_csr_C2C_A0_recv      = core12_csr_cfg_i[29:28];
    assign                              core12_csr_C2C_A1_recv      = core12_csr_cfg_i[31:30];
    assign                              core12_csr_C2C_A0_input_sel = core12_csr_cfg_i[32]  ;
    assign                              core12_csr_C2C_A1_input_sel = core12_csr_cfg_i[33]  ;
    assign                              core12_csr_C2C_A0_recv_en   = core12_csr_cfg_i[34]  ;
    assign                              core12_csr_C2C_A1_recv_en   = core12_csr_cfg_i[35]  ;
    assign                              core12_csr_C2C_A0_bypass    = core12_csr_cfg_i[36]  ;
    assign                              core12_csr_C2C_A1_bypass    = core12_csr_cfg_i[37]  ;
    assign                              core12_csr_C2C_A0_send      = core12_csr_cfg_i[39:38];
    assign                              core12_csr_C2C_A1_send      = core12_csr_cfg_i[41:40];

    assign                              core12_csr_flag_o[0]        = core12_csr_cal_done  ;
    assign                              core12_csr_flag_o[1]        = core12_csr_W_load_done;

    wire                 [  79: 0]      core12_C2C_A0_send_E       ;
    wire                 [  79: 0]      core12_C2C_A1_send_E       ;
cache_PE_core u_cache_PE_core_12(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core12_csr_precision      ),
    .csr_broadcast_i                    (core12_csr_broadcast      ),
    .csr_W_addr_i                       (core12_csr_W_addr         ),
    .csr_A_addr_i                       (core12_csr_A_addr         ),
    .csr_A_cnt_i                        (core12_csr_A_cnt          ),
    .csr_W_load_en_i                    (core12_csr_en_i[0]        ),
    .csr_cal_en_i                       (core12_csr_en_i[1]        ),
    .csr_test_en_i                      (core12_csr_test_en        ),
    .csr_O_wen_i                        (core12_csr_O_wen          ),
    .csr_W_load_done_o                  (core12_csr_W_load_done    ),
    .csr_cal_done_o                     (core12_csr_cal_done       ),
    .axi_req_i                          (core12_axi_req_i          ),
    .axi_we_i                           (core12_axi_we_i           ),
    .axi_addr_i                         (core12_axi_addr_i         ),
    .axi_wdata_i                        (core12_axi_wdata_i        ),
    .axi_rdata_o                        (core12_axi_rdata_o        ),
    .csr_C2C_A1_encode_en_i             (core12_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core12_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core12_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core12_csr_C2C_A0_recv_en ),
    .csr_C2C_A1_recv_en_i               (core12_csr_C2C_A1_recv_en ),
    .csr_C2C_A0_bypass_i                (core12_csr_C2C_A0_bypass  ),
    .csr_C2C_A1_bypass_i                (core12_csr_C2C_A1_bypass  ),
    .csr_C2C_A0_send_i                  (core12_csr_C2C_A0_send    ),
    .csr_C2C_A1_send_i                  (core12_csr_C2C_A1_send    ),
    .csr_C2C_A0_recv_i                  (core12_csr_C2C_A0_recv    ),
    .csr_C2C_A1_recv_i                  (core12_csr_C2C_A1_recv    ),
    .C2C_A0_recv_W_i                    (80'd0                     ),
    .C2C_A1_recv_W_i                    (80'd0                     ),
    .C2C_A0_recv_N_i                    (core8_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core8_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (core12_C2C_A0_send_E      ),
    .C2C_A1_send_E_o                    (core12_C2C_A1_send_E      ),
    .C2C_A0_send_S_o                    (                          ),
    .C2C_A1_send_S_o                    (                          ) 
);

//////////////////////////////// Core13(3,1) ///////////////////////////////
    wire                                core13_csr_precision       ;
    wire                                core13_csr_broadcast       ;
    wire                 [   8: 0]      core13_csr_W_addr          ;
    wire                 [   6: 0]      core13_csr_A_addr          ;
    wire                 [   6: 0]      core13_csr_A_cnt           ;
    wire                                core13_csr_test_en         ;
    wire                                core13_csr_O_wen           ;
    wire                                core13_csr_W_load_done     ;
    wire                                core13_csr_cal_done        ;
    wire                                core13_csr_C2C_A1_encode_en;
    wire                 [   1: 0]      core13_csr_C2C_A0_recv     ;
    wire                 [   1: 0]      core13_csr_C2C_A1_recv     ;
    wire                                core13_csr_C2C_A0_input_sel;
    wire                                core13_csr_C2C_A1_input_sel;
    wire                                core13_csr_C2C_A0_recv_en  ;
    wire                                core13_csr_C2C_A1_recv_en  ;
    wire                                core13_csr_C2C_A0_bypass   ;
    wire                                core13_csr_C2C_A1_bypass   ;
    wire                 [   1: 0]      core13_csr_C2C_A0_send     ;
    wire                 [   1: 0]      core13_csr_C2C_A1_send     ;

    assign                              core13_csr_W_addr           = core13_csr_cfg_i[8:0] ;
    assign                              core13_csr_A_addr           = core13_csr_cfg_i[15:9];
    assign                              core13_csr_A_cnt            = core13_csr_cfg_i[22:16];
    assign                              core13_csr_precision        = core13_csr_cfg_i[23]  ;
    assign                              core13_csr_broadcast        = core13_csr_cfg_i[24]  ;
    assign                              core13_csr_test_en          = core13_csr_cfg_i[25]  ;
    assign                              core13_csr_O_wen            = core13_csr_cfg_i[26]  ;
    
    assign                              core13_csr_C2C_A1_encode_en = core13_csr_cfg_i[27]  ;
    assign                              core13_csr_C2C_A0_recv      = core13_csr_cfg_i[29:28];
    assign                              core13_csr_C2C_A1_recv      = core13_csr_cfg_i[31:30];
    assign                              core13_csr_C2C_A0_input_sel = core13_csr_cfg_i[32]  ;
    assign                              core13_csr_C2C_A1_input_sel = core13_csr_cfg_i[33]  ;
    assign                              core13_csr_C2C_A0_recv_en   = core13_csr_cfg_i[34]  ;
    assign                              core13_csr_C2C_A1_recv_en   = core13_csr_cfg_i[35]  ;
    assign                              core13_csr_C2C_A0_bypass    = core13_csr_cfg_i[36]  ;
    assign                              core13_csr_C2C_A1_bypass    = core13_csr_cfg_i[37]  ;
    assign                              core13_csr_C2C_A0_send      = core13_csr_cfg_i[39:38];
    assign                              core13_csr_C2C_A1_send      = core13_csr_cfg_i[41:40];

    assign                              core13_csr_flag_o[0]        = core13_csr_cal_done  ;
    assign                              core13_csr_flag_o[1]        = core13_csr_W_load_done;

    wire                 [  79: 0]      core13_C2C_A0_send_E       ;
    wire                 [  79: 0]      core13_C2C_A1_send_E       ;
cache_PE_core u_cache_PE_core_13(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core13_csr_precision      ),
    .csr_broadcast_i                    (core13_csr_broadcast      ),
    .csr_W_addr_i                       (core13_csr_W_addr         ),
    .csr_A_addr_i                       (core13_csr_A_addr         ),
    .csr_A_cnt_i                        (core13_csr_A_cnt          ),
    .csr_W_load_en_i                    (core13_csr_en_i[0]        ),
    .csr_cal_en_i                       (core13_csr_en_i[1]        ),
    .csr_test_en_i                      (core13_csr_test_en        ),
    .csr_O_wen_i                        (core13_csr_O_wen          ),
    .csr_W_load_done_o                  (core13_csr_W_load_done    ),
    .csr_cal_done_o                     (core13_csr_cal_done       ),
    .axi_req_i                          (core13_axi_req_i          ),
    .axi_we_i                           (core13_axi_we_i           ),
    .axi_addr_i                         (core13_axi_addr_i         ),
    .axi_wdata_i                        (core13_axi_wdata_i        ),
    .axi_rdata_o                        (core13_axi_rdata_o        ),
    .csr_C2C_A1_encode_en_i             (core13_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core13_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core13_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core13_csr_C2C_A0_recv_en ),
    .csr_C2C_A1_recv_en_i               (core13_csr_C2C_A1_recv_en ),
    .csr_C2C_A0_bypass_i                (core13_csr_C2C_A0_bypass  ),
    .csr_C2C_A1_bypass_i                (core13_csr_C2C_A1_bypass  ),
    .csr_C2C_A0_send_i                  (core13_csr_C2C_A0_send    ),
    .csr_C2C_A1_send_i                  (core13_csr_C2C_A1_send    ),
    .csr_C2C_A0_recv_i                  (core13_csr_C2C_A0_recv    ),
    .csr_C2C_A1_recv_i                  (core13_csr_C2C_A1_recv    ),
    .C2C_A0_recv_W_i                    (core12_C2C_A0_send_E      ),
    .C2C_A1_recv_W_i                    (core12_C2C_A1_send_E      ),
    .C2C_A0_recv_N_i                    (core9_C2C_A0_send_S       ),
    .C2C_A1_recv_N_i                    (core9_C2C_A1_send_S       ),
    .C2C_A0_send_E_o                    (core13_C2C_A0_send_E      ),
    .C2C_A1_send_E_o                    (core13_C2C_A1_send_E      ),
    .C2C_A0_send_S_o                    (                          ),
    .C2C_A1_send_S_o                    (                          ) 
);

//////////////////////////////// Core14(3,2) ///////////////////////////////
    wire                                core14_csr_precision       ;
    wire                                core14_csr_broadcast       ;
    wire                 [   8: 0]      core14_csr_W_addr          ;
    wire                 [   6: 0]      core14_csr_A_addr          ;
    wire                 [   6: 0]      core14_csr_A_cnt           ;
    wire                                core14_csr_test_en         ;
    wire                                core14_csr_O_wen           ;
    wire                                core14_csr_W_load_done     ;
    wire                                core14_csr_cal_done        ;
    wire                                core14_csr_C2C_A1_encode_en;
    wire                 [   1: 0]      core14_csr_C2C_A0_recv     ;
    wire                 [   1: 0]      core14_csr_C2C_A1_recv     ;
    wire                                core14_csr_C2C_A0_input_sel;
    wire                                core14_csr_C2C_A1_input_sel;
    wire                                core14_csr_C2C_A0_recv_en  ;
    wire                                core14_csr_C2C_A1_recv_en  ;
    wire                                core14_csr_C2C_A0_bypass   ;
    wire                                core14_csr_C2C_A1_bypass   ;
    wire                 [   1: 0]      core14_csr_C2C_A0_send     ;
    wire                 [   1: 0]      core14_csr_C2C_A1_send     ;

    assign                              core14_csr_W_addr           = core14_csr_cfg_i[8:0] ;
    assign                              core14_csr_A_addr           = core14_csr_cfg_i[15:9];
    assign                              core14_csr_A_cnt            = core14_csr_cfg_i[22:16];
    assign                              core14_csr_precision        = core14_csr_cfg_i[23]  ;
    assign                              core14_csr_broadcast        = core14_csr_cfg_i[24]  ;
    assign                              core14_csr_test_en          = core14_csr_cfg_i[25]  ;
    assign                              core14_csr_O_wen            = core14_csr_cfg_i[26]  ;
    
    assign                              core14_csr_C2C_A1_encode_en = core14_csr_cfg_i[27]  ;
    assign                              core14_csr_C2C_A0_recv      = core14_csr_cfg_i[29:28];
    assign                              core14_csr_C2C_A1_recv      = core14_csr_cfg_i[31:30];
    assign                              core14_csr_C2C_A0_input_sel = core14_csr_cfg_i[32]  ;
    assign                              core14_csr_C2C_A1_input_sel = core14_csr_cfg_i[33]  ;
    assign                              core14_csr_C2C_A0_recv_en   = core14_csr_cfg_i[34]  ;
    assign                              core14_csr_C2C_A1_recv_en   = core14_csr_cfg_i[35]  ;
    assign                              core14_csr_C2C_A0_bypass    = core14_csr_cfg_i[36]  ;
    assign                              core14_csr_C2C_A1_bypass    = core14_csr_cfg_i[37]  ;
    assign                              core14_csr_C2C_A0_send      = core14_csr_cfg_i[39:38];
    assign                              core14_csr_C2C_A1_send      = core14_csr_cfg_i[41:40];

    assign                              core14_csr_flag_o[0]        = core14_csr_cal_done  ;
    assign                              core14_csr_flag_o[1]        = core14_csr_W_load_done;

    wire                 [  79: 0]      core14_C2C_A0_send_E       ;
    wire                 [  79: 0]      core14_C2C_A1_send_E       ;
cache_PE_core u_cache_PE_core_14(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core14_csr_precision      ),
    .csr_broadcast_i                    (core14_csr_broadcast      ),
    .csr_W_addr_i                       (core14_csr_W_addr         ),
    .csr_A_addr_i                       (core14_csr_A_addr         ),
    .csr_A_cnt_i                        (core14_csr_A_cnt          ),
    .csr_W_load_en_i                    (core14_csr_en_i[0]        ),
    .csr_cal_en_i                       (core14_csr_en_i[1]        ),
    .csr_test_en_i                      (core14_csr_test_en        ),
    .csr_O_wen_i                        (core14_csr_O_wen          ),
    .csr_W_load_done_o                  (core14_csr_W_load_done    ),
    .csr_cal_done_o                     (core14_csr_cal_done       ),
    .axi_req_i                          (core14_axi_req_i          ),
    .axi_we_i                           (core14_axi_we_i           ),
    .axi_addr_i                         (core14_axi_addr_i         ),
    .axi_wdata_i                        (core14_axi_wdata_i        ),
    .axi_rdata_o                        (core14_axi_rdata_o        ),
    .csr_C2C_A1_encode_en_i             (core14_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core14_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core14_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core14_csr_C2C_A0_recv_en ),
    .csr_C2C_A1_recv_en_i               (core14_csr_C2C_A1_recv_en ),
    .csr_C2C_A0_bypass_i                (core14_csr_C2C_A0_bypass  ),
    .csr_C2C_A1_bypass_i                (core14_csr_C2C_A1_bypass  ),
    .csr_C2C_A0_send_i                  (core14_csr_C2C_A0_send    ),
    .csr_C2C_A1_send_i                  (core14_csr_C2C_A1_send    ),
    .csr_C2C_A0_recv_i                  (core14_csr_C2C_A0_recv    ),
    .csr_C2C_A1_recv_i                  (core14_csr_C2C_A1_recv    ),
    .C2C_A0_recv_W_i                    (core13_C2C_A0_send_E      ),
    .C2C_A1_recv_W_i                    (core13_C2C_A1_send_E      ),
    .C2C_A0_recv_N_i                    (core10_C2C_A0_send_S      ),
    .C2C_A1_recv_N_i                    (core10_C2C_A1_send_S      ),
    .C2C_A0_send_E_o                    (core14_C2C_A0_send_E      ),
    .C2C_A1_send_E_o                    (core14_C2C_A1_send_E      ),
    .C2C_A0_send_S_o                    (                          ),
    .C2C_A1_send_S_o                    (                          ) 
);

//////////////////////////////// Core15(3,3) ///////////////////////////////
    wire                                core15_csr_precision       ;
    wire                                core15_csr_broadcast       ;
    wire                 [   8: 0]      core15_csr_W_addr          ;
    wire                 [   6: 0]      core15_csr_A_addr          ;
    wire                 [   6: 0]      core15_csr_A_cnt           ;
    wire                                core15_csr_test_en         ;
    wire                                core15_csr_O_wen           ;
    wire                                core15_csr_W_load_done     ;
    wire                                core15_csr_cal_done        ;
    wire                                core15_csr_C2C_A1_encode_en;
    wire                 [   1: 0]      core15_csr_C2C_A0_recv     ;
    wire                 [   1: 0]      core15_csr_C2C_A1_recv     ;
    wire                                core15_csr_C2C_A0_input_sel;
    wire                                core15_csr_C2C_A1_input_sel;
    wire                                core15_csr_C2C_A0_recv_en  ;
    wire                                core15_csr_C2C_A1_recv_en  ;
    wire                                core15_csr_C2C_A0_bypass   ;
    wire                                core15_csr_C2C_A1_bypass   ;
    wire                 [   1: 0]      core15_csr_C2C_A0_send     ;
    wire                 [   1: 0]      core15_csr_C2C_A1_send     ;

    assign                              core15_csr_W_addr           = core15_csr_cfg_i[8:0] ;
    assign                              core15_csr_A_addr           = core15_csr_cfg_i[15:9];
    assign                              core15_csr_A_cnt            = core15_csr_cfg_i[22:16];
    assign                              core15_csr_precision        = core15_csr_cfg_i[23]  ;
    assign                              core15_csr_broadcast        = core15_csr_cfg_i[24]  ;
    assign                              core15_csr_test_en          = core15_csr_cfg_i[25]  ;
    assign                              core15_csr_O_wen            = core15_csr_cfg_i[26]  ;
    
    assign                              core15_csr_C2C_A1_encode_en = core15_csr_cfg_i[27]  ;
    assign                              core15_csr_C2C_A0_recv      = core15_csr_cfg_i[29:28];
    assign                              core15_csr_C2C_A1_recv      = core15_csr_cfg_i[31:30];
    assign                              core15_csr_C2C_A0_input_sel = core15_csr_cfg_i[32]  ;
    assign                              core15_csr_C2C_A1_input_sel = core15_csr_cfg_i[33]  ;
    assign                              core15_csr_C2C_A0_recv_en   = core15_csr_cfg_i[34]  ;
    assign                              core15_csr_C2C_A1_recv_en   = core15_csr_cfg_i[35]  ;
    assign                              core15_csr_C2C_A0_bypass    = core15_csr_cfg_i[36]  ;
    assign                              core15_csr_C2C_A1_bypass    = core15_csr_cfg_i[37]  ;
    assign                              core15_csr_C2C_A0_send      = core15_csr_cfg_i[39:38];
    assign                              core15_csr_C2C_A1_send      = core15_csr_cfg_i[41:40];

    assign                              core15_csr_flag_o[0]        = core15_csr_cal_done  ;
    assign                              core15_csr_flag_o[1]        = core15_csr_W_load_done;

    wire                 [  79: 0]      core15_C2C_A0_send_E       ;
    wire                 [  79: 0]      core15_C2C_A1_send_E       ;
cache_PE_core u_cache_PE_core_15(
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),
    .csr_precision_i                    (core15_csr_precision      ),
    .csr_broadcast_i                    (core15_csr_broadcast      ),
    .csr_W_addr_i                       (core15_csr_W_addr         ),
    .csr_A_addr_i                       (core15_csr_A_addr         ),
    .csr_A_cnt_i                        (core15_csr_A_cnt          ),
    .csr_W_load_en_i                    (core15_csr_en_i[0]        ),
    .csr_cal_en_i                       (core15_csr_en_i[1]        ),
    .csr_test_en_i                      (core15_csr_test_en        ),
    .csr_O_wen_i                        (core15_csr_O_wen          ),
    .csr_W_load_done_o                  (core15_csr_W_load_done    ),
    .csr_cal_done_o                     (core15_csr_cal_done       ),
    .axi_req_i                          (core15_axi_req_i          ),
    .axi_we_i                           (core15_axi_we_i           ),
    .axi_addr_i                         (core15_axi_addr_i         ),
    .axi_wdata_i                        (core15_axi_wdata_i        ),
    .axi_rdata_o                        (core15_axi_rdata_o        ),
    .csr_C2C_A1_encode_en_i             (core15_csr_C2C_A1_encode_en),
    .csr_C2C_A0_input_sel_i             (core15_csr_C2C_A0_input_sel),
    .csr_C2C_A1_input_sel_i             (core15_csr_C2C_A1_input_sel),
    .csr_C2C_A0_recv_en_i               (core15_csr_C2C_A0_recv_en ),
    .csr_C2C_A1_recv_en_i               (core15_csr_C2C_A1_recv_en ),
    .csr_C2C_A0_bypass_i                (core15_csr_C2C_A0_bypass  ),
    .csr_C2C_A1_bypass_i                (core15_csr_C2C_A1_bypass  ),
    .csr_C2C_A0_send_i                  (core15_csr_C2C_A0_send    ),
    .csr_C2C_A1_send_i                  (core15_csr_C2C_A1_send    ),
    .csr_C2C_A0_recv_i                  (core15_csr_C2C_A0_recv    ),
    .csr_C2C_A1_recv_i                  (core15_csr_C2C_A1_recv    ),
    .C2C_A0_recv_W_i                    (core14_C2C_A0_send_E      ),
    .C2C_A1_recv_W_i                    (core14_C2C_A1_send_E      ),
    .C2C_A0_recv_N_i                    (core11_C2C_A0_send_S      ),
    .C2C_A1_recv_N_i                    (core11_C2C_A1_send_S      ),
    .C2C_A0_send_E_o                    (                          ),
    .C2C_A1_send_E_o                    (                          ),
    .C2C_A0_send_S_o                    (                          ),
    .C2C_A1_send_S_o                    (                          ) 
);

endmodule
    
