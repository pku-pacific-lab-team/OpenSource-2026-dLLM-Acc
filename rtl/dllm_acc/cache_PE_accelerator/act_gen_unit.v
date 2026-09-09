`timescale 1ns / 1ps

module act_gen_unit(
    input  wire                         clk                        ,
    input  wire                         en_i                       ,
    input  wire                         precision_i                ,

    input  wire                         Cache0_idx_update_i        ,
    input  wire                         Cache1_idx_update_i        ,    
    input  wire          [   1: 0]      Cache_idx_addr_i           ,
    input  wire          [   3: 0]      Cache_idx_data_i           ,

    input  wire          [   3: 0]      IA0_i                      ,
    output wire          [   3: 0]      IA0_o                      ,
    output wire                         Cache0_update_o            ,
    output wire                         Cache0_hit_o               ,
    output wire          [   1: 0]      Cache0_code_o              ,

    input  wire          [   3: 0]      IA1_i                      ,
    output wire          [   3: 0]      IA1_o                      ,
    output wire                         Cache1_update_o            ,
    output wire                         Cache1_hit_o               ,
    output wire          [   1: 0]      Cache1_code_o              ,
                         
    input  wire                         C2C_A0_input_sel_i         ,
    input  wire                         C2C_A0_bypass_i            ,
    input  wire                         C2C_A0_recv_en_i           ,
    input  wire          [   4: 0]      C2C_A0_recv_i              ,
    input  wire                         C2C_A0_send_en_i           ,
    output reg           [   4: 0]      C2C_A0_send_o              ,
    input  wire                         C2C_A1_input_sel_i         ,
    input  wire                         C2C_A1_bypass_i            ,
    input  wire                         C2C_A1_recv_en_i           ,
    input  wire          [   4: 0]      C2C_A1_recv_i              ,
    input  wire                         C2C_A1_send_en_i           ,
    output reg           [   4: 0]      C2C_A1_send_o              ,
    input  wire                         C2C_A1_encode_en_i
);
    wire                 [   3: 0]      IA0                        ;
    wire                 [   3: 0]      IA1                        ;

    reg                                 Cache0_hit                 ;
    reg                  [   1: 0]      Cache0_code                ;
    reg                  [   3: 0]      Cache0_hit_history_reg     ;
    reg                  [   3: 0]      Cache0_idx_reg[0:3]        ;
    wire                 [   3: 0]      condition0                 ;

    reg                  [   3: 0]      OA0_d                      ;
    reg                  [   3: 0]      OA0_q                      ;
    reg                                 Cache0_hit_d               ;
    reg                                 Cache0_hit_q               ;
    reg                  [   1: 0]      Cache0_code_d              ;
    reg                  [   1: 0]      Cache0_code_q              ;
    reg                                 Cache0_update_d            ;
    reg                                 Cache0_update_q            ;

    reg                                 Cache1_hit                 ;
    reg                  [   1: 0]      Cache1_code                ;
    reg                  [   3: 0]      Cache1_hit_history_reg     ;
    reg                  [   3: 0]      Cache1_idx_reg[0:3]        ;
    wire                 [   3: 0]      condition1                 ;

    reg                  [   3: 0]      OA1_d                      ;
    reg                  [   3: 0]      OA1_tmp_d                  ;
    reg                  [   3: 0]      OA1_q                      ;
    reg                                 Cache1_hit_d               ;
    reg                                 Cache1_hit_q               ;
    reg                  [   1: 0]      Cache1_code_d              ;
    reg                  [   1: 0]      Cache1_code_q              ;
    reg                                 Cache1_update_d            ;
    reg                                 Cache1_update_q            ;
    
    reg                  [   3: 0]      OA1_reg                    ;
    reg                                 Cache1_hit_reg             ;
    reg                  [   1: 0]      Cache1_code_reg            ;
    reg                                 Cache1_update              ;

    assign                              IA0                         = (C2C_A0_input_sel_i) ? C2C_A0_recv_i[3:0] : IA0_i;
    assign                              IA1                         = (C2C_A1_input_sel_i) ? C2C_A1_recv_i[3:0] : IA1_i;

gclk_unit u_gclk_unit(
    .clk_i                              (clk                       ),
    .en_i                               (~(&{Cache0_hit_history_reg,Cache0_hit_history_reg})|Cache0_idx_update_i|Cache1_idx_update_i|precision_i),
    .test_en_i                          (1'b0                      ),
    .gclk_o                             (gclk                      ) 
);

    always @(posedge gclk) begin
        if(Cache0_idx_update_i)
            Cache0_idx_reg[Cache_idx_addr_i] <= Cache_idx_data_i;
    end

    always @(posedge gclk) begin
        if(Cache0_idx_update_i | precision_i)
            Cache0_hit_history_reg <= 4'b0000;
        else if(en_i) begin
            Cache0_hit_history_reg[0] <= (IA0 == Cache0_idx_reg[0]) | Cache0_hit_history_reg[0];
            Cache0_hit_history_reg[1] <= (IA0 == Cache0_idx_reg[1]) | Cache0_hit_history_reg[1];
            Cache0_hit_history_reg[2] <= (IA0 == Cache0_idx_reg[2]) | Cache0_hit_history_reg[2];
            Cache0_hit_history_reg[3] <= (IA0 == Cache0_idx_reg[3]) | Cache0_hit_history_reg[3];
        end
    end

    assign                              condition0[0]               = ((IA0|{4{precision_i}}) == Cache0_idx_reg[0]);
    assign                              condition0[1]               = ((IA0|{4{precision_i}}) == Cache0_idx_reg[1]);
    assign                              condition0[2]               = ((IA0|{4{precision_i}}) == Cache0_idx_reg[2]);
    assign                              condition0[3]               = ((IA0|{4{precision_i}}) == Cache0_idx_reg[3]);
    always @(*) begin
        if(~precision_i) begin
            case (condition0)
                4'b0001: {Cache0_hit,Cache0_code} = {Cache0_hit_history_reg[0],2'b00};
                4'b0010: {Cache0_hit,Cache0_code} = {Cache0_hit_history_reg[1],2'b01};
                4'b0100: {Cache0_hit,Cache0_code} = {Cache0_hit_history_reg[2],2'b10};
                4'b1000: {Cache0_hit,Cache0_code} = {Cache0_hit_history_reg[3],2'b11};
                default: {Cache0_hit,Cache0_code} = {1'b0,2'b00};
            endcase
        end
        else begin
            Cache0_hit = IA1[3];
            Cache0_code = IA0[1:0];
        end
    end

    always @(*) begin
        OA0_d = OA0_q;
        Cache0_hit_d = Cache0_hit_q;
        Cache0_code_d = Cache0_code_q;
        Cache0_update_d = 1'b0;
        if(~C2C_A0_recv_en_i)begin
            if(~precision_i)begin
                if(~Cache0_hit)
                    OA0_d = IA0;
                else
                    OA0_d = OA0_q;
                Cache0_hit_d  = Cache0_hit;
                if(|condition0)
                    Cache0_code_d = Cache0_code;
                else
                    Cache0_code_d = Cache0_code_q;
            end
            else begin
                if(~IA1[3])
                    OA0_d = {IA1[2:0],IA0[3]};
                else
                    OA0_d = OA0_q;
                Cache0_hit_d  = Cache0_hit;
                if(~IA0[2])
                    Cache0_code_d = Cache0_code;
                else
                    Cache0_code_d = Cache0_code_q;
            end
            if(en_i)
                Cache0_update_d =(condition0 == 4'b0001 & ~Cache0_hit_history_reg[0])
                                |(condition0 == 4'b0010 & ~Cache0_hit_history_reg[1])
                                |(condition0 == 4'b0100 & ~Cache0_hit_history_reg[2])
                                |(condition0 == 4'b1000 & ~Cache0_hit_history_reg[3]);
            else 
                Cache0_update_d = 1'b0;
        end
        else begin // Core-2-Core data decompression
            Cache0_update_d = 1'b0;
            if(~precision_i)begin                
                Cache0_hit_d = C2C_A0_recv_i[4];
                if(~C2C_A0_recv_i[4])begin
                    OA0_d = C2C_A0_recv_i[3:0];
                    Cache0_code_d = Cache0_code_q;
                end
                else begin
                    OA0_d = OA0_q;
                    Cache0_code_d = C2C_A0_recv_i[1:0];
                end
            end
            else begin
                Cache0_hit_d = C2C_A1_recv_i[3];
                if(~C2C_A1_recv_i[3])
                    OA0_d = {C2C_A1_recv_i[2:0],C2C_A0_recv_i[3]};
                else
                    OA0_d = OA0_q;
                if(~C2C_A0_recv_i[2])
                    Cache0_code_d = C2C_A0_recv_i[1:0];
                else
                    Cache0_code_d = Cache0_code_q;   
            end
        end
    end

    always @(posedge clk) begin
        OA0_q <= OA0_d;
        Cache0_hit_q <= Cache0_hit_d;
        Cache0_code_q <= Cache0_code_d;
        Cache0_update_q <= Cache0_update_d;
    end

    assign                              IA0_o                       = OA0_q                ;
    assign                              Cache0_hit_o                = Cache0_hit_q         ;
    assign                              Cache0_code_o               = Cache0_code_q        ;
    assign                              Cache0_update_o             = Cache0_update_q      ;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    always @(posedge gclk) begin
        if(Cache1_idx_update_i)
            Cache1_idx_reg[Cache_idx_addr_i] <= Cache_idx_data_i;
    end

    always @(posedge gclk) begin
        if(Cache1_idx_update_i | precision_i)
            Cache1_hit_history_reg <= 4'b0000;
        else if(en_i) begin
            Cache1_hit_history_reg[0] <= (IA1 == Cache1_idx_reg[0]) | Cache1_hit_history_reg[0];
            Cache1_hit_history_reg[1] <= (IA1 == Cache1_idx_reg[1]) | Cache1_hit_history_reg[1];
            Cache1_hit_history_reg[2] <= (IA1 == Cache1_idx_reg[2]) | Cache1_hit_history_reg[2];
            Cache1_hit_history_reg[3] <= (IA1 == Cache1_idx_reg[3]) | Cache1_hit_history_reg[3];
        end
    end

    assign                              condition1[0]               = ((IA1|{4{precision_i}}) == Cache1_idx_reg[0]);
    assign                              condition1[1]               = ((IA1|{4{precision_i}}) == Cache1_idx_reg[1]);
    assign                              condition1[2]               = ((IA1|{4{precision_i}}) == Cache1_idx_reg[2]);
    assign                              condition1[3]               = ((IA1|{4{precision_i}}) == Cache1_idx_reg[3]);
    always @(*) begin
        if(~precision_i) begin
            case (condition1)
                4'b0001: {Cache1_hit,Cache1_code} = {Cache1_hit_history_reg[0],2'b00};
                4'b0010: {Cache1_hit,Cache1_code} = {Cache1_hit_history_reg[1],2'b01};
                4'b0100: {Cache1_hit,Cache1_code} = {Cache1_hit_history_reg[2],2'b10};
                4'b1000: {Cache1_hit,Cache1_code} = {Cache1_hit_history_reg[3],2'b11};
                default: {Cache1_hit,Cache1_code} = {1'b0,2'b00};
            endcase
        end
        else begin
            Cache1_hit = IA0[2];
            Cache1_code = IA0[1:0];
        end
    end

    always @(*) begin
        OA1_d = OA1_q;
        Cache1_hit_d = Cache1_hit_q;
        Cache1_code_d = Cache1_code_q;
        Cache1_update_d = 1'b0;
        if(precision_i&IA1[3])
            OA1_tmp_d = (~{IA1[2:0], IA0[3]}) + 4'b0001;
        else
            OA1_tmp_d = {IA1[2:0], 1'b0};
        if(~C2C_A1_recv_en_i)begin
            if(~precision_i)begin
                if(~Cache1_hit)
                    OA1_d = IA1;
                else
                    OA1_d = OA1_q;
                Cache1_hit_d  = Cache1_hit;
                if(|condition1)
                    Cache1_code_d = Cache1_code;
                else
                    Cache1_code_d = Cache1_code_q;
            end
            else begin
                if(IA1[3])
                    OA1_d = OA1_tmp_d;
                else
                    OA1_d = OA1_q;
                Cache1_hit_d  = Cache1_hit;
                if(IA0[2])                
                    Cache1_code_d = Cache1_code;
                else
                    Cache1_code_d = Cache1_code_q;
            end
            if(en_i)
                Cache1_update_d =(condition1 == 4'b0001 & ~Cache1_hit_history_reg[0])
                                |(condition1 == 4'b0010 & ~Cache1_hit_history_reg[1])
                                |(condition1 == 4'b0100 & ~Cache1_hit_history_reg[2])
                                |(condition1 == 4'b1000 & ~Cache1_hit_history_reg[3]);
            else 
                Cache1_update_d = 1'b0;
        end
        else begin // Core-2-Core data decompression
            Cache1_update_d = 1'b0;
            if(~precision_i)begin
                Cache1_hit_d = C2C_A1_recv_i[4];
                if(~C2C_A1_recv_i[4])begin
                    OA1_d = C2C_A1_recv_i[3:0];
                    Cache1_code_d = Cache1_code_q;
                end
                else begin
                    OA1_d = OA1_q;
                    Cache1_code_d = C2C_A1_recv_i[1:0];
                end
            end
            else begin
                Cache1_hit_d = C2C_A0_recv_i[2];
                if(C2C_A1_recv_i[3])
                    OA1_d = {C2C_A1_recv_i[2:0],C2C_A0_recv_i[3]};
                else
                    OA1_d = OA1_q;
                if(C2C_A0_recv_i[2])
                    Cache1_code_d = C2C_A0_recv_i[1:0];
                else
                    Cache1_code_d = Cache1_code_q;
            end
        end
    end

    always @(posedge clk) begin
        OA1_q <= OA1_d;
        Cache1_hit_q <= Cache1_hit_d;
        Cache1_code_q <= Cache1_code_d;
        Cache1_update_q <= Cache1_update_d;
    end

    assign                              IA1_o                       = OA1_q                ;
    assign                              Cache1_hit_o                = Cache1_hit_q         ;
    assign                              Cache1_code_o               = Cache1_code_q        ;
    assign                              Cache1_update_o             = Cache1_update_q      ;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Core-2-Core data compression
    always @(*) begin
        C2C_A0_send_o = 5'b00000;
        C2C_A1_send_o = 5'b00000;
        if(~precision_i)begin
            if(C2C_A0_send_en_i)
                if(Cache0_hit_d)
                    C2C_A0_send_o = {1'b1,2'b00,Cache0_code_d};
                else
                    C2C_A0_send_o = {1'b0,OA0_d};
            if(C2C_A1_send_en_i)
                if(Cache1_hit_d)
                    C2C_A1_send_o = {1'b1,2'b00,Cache1_code_d};
                else
                    C2C_A1_send_o = {1'b0,OA1_d};
        end
        else begin
            if(C2C_A1_send_en_i&C2C_A0_send_en_i)
                if(Cache1_hit_d)
                    C2C_A0_send_o[2:0] = {1'b1, Cache1_code_d};
                else
                    C2C_A0_send_o[2:0] = {1'b0, Cache0_code_d};
                if(Cache0_hit_d)
                    {C2C_A1_send_o[3:0], C2C_A0_send_o[3]} = {1'b1,OA1_d};
                else
                    {C2C_A1_send_o[3:0], C2C_A0_send_o[3]} = {1'b0,OA0_d};
            if(~C2C_A1_send_en_i&C2C_A0_send_en_i)
                if(C2C_A1_encode_en_i) 
                    C2C_A0_send_o = {1'b0, IA1[3], OA1_tmp_d[3:1]}; 
                else 
                    C2C_A0_send_o = {1'b0, IA1};
            if(C2C_A1_send_en_i&~C2C_A0_send_en_i)
                if(C2C_A1_encode_en_i)
                    C2C_A1_send_o = {1'b0, IA1[3], OA1_tmp_d[3:1]}; 
                else 
                    C2C_A1_send_o = {1'b0, IA1};        
        end
        if(C2C_A0_bypass_i)
            C2C_A0_send_o = C2C_A0_recv_i;
        if(C2C_A1_bypass_i)
            C2C_A1_send_o = C2C_A1_recv_i;
    end

endmodule
