`timescale 1ns / 1ps

module topk_ctrlr(
    input   logic           clk                 ,
    input   logic           rst_n               ,
    input   logic           check               ,   
    input   logic           out_en              ,
    output  logic           fsm_first_check     ,
    output  logic           fsm_out_en          ,
    output  logic           rst_cnt             ,
    output  logic           vld_out             ,
    output  logic    [2:0]  STAGE               
    
);
    logic                fsm_check          ;
    logic [2:0]          fsm_cnt            ;
    logic                first_check        ;
    logic                first_check_1      ;

    assign STAGE = fsm_cnt;
    assign fsm_first_check = ~first_check;
    always_ff @( posedge clk or negedge rst_n) begin : fsm
        if(!rst_n)begin
            fsm_check<=0;
            fsm_cnt<=0;
            first_check_1<=0;
            first_check<=0;
        end
        else begin
            fsm_check<=check;
            if(~(|fsm_cnt))begin
                if(check&~fsm_check)
                    fsm_cnt <= 1;
                else
                    fsm_cnt <= 0;
            end
            else if(fsm_cnt<5)
                fsm_cnt <= fsm_cnt+1;
            else if(!check)
                fsm_cnt <= 0;
            else
                fsm_cnt <= fsm_cnt;

            if(check&(~fsm_check))
                first_check_1 <= 1;
            else
                first_check_1 <= first_check_1;
            if((~check)&(first_check_1))
                first_check<=1;
            else
                first_check<=first_check;
        end
    end

    assign vld_out=fsm_out_en;

    always_comb begin
        rst_cnt=1;
        fsm_out_en=0;
        if(fsm_cnt==5)begin
            rst_cnt=0;
            if(out_en)
                fsm_out_en=1;
        end
    end

    

endmodule