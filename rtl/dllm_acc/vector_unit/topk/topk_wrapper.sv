`timescale 1ns / 1ps


module topk_wrapper #(
    parameter int period    = 256                   ,
    parameter int COPY      = 1                     ,
    parameter int SPACE     = $clog2(period)
) (
    input   logic                rst_n              ,
    input   logic                clk                ,
    input   logic        [3:0]   A_i                ,
    input   logic                clear_i            ,
    input   logic                vld_in_i           ,
    input   logic                period_end_i       ,     
    input   logic                rd_en_i            ,
    output  logic        [3:0]   AC_out_o    [3:0]  ,
    output  logic                vld_out_o              
);  



    topk_ss #(
        .SPACE  (SPACE          )
    ) u_topk(
        .A              (A_i                ),
        .rst_n          (rst_n&(!clear_i)   ),
        .en             (vld_in_i           ),
        .check          (period_end_i       ),
        .out_en         (rd_en_i            ),    
        .AC_out         (AC_out_o           ),
        .clk            (clk                ),
        .vld_out_o      (vld_out_o          )
    );   
    
endmodule
