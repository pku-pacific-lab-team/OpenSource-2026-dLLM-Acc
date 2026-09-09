`timescale 1ns / 1ps

module cache_PE_core(
    input  wire                         clk                        ,
    input  wire                         rst_n                      ,

    input  wire                         csr_precision_i            ,
    input  wire                         csr_broadcast_i            ,
    input  wire          [   8: 0]      csr_W_addr_i               ,
    input  wire          [   6: 0]      csr_A_addr_i               ,
    input  wire          [   6: 0]      csr_A_cnt_i                ,
    input  wire                         csr_W_load_en_i            ,
    input  wire                         csr_cal_en_i               ,
    input  wire                         csr_test_en_i              ,
    input  wire                         csr_O_wen_i                ,
    output wire                         csr_W_load_done_o          ,
    output wire                         csr_cal_done_o             ,

    input  wire                         axi_req_i                  ,
    input  wire                         axi_we_i                   ,
    input  wire          [  63: 0]      axi_addr_i                 ,
    input  wire          [  63: 0]      axi_wdata_i                ,
    output wire          [  63: 0]      axi_rdata_o                ,
    
    input  wire                         csr_C2C_A1_encode_en_i     ,
    input  wire                         csr_C2C_A0_bypass_i        ,
    input  wire                         csr_C2C_A1_bypass_i        ,
    input  wire                         csr_C2C_A0_input_sel_i     ,
    input  wire                         csr_C2C_A1_input_sel_i     ,
    input  wire                         csr_C2C_A0_recv_en_i       ,
    input  wire                         csr_C2C_A1_recv_en_i       ,
    input  wire          [   1: 0]      csr_C2C_A0_send_i          ,
    input  wire          [   1: 0]      csr_C2C_A1_send_i          ,
    input  wire          [   1: 0]      csr_C2C_A0_recv_i          ,
    input  wire          [   1: 0]      csr_C2C_A1_recv_i          ,

    input  wire          [  79: 0]      C2C_A0_recv_W_i            ,
    input  wire          [  79: 0]      C2C_A1_recv_W_i            ,
    input  wire          [  79: 0]      C2C_A0_recv_N_i            ,
    input  wire          [  79: 0]      C2C_A1_recv_N_i            ,
    output wire          [  79: 0]      C2C_A0_send_E_o            ,
    output wire          [  79: 0]      C2C_A1_send_E_o            ,
    output wire          [  79: 0]      C2C_A0_send_S_o            ,
    output wire          [  79: 0]      C2C_A1_send_S_o
);
    wire                                cal_start                   ;
    wire                 [  15: 0]      W_update                    ;
    wire                 [ 127: 0]      W                           ;
    wire                                Cache0_idx_update           ;
    wire                                Cache1_idx_update           ;
    wire                 [   1: 0]      Cache_idx_addr              ;
    wire                 [  63: 0]      Cache_idx_data              ;
    wire                 [  63: 0]      IA0                         ;
    wire                 [  63: 0]      IA1                         ;
    wire                 [ 383: 0]      Result                      ;

    wire                                W0_buffer_req               ;
    wire                                W0_buffer_we                ;
    wire                 [   7: 0]      W0_buffer_addr              ;
    wire                 [  63: 0]      W0_buffer_wdata             ;
    wire                 [  63: 0]      W0_buffer_rdata             ;
    wire                                W1_buffer_req               ;
    wire                                W1_buffer_we                ;
    wire                 [   7: 0]      W1_buffer_addr              ;
    wire                 [  63: 0]      W1_buffer_wdata             ;
    wire                 [  63: 0]      W1_buffer_rdata             ;

    wire                                A0_buffer_req               ;
    wire                                A0_buffer_we                ;
    wire                 [   5: 0]      A0_buffer_addr              ;
    wire                 [  63: 0]      A0_buffer_wdata             ;
    wire                 [  63: 0]      A0_buffer_rdata             ;
    wire                                A1_buffer_req               ;
    wire                                A1_buffer_we                ;
    wire                 [   5: 0]      A1_buffer_addr              ;
    wire                 [  63: 0]      A1_buffer_wdata             ;
    wire                 [  63: 0]      A1_buffer_rdata             ;

    wire                                O0_buffer_req               ;
    wire                                O0_buffer_we                ;
    wire                 [   5: 0]      O0_buffer_addr              ;
    wire                 [  63: 0]      O0_buffer_wdata             ;
    wire                 [  63: 0]      O0_buffer_rdata             ;
    wire                                O1_buffer_req               ;
    wire                                O1_buffer_we                ;
    wire                 [   5: 0]      O1_buffer_addr              ;
    wire                 [  63: 0]      O1_buffer_wdata             ;
    wire                 [  63: 0]      O1_buffer_rdata             ;
    wire                                O2_buffer_req               ;
    wire                                O2_buffer_we                ;
    wire                 [   5: 0]      O2_buffer_addr              ;
    wire                 [  63: 0]      O2_buffer_wdata             ;
    wire                 [  63: 0]      O2_buffer_rdata             ;
    wire                                O3_buffer_req               ;
    wire                                O3_buffer_we                ;
    wire                 [   5: 0]      O3_buffer_addr              ;
    wire                 [  63: 0]      O3_buffer_wdata             ;
    wire                 [  63: 0]      O3_buffer_rdata             ;
    wire                                O4_buffer_req               ;
    wire                                O4_buffer_we                ;
    wire                 [   5: 0]      O4_buffer_addr              ;
    wire                 [  63: 0]      O4_buffer_wdata             ;
    wire                 [  63: 0]      O4_buffer_rdata             ;
    wire                                O5_buffer_req               ;
    wire                                O5_buffer_we                ;
    wire                 [   5: 0]      O5_buffer_addr              ;
    wire                 [  63: 0]      O5_buffer_wdata             ;
    wire                 [  63: 0]      O5_buffer_rdata             ;

    wire                 [ 191: 0]      O_group0_buffer_wdata       ;
    wire                 [ 191: 0]      O_group1_buffer_wdata       ;

    wire                                broadcast_sel               ;

    wire                                C2C_A0_send_en             ;
    wire                 [  79: 0]      C2C_A0_send                ;
    wire                 [  79: 0]      C2C_A0_recv                ;
    wire                                C2C_A1_send_en             ;
    wire                 [  79: 0]      C2C_A1_send                ;
    wire                 [  79: 0]      C2C_A1_recv                ;

genvar i;
for (i = 0; i < 16; i = i + 1) begin
    assign                              W[8*i+7:8*i]  = csr_precision_i ? csr_W_addr_i[8] ? 
                                                        {-W1_buffer_rdata[4*i+3:4*i],W1_buffer_rdata[4*i+3:4*i]}:
                                                        {-W0_buffer_rdata[4*i+3:4*i],W0_buffer_rdata[4*i+3:4*i]}:
                                                        {W1_buffer_rdata[4*i+3:4*i],W0_buffer_rdata[4*i+3:4*i]};
    assign                              {IA1[4*i+3:4*i],IA0[4*i+3:4*i]}= (~csr_precision_i&csr_broadcast_i) ? broadcast_sel ?
                                                                        {A0_buffer_rdata[4*i+3:4*i],A0_buffer_rdata[4*i+3:4*i]}: 
                                                                        {A1_buffer_rdata[4*i+3:4*i],A1_buffer_rdata[4*i+3:4*i]}:
                                                                        {A1_buffer_rdata[4*i+3:4*i],A0_buffer_rdata[4*i+3:4*i]};
    assign                              O_group0_buffer_wdata[12*i+11:12*i]= csr_O_wen_i ? Result[24*i+11:24*i] : 12'd0;
    assign                              O_group1_buffer_wdata[12*i+11:12*i]= csr_O_wen_i ? Result[24*i+23:24*i+12] : 12'd0;
end
    assign                              {O2_buffer_wdata,O1_buffer_wdata,O0_buffer_wdata}= O_group0_buffer_wdata;
    assign                              {O5_buffer_wdata,O4_buffer_wdata,O3_buffer_wdata}= O_group1_buffer_wdata;

cache_PE_core_ctrlr u_cache_PE_core_ctrlr (
    .clk                                (clk                       ),
    .rst_n                              (rst_n                     ),

    .csr_precision_i                    (csr_precision_i           ),
    .csr_broadcast_i                    (csr_broadcast_i           ),
    .csr_W_addr_i                       (csr_W_addr_i              ),
    .csr_A_addr_i                       (csr_A_addr_i              ),
    .csr_A_cnt_i                        (csr_A_cnt_i               ),
    .csr_W_load_en_i                    (csr_W_load_en_i           ),
    .csr_cal_en_i                       (csr_cal_en_i              ),
    .csr_test_en_i                      (csr_test_en_i             ),
    .csr_O_wen_i                        (csr_O_wen_i               ),
    .csr_W_load_done_o                  (csr_W_load_done_o         ),
    .csr_cal_done_o                     (csr_cal_done_o            ),

    .axi_req_i                          (axi_req_i                 ),
    .axi_we_i                           (axi_we_i                  ),
    .axi_addr_i                         (axi_addr_i                ),
    .axi_wdata_i                        (axi_wdata_i               ),
    .axi_rdata_o                        (axi_rdata_o               ),

    .csr_C2C_A0_input_sel_i             (csr_C2C_A0_input_sel_i    ),
    .csr_C2C_A1_input_sel_i             (csr_C2C_A1_input_sel_i    ),
    .csr_C2C_A0_recv_en_i               (csr_C2C_A0_recv_en_i      ),
    .csr_C2C_A1_recv_en_i               (csr_C2C_A1_recv_en_i      ),      

    .cal_start_o                        (cal_start                 ),
    .W_update_o                         (W_update                  ),
    .Cache0_idx_update_o                (Cache0_idx_update         ),
    .Cache1_idx_update_o                (Cache1_idx_update         ),
    .Cache_idx_addr_o                   (Cache_idx_addr            ),
    .Cache_idx_data_o                   (Cache_idx_data            ),

    .W0_buffer_rdata_i                  (W0_buffer_rdata           ),
    .W0_buffer_req_o                    (W0_buffer_req             ),
    .W0_buffer_we_o                     (W0_buffer_we              ),
    .W0_buffer_addr_o                   (W0_buffer_addr            ),
    .W0_buffer_wdata_o                  (W0_buffer_wdata           ),
    .W1_buffer_rdata_i                  (W1_buffer_rdata           ),
    .W1_buffer_req_o                    (W1_buffer_req             ),
    .W1_buffer_we_o                     (W1_buffer_we              ),
    .W1_buffer_addr_o                   (W1_buffer_addr            ),
    .W1_buffer_wdata_o                  (W1_buffer_wdata           ), 

    .A0_buffer_rdata_i                  (A0_buffer_rdata           ),
    .A0_buffer_req_o                    (A0_buffer_req             ),
    .A0_buffer_we_o                     (A0_buffer_we              ),
    .A0_buffer_addr_o                   (A0_buffer_addr            ),
    .A0_buffer_wdata_o                  (A0_buffer_wdata           ),
    .A1_buffer_rdata_i                  (A1_buffer_rdata           ),
    .A1_buffer_req_o                    (A1_buffer_req             ),
    .A1_buffer_we_o                     (A1_buffer_we              ),
    .A1_buffer_addr_o                   (A1_buffer_addr            ),
    .A1_buffer_wdata_o                  (A1_buffer_wdata           ),

    .O0_buffer_req_o                    (O0_buffer_req             ),
    .O0_buffer_we_o                     (O0_buffer_we              ),
    .O0_buffer_addr_o                   (O0_buffer_addr            ),
    .O0_buffer_rdata_i                  (O0_buffer_rdata           ),
    .O1_buffer_req_o                    (O1_buffer_req             ),
    .O1_buffer_we_o                     (O1_buffer_we              ),
    .O1_buffer_addr_o                   (O1_buffer_addr            ),
    .O1_buffer_rdata_i                  (O1_buffer_rdata           ),
    .O2_buffer_req_o                    (O2_buffer_req             ),
    .O2_buffer_we_o                     (O2_buffer_we              ),
    .O2_buffer_addr_o                   (O2_buffer_addr            ),
    .O2_buffer_rdata_i                  (O2_buffer_rdata           ),
    .O3_buffer_req_o                    (O3_buffer_req             ),
    .O3_buffer_we_o                     (O3_buffer_we              ),
    .O3_buffer_addr_o                   (O3_buffer_addr            ),
    .O3_buffer_rdata_i                  (O3_buffer_rdata           ),
    .O4_buffer_req_o                    (O4_buffer_req             ),
    .O4_buffer_we_o                     (O4_buffer_we              ),
    .O4_buffer_addr_o                   (O4_buffer_addr            ),
    .O4_buffer_rdata_i                  (O4_buffer_rdata           ),
    .O5_buffer_req_o                    (O5_buffer_req             ),
    .O5_buffer_we_o                     (O5_buffer_we              ),
    .O5_buffer_addr_o                   (O5_buffer_addr            ),
    .O5_buffer_rdata_i                  (O5_buffer_rdata           ),

    .broadcast_sel_o                    (broadcast_sel             ) 
);

cache_PE_array u_cache_PE_array(
    .clk                                (clk                       ),
    .en_i                               (cal_start                 ),
    .precision_i                        (csr_precision_i           ),
    .broadcast_i                        (csr_broadcast_i           ),
    .W_update_i                         (W_update                  ),
    .W_i                                (W                         ),
    .Cache0_idx_update_i                (Cache0_idx_update         ),
    .Cache1_idx_update_i                (Cache1_idx_update         ),
    .Cache_idx_addr_i                   (Cache_idx_addr            ),
    .Cache_idx_data_i                   (Cache_idx_data            ),
    .IA0_i                              (IA0                       ),
    .IA1_i                              (IA1                       ),
    .Result_o                           (Result                    ),

    .C2C_A0_input_sel_i                 (csr_C2C_A0_input_sel_i    ),
    .C2C_A0_bypass_i                    (csr_C2C_A0_bypass_i       ),
    .C2C_A0_send_en_i                   (C2C_A0_send_en            ),
    .C2C_A0_send_o                      (C2C_A0_send               ),
    .C2C_A0_recv_en_i                   (csr_C2C_A0_recv_en_i      ),
    .C2C_A0_recv_i                      (C2C_A0_recv               ),
    .C2C_A1_input_sel_i                 (csr_C2C_A1_input_sel_i    ),
    .C2C_A1_bypass_i                    (csr_C2C_A1_bypass_i       ),
    .C2C_A1_send_en_i                   (C2C_A1_send_en            ),
    .C2C_A1_send_o                      (C2C_A1_send               ), 
    .C2C_A1_recv_en_i                   (csr_C2C_A1_recv_en_i      ),
    .C2C_A1_recv_i                      (C2C_A1_recv               ),
    .C2C_A1_encode_en_i                 (csr_C2C_A1_encode_en_i    )
);

//////////////////////////////// weight_buffer ////////////////////////////////

sram_256x64 u_weight0_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (W0_buffer_req             ),
    .write_enable_i                     (W0_buffer_we              ),
    .addr_i                             (W0_buffer_addr            ),
    .write_data_i                       (W0_buffer_wdata           ),
    .read_data_o                        (W0_buffer_rdata           ) 
);

sram_256x64 u_weight1_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (W1_buffer_req             ),
    .write_enable_i                     (W1_buffer_we              ),
    .addr_i                             (W1_buffer_addr            ),
    .write_data_i                       (W1_buffer_wdata           ),
    .read_data_o                        (W1_buffer_rdata           )  
);

////////////////////////////// activation_buffer //////////////////////////////

sram_64x64 u_activation0_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (A0_buffer_req             ),
    .write_enable_i                     (A0_buffer_we              ),
    .addr_i                             (A0_buffer_addr            ),
    .write_data_i                       (A0_buffer_wdata           ),
    .read_data_o                        (A0_buffer_rdata           ) 
);

sram_64x64 u_activation1_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (A1_buffer_req             ),
    .write_enable_i                     (A1_buffer_we              ),
    .addr_i                             (A1_buffer_addr            ),
    .write_data_i                       (A1_buffer_wdata           ),
    .read_data_o                        (A1_buffer_rdata           )  
);

//////////////////////////////// output_buffer ////////////////////////////////

sram_64x64 u_output0_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (O0_buffer_req             ),
    .write_enable_i                     (O0_buffer_we              ),
    .addr_i                             (O0_buffer_addr            ),
    .write_data_i                       (O0_buffer_wdata           ),
    .read_data_o                        (O0_buffer_rdata           ) 
);

sram_64x64 u_output1_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (O1_buffer_req             ),
    .write_enable_i                     (O1_buffer_we              ),
    .addr_i                             (O1_buffer_addr            ),
    .write_data_i                       (O1_buffer_wdata           ),
    .read_data_o                        (O1_buffer_rdata           ) 
);

sram_64x64 u_output2_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (O2_buffer_req             ),
    .write_enable_i                     (O2_buffer_we              ),
    .addr_i                             (O2_buffer_addr            ),
    .write_data_i                       (O2_buffer_wdata           ),
    .read_data_o                        (O2_buffer_rdata           ) 
);

sram_64x64 u_output3_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (O3_buffer_req             ),
    .write_enable_i                     (O3_buffer_we              ),
    .addr_i                             (O3_buffer_addr            ),
    .write_data_i                       (O3_buffer_wdata           ),
    .read_data_o                        (O3_buffer_rdata           ) 
);

sram_64x64 u_output4_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (O4_buffer_req             ),
    .write_enable_i                     (O4_buffer_we              ),
    .addr_i                             (O4_buffer_addr            ),
    .write_data_i                       (O4_buffer_wdata           ),
    .read_data_o                        (O4_buffer_rdata           ) 
);

sram_64x64 u_output5_buffer (
    .clk_i                              (clk                       ),
    .chip_enable_i                      (O5_buffer_req             ),
    .write_enable_i                     (O5_buffer_we              ),
    .addr_i                             (O5_buffer_addr            ),
    .write_data_i                       (O5_buffer_wdata           ),
    .read_data_o                        (O5_buffer_rdata           ) 
);

//////////////////////////// Core-2-Core Interface ////////////////////////////

C2C_intf u_C2C_intf(
    .csr_C2C_A0_send_i                  (csr_C2C_A0_send_i         ),
    .C2C_A0_send_en_o                   (C2C_A0_send_en            ),
    .C2C_A0_send_E_o                    (C2C_A0_send_E_o           ),
    .C2C_A0_send_S_o                    (C2C_A0_send_S_o           ),
    .C2C_A0_send_i                      (C2C_A0_send               ),

    .csr_C2C_A0_recv_i                  (csr_C2C_A0_recv_i         ),
    .csr_C2C_A0_bypass_i                (csr_C2C_A0_bypass_i       ),
    .C2C_A0_recv_W_i                    (C2C_A0_recv_W_i           ),
    .C2C_A0_recv_N_i                    (C2C_A0_recv_N_i           ),
    .C2C_A0_recv_o                      (C2C_A0_recv               ),

    .csr_C2C_A1_send_i                  (csr_C2C_A1_send_i         ),
    .C2C_A1_send_en_o                   (C2C_A1_send_en            ),
    .C2C_A1_send_E_o                    (C2C_A1_send_E_o           ),
    .C2C_A1_send_S_o                    (C2C_A1_send_S_o           ),
    .C2C_A1_send_i                      (C2C_A1_send               ),

    .csr_C2C_A1_recv_i                  (csr_C2C_A1_recv_i         ),
    .csr_C2C_A1_bypass_i                (csr_C2C_A1_bypass_i       ),
    .C2C_A1_recv_W_i                    (C2C_A1_recv_W_i           ),
    .C2C_A1_recv_N_i                    (C2C_A1_recv_N_i           ),
    .C2C_A1_recv_o                      (C2C_A1_recv               ) 
);

endmodule
