`timescale 1ns / 1ps

module cache_PE_unit(
    input  wire                         gclk                       ,
    input  wire                         precision_i                ,
    input  wire                         W_update_i                 ,
    input  wire          [   7: 0]      W_i                        ,

    input  wire          [   3: 0]      IA0_i                      ,
    input  wire                         Cache0_update_i            ,
    input  wire                         Cache0_hit_i               ,
    input  wire          [   1: 0]      Cache0_code_i              ,
    output wire          [   7: 0]      OA0_o                      ,

    input  wire          [   3: 0]      IA1_i                      ,
    input  wire                         Cache1_update_i            ,
    input  wire                         Cache1_hit_i               ,
    input  wire          [   1: 0]      Cache1_code_i              ,
    output wire          [   7: 0]      OA1_o                      ,
    
    output wire          [  11: 0]      OA_o 
);
    genvar i;

    wire                 [   7: 0]      PE0_OA                      ;
    wire                 [   7: 0]      Cache0_OA                   ;
    reg     signed       [   3: 0]      W0_reg                      ;
    reg                  [   7: 0]      Cache0_reg[0:3]             ;
    
    wire                 [   1: 0]      Cache0_addr                 ;
    wire                 [   7: 0]      Cache0_data                 ;

    wire                 [   7: 0]      PE1_OA                      ;
    wire                 [   7: 0]      Cache1_OA                   ;
    reg     signed       [   3: 0]      W1_reg                      ;
    reg                  [   7: 0]      Cache1_reg[0:3]             ;

    wire                 [   1: 0]      Cache1_addr                 ;
    wire                 [   7: 0]      Cache1_data                 ;

    wire                 [   7: 0]      PE_OA                       ;
    wire                 [   7: 0]      PE_OA_final                 ;
    wire                 [   6: 0]      Cache_OA                    ;

    always @(posedge gclk) begin
        if(W_update_i)
            W0_reg <= W_i[3:0];
    end

    assign                              PE0_OA                      = $signed({~precision_i & IA0_i[3], IA0_i}) * $signed(W0_reg);

    assign                              Cache0_addr                 = (Cache0_update_i) ? Cache0_code_i : 2'b00;
    assign                              Cache0_data                 = (Cache0_update_i) ? PE0_OA : 8'b0;

    always @(posedge gclk) begin
        if(Cache0_update_i)begin
            Cache0_reg[Cache0_addr] <= Cache0_data;
        end
        else begin
            Cache0_reg[Cache0_addr] <= Cache0_reg[Cache0_addr];
        end
    end

    generate
        for (i = 0; i < 8; i = i + 1) begin : GEN_MUX0
            mux4_unit u_cache0_mux4 (
                .I0(Cache0_reg[0][i]),
                .I1(Cache0_reg[1][i]),
                .I2(Cache0_reg[2][i]),
                .I3(Cache0_reg[3][i]),
                .S0(Cache0_code_i[0]),
                .S1(Cache0_code_i[1]),
                .Zout(Cache0_OA[i])
            );
            mux2_unit u_cache0_mux2 (
                .I0(PE0_OA[i]),
                .I1(precision_i | Cache0_OA[i]),
                .S(precision_i | Cache0_hit_i),
                .Zout(OA0_o[i])
            );
        end
    endgenerate

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    always @(posedge gclk) begin
        if(W_update_i)
            W1_reg <= W_i[7:4];
    end

    assign                              PE1_OA                      = $signed({~precision_i & IA1_i[3], IA1_i}) * $signed(W1_reg);

    assign                              Cache1_addr                 = (Cache1_update_i) ? Cache1_code_i : 2'b00;
    assign                              Cache1_data                 = (Cache1_update_i) ? PE1_OA : 8'b0;

    always @(posedge gclk) begin
        if(Cache1_update_i)begin
            Cache1_reg[Cache1_addr] <= Cache1_data;
        end
        else begin
            Cache1_reg[Cache1_addr] <= Cache1_reg[Cache1_addr];
        end
    end

    generate
        for (i = 0; i < 8; i = i + 1) begin : GEN_MUX1
            mux4_unit u_cache1_mux4 (
                .I0(Cache1_reg[0][i]),
                .I1(Cache1_reg[1][i]),
                .I2(Cache1_reg[2][i]),
                .I3(Cache1_reg[3][i]),
                .S0(Cache1_code_i[0]),
                .S1(Cache1_code_i[1]),
                .Zout(Cache1_OA[i])
            );
            mux2_unit u_cache1_mux2 (
                .I0(PE1_OA[i]),
                .I1(precision_i | Cache1_OA[i]),
                .S(precision_i | Cache1_hit_i),
                .Zout(OA1_o[i])
            );
        end
    endgenerate

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    generate
        for (i = 0; i < 7; i = i + 1) begin : GEN_MUX2
            mux2_unit u_cache_mux2 (
                .I0(precision_i & Cache0_OA[i]),
                .I1(precision_i & Cache1_OA[i]),
                .S(precision_i & Cache1_hit_i),
                .Zout(Cache_OA[i])
            );
        end
    endgenerate

    generate
        for (i = 0; i < 8; i = i + 1) begin : GEN_MUX3
            mux2_unit u_w_mux2 (
                .I0(precision_i & PE0_OA[i]),
                .I1(precision_i & PE1_OA[i]),
                .S(precision_i & Cache0_hit_i),
                .Zout(PE_OA[i])
            );
        end
    endgenerate

    assign PE_OA_final = (precision_i & (|IA1_i) | ~Cache0_hit_i) ? PE_OA : {W1_reg, 4'b0000};
    assign OA_o = $signed({PE_OA_final[7], PE_OA_final, 3'b000}) + $signed({{5{Cache_OA[6]}}, Cache_OA});

endmodule
