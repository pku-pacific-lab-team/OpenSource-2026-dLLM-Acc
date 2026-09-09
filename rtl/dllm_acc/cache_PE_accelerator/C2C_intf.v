`timescale 1ns / 1ps

module C2C_intf(
    input  wire          [   1: 0]      csr_C2C_A0_send_i          ,
    output wire                         C2C_A0_send_en_o           ,
    output wire          [  79: 0]      C2C_A0_send_E_o            ,
    output wire          [  79: 0]      C2C_A0_send_S_o            ,
    input  wire          [  79: 0]      C2C_A0_send_i              ,

    input  wire          [   1: 0]      csr_C2C_A0_recv_i          ,
    input  wire                         csr_C2C_A0_bypass_i        , 
    input  wire          [  79: 0]      C2C_A0_recv_W_i            ,
    input  wire          [  79: 0]      C2C_A0_recv_N_i            ,
    output wire          [  79: 0]      C2C_A0_recv_o              ,

    input  wire          [   1: 0]      csr_C2C_A1_send_i          ,
    output wire                         C2C_A1_send_en_o           ,
    output wire          [  79: 0]      C2C_A1_send_E_o            ,
    output wire          [  79: 0]      C2C_A1_send_S_o            ,
    input  wire          [  79: 0]      C2C_A1_send_i              ,

    input  wire          [   1: 0]      csr_C2C_A1_recv_i          ,
    input  wire                         csr_C2C_A1_bypass_i        ,
    input  wire          [  79: 0]      C2C_A1_recv_W_i            ,
    input  wire          [  79: 0]      C2C_A1_recv_N_i            ,
    output wire          [  79: 0]      C2C_A1_recv_o
);

    assign                              C2C_A0_send_en_o            = (|csr_C2C_A0_send_i)&(~csr_C2C_A0_bypass_i);
    assign                              C2C_A0_send_E_o             = csr_C2C_A0_send_i[0] ? C2C_A0_send_i : 80'b0;
    assign                              C2C_A0_send_S_o             = csr_C2C_A0_send_i[1] ? C2C_A0_send_i : 80'b0;

    assign                              C2C_A0_recv_o               = (csr_C2C_A0_recv_i==2'b01) ? C2C_A0_recv_W_i : C2C_A0_recv_N_i;

    assign                              C2C_A1_send_en_o            = (|csr_C2C_A1_send_i)&(~csr_C2C_A1_bypass_i);
    assign                              C2C_A1_send_E_o             = csr_C2C_A1_send_i[0] ? C2C_A1_send_i : 80'b0;
    assign                              C2C_A1_send_S_o             = csr_C2C_A1_send_i[1] ? C2C_A1_send_i : 80'b0;

    assign                              C2C_A1_recv_o               = (csr_C2C_A1_recv_i==2'b01) ? C2C_A1_recv_W_i : C2C_A1_recv_N_i;
                                                                                                                                      
endmodule