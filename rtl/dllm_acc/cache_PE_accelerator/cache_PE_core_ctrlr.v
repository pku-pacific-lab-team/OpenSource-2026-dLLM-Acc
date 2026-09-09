`timescale 1ns / 1ps

module cache_PE_core_ctrlr(
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
    output reg                          csr_W_load_done_o          ,
    output reg                          csr_cal_done_o             ,

    input  wire                         csr_C2C_A0_input_sel_i     ,
    input  wire                         csr_C2C_A1_input_sel_i     ,
    input  wire                         csr_C2C_A0_recv_en_i       ,
    input  wire                         csr_C2C_A1_recv_en_i       ,

    // to axi interface
    input  wire                         axi_req_i                  ,
    input  wire                         axi_we_i                   ,
    input  wire          [  63: 0]      axi_addr_i                 ,
    input  wire          [  63: 0]      axi_wdata_i                ,
    output reg           [  63: 0]      axi_rdata_o                ,

    // to cache_PE_array
    output reg                          cal_start_o                ,
    output reg           [  15: 0]      W_update_o                 ,
    output reg                          Cache0_idx_update_o        ,
    output reg                          Cache1_idx_update_o        ,
    output reg           [   1: 0]      Cache_idx_addr_o           ,
    output reg           [  63: 0]      Cache_idx_data_o           ,

    // to weight_buffer
    input  wire          [  63: 0]      W0_buffer_rdata_i          ,
    output reg                          W0_buffer_req_o            ,
    output reg                          W0_buffer_we_o             ,
    output reg           [   7: 0]      W0_buffer_addr_o           ,
    output reg           [  63: 0]      W0_buffer_wdata_o          ,
    input  wire          [  63: 0]      W1_buffer_rdata_i          ,
    output reg                          W1_buffer_req_o            ,
    output reg                          W1_buffer_we_o             ,
    output reg           [   7: 0]      W1_buffer_addr_o           ,
    output reg           [  63: 0]      W1_buffer_wdata_o          ,

    // to activation_buffer
    input  wire          [  63: 0]      A0_buffer_rdata_i          ,
    output reg                          A0_buffer_req_o            ,
    output reg                          A0_buffer_we_o             ,
    output reg           [   5: 0]      A0_buffer_addr_o           ,
    output reg           [  63: 0]      A0_buffer_wdata_o          ,
    input  wire          [  63: 0]      A1_buffer_rdata_i          ,
    output reg                          A1_buffer_req_o            ,
    output reg                          A1_buffer_we_o             ,
    output reg           [   5: 0]      A1_buffer_addr_o           ,
    output reg           [  63: 0]      A1_buffer_wdata_o          ,

    // to output_buffer
    input  wire          [  63: 0]      O0_buffer_rdata_i          ,
    output reg                          O0_buffer_req_o            ,
    output reg                          O0_buffer_we_o             ,
    output reg           [   5: 0]      O0_buffer_addr_o           ,
    input  wire          [  63: 0]      O1_buffer_rdata_i          ,
    output reg                          O1_buffer_req_o            ,
    output reg                          O1_buffer_we_o             ,
    output reg           [   5: 0]      O1_buffer_addr_o           ,
    input  wire          [  63: 0]      O2_buffer_rdata_i          ,
    output reg                          O2_buffer_req_o            ,
    output reg                          O2_buffer_we_o             ,
    output reg           [   5: 0]      O2_buffer_addr_o           ,
    input  wire          [  63: 0]      O3_buffer_rdata_i          ,
    output reg                          O3_buffer_req_o            ,
    output reg                          O3_buffer_we_o             ,
    output reg           [   5: 0]      O3_buffer_addr_o           ,
    input  wire          [  63: 0]      O4_buffer_rdata_i          ,
    output reg                          O4_buffer_req_o            ,
    output reg                          O4_buffer_we_o             ,
    output reg           [   5: 0]      O4_buffer_addr_o           ,
    input  wire          [  63: 0]      O5_buffer_rdata_i          ,
    output reg                          O5_buffer_req_o            ,
    output reg                          O5_buffer_we_o             ,
    output reg           [   5: 0]      O5_buffer_addr_o           ,

    output reg                          broadcast_sel_o         
);

    localparam                          [   2: 0]      IDLE                        = 3'd0                 ;
    localparam                          [   2: 0]      W_PRE                       = 3'd1                 ;
    localparam                          [   2: 0]      W_LOAD                      = 3'd2                 ;
    localparam                          [   2: 0]      A_PRE                       = 3'd3                 ;
    localparam                          [   2: 0]      CAL                         = 3'd4                 ;

    reg                  [   2: 0]      state_q                     ;
    reg                  [   2: 0]      state_d                     ;
    reg                  [   6: 0]      load_addr_q                 ;
    reg                  [   6: 0]      load_addr_d                 ;
    reg                  [   3: 0]      W_update_shift_q            ;
    reg                  [   3: 0]      W_update_shift_d            ;
    reg                                 csr_W_load_done_q           ;
    reg                                 csr_W_load_done_d           ;
    reg                                 csr_cal_done_q              ;
    reg                                 csr_cal_done_d              ;
    reg                                 cal_start_q                 ;
    reg                                 cal_start_d                 ;
    reg                                 O_buffer_req_q              ;
    reg                                 O_buffer_req_d              ;
    reg                  [   5: 0]      O_buffer_addr_q             ;
    reg                  [   5: 0]      O_buffer_addr_d             ;
    reg                                 broadcast_sel_q             ;
    reg                                 broadcast_sel_d             ;

    reg                  [   8: 0]      W_buffer_addr               ;
    reg                  [   6: 0]      A_buffer_addr               ;

    reg                                 cal_start                   ;

    reg                                 axi_req_q                   ;
    reg                  [   5: 0]      axi_addr_q                  ;

    always @(posedge clk) begin
        if (!rst_n) begin
            state_q                     <= IDLE;
            load_addr_q                 <= 7'd0;
            W_update_shift_q            <= 4'd0;
            csr_W_load_done_q           <= 1'b0;
            csr_cal_done_q              <= 1'b0;
            cal_start_q                 <= 1'b0;
            O_buffer_req_q              <= 1'b0;
            O_buffer_addr_q             <= 6'd0;
            broadcast_sel_q             <= 1'b0;
            axi_req_q                   <= 1'b0;
            axi_addr_q                  <= 4'd0;
        end
        else begin
            state_q                     <= state_d;
            load_addr_q                 <= load_addr_d;
            W_update_shift_q            <= W_update_shift_d;
            csr_W_load_done_q           <= csr_W_load_done_d;
            csr_cal_done_q              <= csr_cal_done_d;
            cal_start_q                 <= cal_start_d;
            O_buffer_req_q              <= O_buffer_req_d;
            O_buffer_addr_q             <= O_buffer_addr_d;
            broadcast_sel_q             <= broadcast_sel_d;
            axi_req_q                   <= axi_req_i&~axi_we_i;
            axi_addr_q                  <= {6{axi_req_i&~axi_we_i}} & {axi_addr_i[10:9],axi_addr_i[8],axi_addr_i[6],axi_addr_i[1:0]};
        end
    end

    always @(*) begin
        state_d                         = state_q;
        load_addr_d                     = load_addr_q;
        W_update_shift_d                = W_update_shift_q;
        csr_W_load_done_d               = csr_W_load_done_q;
        csr_cal_done_d                  = csr_cal_done_q;

        cal_start_d                     = csr_cal_en_i & cal_start;
        O_buffer_req_d                  = cal_start_q & csr_O_wen_i;
        O_buffer_addr_d                 = {6{O_buffer_req_q&csr_O_wen_i}}&(O_buffer_addr_q + 6'd1);

        broadcast_sel_d                 = A0_buffer_req_o;

        case (state_q)
            IDLE: begin
                if (csr_W_load_en_i & ~csr_W_load_done_q) begin
                    state_d             = W_PRE;
                    load_addr_d         = 4'd0;
                    W_update_shift_d    = 4'd0;
                end
                if (~csr_W_load_en_i & csr_W_load_done_q) begin
                    csr_W_load_done_d   = 1'b0;
                end
                if (csr_cal_en_i & ~csr_cal_done_q) begin
                    state_d             = A_PRE;
                    load_addr_d         = 4'd0;                    
                end
                if (~csr_cal_en_i & csr_cal_done_q) begin
                    csr_cal_done_d      = 1'b0;
                end
            end

            W_PRE: begin
                state_d             = W_LOAD;
                load_addr_d         = load_addr_q + 7'd1;
            end

            W_LOAD: begin
                if (W_update_shift_q == 4'd15 & ~csr_test_en_i) begin
                    state_d             = IDLE;
                    load_addr_d         = 7'd0;
                    csr_W_load_done_d   = 1'b1;
                end
                else begin
                    state_d             = W_LOAD;
                    load_addr_d         = load_addr_q + 7'd1;
                    W_update_shift_d    = load_addr_q;
                    csr_W_load_done_d   = 1'b0;
                end
            end

            A_PRE: begin
                state_d             = CAL;
                load_addr_d         = load_addr_q + 7'd1;
            end

            CAL: begin
                if (load_addr_q == csr_A_cnt_i-7'd1) begin
                    if (~csr_test_en_i) begin
                        state_d             = IDLE;
                        csr_cal_done_d      = 1'b1;
                    end
                    else begin
                        load_addr_d         = load_addr_q + 7'd1;
                        csr_cal_done_d      = 1'b0;
                    end
                    load_addr_d         = 7'd0;                   
                end
                else begin
                    state_d             = CAL;
                    load_addr_d         = load_addr_q + 7'd1;
                    csr_cal_done_d      = 1'b0;
                end
            end

            default: begin
                state_d                 = IDLE;
                load_addr_d             = 7'd0;
            end
        endcase
    end


    always @(*) begin
        axi_rdata_o                     = 64'd0;

        W_update_o                      = 16'd0;
        Cache0_idx_update_o             = 1'b0;
        Cache1_idx_update_o             = 1'b0;
        Cache_idx_addr_o                = 2'd0;
        Cache_idx_data_o                = 64'd0;

        W0_buffer_req_o                 = 1'b0;
        W0_buffer_we_o                  = 1'b0;
        W0_buffer_addr_o                = 8'd0;
        W0_buffer_wdata_o               = 64'd0;
        W1_buffer_req_o                 = 1'b0;
        W1_buffer_we_o                  = 1'b0;
        W1_buffer_addr_o                = 8'd0;
        W1_buffer_wdata_o               = 64'd0;

        A0_buffer_req_o                 = 1'b0;
        A0_buffer_we_o                  = 1'b0;
        A0_buffer_addr_o                = 6'd0;
        A0_buffer_wdata_o               = 64'd0;
        A1_buffer_req_o                 = 1'b0;
        A1_buffer_we_o                  = 1'b0;
        A1_buffer_addr_o                = 6'd0;
        A1_buffer_wdata_o               = 64'd0;
        cal_start                       = 1'b0;

        O0_buffer_req_o                 = 1'b0;
        O0_buffer_we_o                  = 1'b0;
        O0_buffer_addr_o                = 6'd0;
        O1_buffer_req_o                 = 1'b0;
        O1_buffer_we_o                  = 1'b0;
        O1_buffer_addr_o                = 6'd0;
        O2_buffer_req_o                 = 1'b0;
        O2_buffer_we_o                  = 1'b0;
        O2_buffer_addr_o                = 6'd0;
        O3_buffer_req_o                 = 1'b0;
        O3_buffer_we_o                  = 1'b0;
        O3_buffer_addr_o                = 6'd0;
        O4_buffer_req_o                 = 1'b0;
        O4_buffer_we_o                  = 1'b0;
        O4_buffer_addr_o                = 6'd0;
        O5_buffer_req_o                 = 1'b0;
        O5_buffer_we_o                  = 1'b0;
        O5_buffer_addr_o                = 6'd0;

        W_buffer_addr                   = 9'd0;
        A_buffer_addr                   = 7'd0;

        csr_W_load_done_o               = csr_W_load_done_q;

        cal_start_o                     = cal_start_q;
        O0_buffer_req_o                 = O_buffer_req_q;
        O0_buffer_addr_o                = O_buffer_addr_q;
        O0_buffer_we_o                  = O_buffer_req_q;
        O1_buffer_req_o                 = O_buffer_req_q;
        O1_buffer_addr_o                = O_buffer_addr_q;
        O1_buffer_we_o                  = O_buffer_req_q;
        O2_buffer_req_o                 = O_buffer_req_q;
        O2_buffer_addr_o                = O_buffer_addr_q;
        O2_buffer_we_o                  = O_buffer_req_q;
        O3_buffer_req_o                 = O_buffer_req_q;
        O3_buffer_addr_o                = O_buffer_addr_q;
        O3_buffer_we_o                  = O_buffer_req_q;
        O4_buffer_req_o                 = O_buffer_req_q;
        O4_buffer_addr_o                = O_buffer_addr_q;
        O4_buffer_we_o                  = O_buffer_req_q;
        O5_buffer_req_o                 = O_buffer_req_q;
        O5_buffer_addr_o                = O_buffer_addr_q;
        O5_buffer_we_o                  = O_buffer_req_q;

        csr_cal_done_o                  = csr_cal_done_q;

        broadcast_sel_o                 = broadcast_sel_q;

        case (state_q)
            IDLE: begin
                if (axi_req_i) begin
                    case (axi_addr_i[10:9])
                        2'b00: begin // 11'b000_0000_0000 ~ 10'b00_0000_111: cache idx regfile W
                            Cache0_idx_update_o     = ~axi_addr_i[2];
                            Cache1_idx_update_o     = axi_addr_i[2];
                            Cache_idx_addr_o        = axi_addr_i[1:0];
                            Cache_idx_data_o        = axi_wdata_i;
                        end
                        2'b01: begin // 11'b010_0000_0000 ~ 10'b011_1111_1111: weight buffer W/R                   
                            W0_buffer_req_o         = ~axi_addr_i[8];
                            W0_buffer_we_o          = axi_we_i;
                            W0_buffer_addr_o        = axi_addr_i[7:0];
                            W0_buffer_wdata_o       = axi_wdata_i;
                            W1_buffer_req_o         = axi_addr_i[8];
                            W1_buffer_we_o          = axi_we_i;
                            W1_buffer_addr_o        = axi_addr_i[7:0];
                            W1_buffer_wdata_o       = axi_wdata_i;
                        end
                        2'b10: begin // 10'b100_0000_0000 ~ 10'b100_0111_1111: activation buffer W/R
                            A0_buffer_req_o         = ~axi_addr_i[6];
                            A0_buffer_we_o          = axi_we_i;
                            A0_buffer_addr_o        = axi_addr_i[5:0];
                            A0_buffer_wdata_o       = axi_wdata_i;
                            A1_buffer_req_o         = axi_addr_i[6];
                            A1_buffer_we_o          = axi_we_i;
                            A1_buffer_addr_o        = axi_addr_i[5:0];
                            A1_buffer_wdata_o       = axi_wdata_i;
                        end
                        2'b11: begin // 10'110_0000_0000 ~ 10'b111_1111_1111: output buffer R
                            O0_buffer_req_o         = ({axi_addr_i[8],axi_addr_i[1:0]} == 3'b000);
                            O0_buffer_addr_o        = axi_addr_i[7:2];
                            O1_buffer_req_o         = ({axi_addr_i[8],axi_addr_i[1:0]} == 3'b001);
                            O1_buffer_addr_o        = axi_addr_i[7:2];
                            O2_buffer_req_o         = ({axi_addr_i[8],axi_addr_i[1:0]} == 3'b010);
                            O2_buffer_addr_o        = axi_addr_i[7:2];
                            O3_buffer_req_o         = ({axi_addr_i[8],axi_addr_i[1:0]} == 3'b100);
                            O3_buffer_addr_o        = axi_addr_i[7:2];
                            O4_buffer_req_o         = ({axi_addr_i[8],axi_addr_i[1:0]} == 3'b101);
                            O4_buffer_addr_o        = axi_addr_i[7:2];
                            O5_buffer_req_o         = ({axi_addr_i[8],axi_addr_i[1:0]} == 3'b110);
                            O5_buffer_addr_o        = axi_addr_i[7:2];
                        end
                    endcase                  
                end
                if (axi_req_q) begin
                    case (axi_addr_q[5:4])
                        2'b00: axi_rdata_o          = 64'd0;
                        2'b01: axi_rdata_o          = axi_addr_q[3] ? W1_buffer_rdata_i : W0_buffer_rdata_i; 
                        2'b10: axi_rdata_o          = axi_addr_q[2] ? A1_buffer_rdata_i : A0_buffer_rdata_i;
                        2'b11: axi_rdata_o          = ({axi_addr_q[3],axi_addr_q[1:0]} == 3'b000) ? O0_buffer_rdata_i :
                                                      ({axi_addr_q[3],axi_addr_q[1:0]} == 3'b001) ? O1_buffer_rdata_i :
                                                      ({axi_addr_q[3],axi_addr_q[1:0]} == 3'b010) ? O2_buffer_rdata_i :
                                                      ({axi_addr_q[3],axi_addr_q[1:0]} == 3'b100) ? O3_buffer_rdata_i : 
                                                      ({axi_addr_q[3],axi_addr_q[1:0]} == 3'b101) ? O4_buffer_rdata_i : 
                                                      ({axi_addr_q[3],axi_addr_q[1:0]} == 3'b110) ? O5_buffer_rdata_i : 64'd0;
                    endcase
                end
            end

            W_PRE: begin
                if(~csr_precision_i)begin
                    W0_buffer_req_o         = 1'b1;
                    W0_buffer_we_o          = 1'b0;
                    W0_buffer_addr_o        = csr_W_addr_i;
                    W1_buffer_req_o         = 1'b1;
                    W1_buffer_we_o          = 1'b0;
                    W1_buffer_addr_o        = csr_W_addr_i;
                end
                else begin
                    W0_buffer_req_o         = ~csr_W_addr_i[8];
                    W0_buffer_we_o          = 1'b0;
                    W0_buffer_addr_o        = csr_W_addr_i[7:0];
                    W1_buffer_req_o         = csr_W_addr_i[8];
                    W1_buffer_we_o          = 1'b0;
                    W1_buffer_addr_o        = csr_W_addr_i[7:0];
                end
            end

            W_LOAD: begin
                W_update_o              = 16'h8000 >> W_update_shift_q;
                W_buffer_addr           = csr_W_addr_i + load_addr_q;
                if(~csr_precision_i)begin
                    W0_buffer_req_o         = 1'b1;
                    W0_buffer_we_o          = 1'b0;
                    W0_buffer_addr_o        = W_buffer_addr[7:0];
                    W1_buffer_req_o         = 1'b1;
                    W1_buffer_we_o          = 1'b0;
                    W1_buffer_addr_o        = W_buffer_addr[7:0];
                end
                else begin
                    W0_buffer_req_o         = ~csr_W_addr_i[8];
                    W0_buffer_we_o          = 1'b0;
                    W0_buffer_addr_o        = W_buffer_addr[7:0];
                    W1_buffer_req_o         = csr_W_addr_i[8];
                    W1_buffer_we_o          = 1'b0;
                    W1_buffer_addr_o        = W_buffer_addr[7:0];
                end
            end

            A_PRE: begin
                cal_start               = 1'b1;
                if(~csr_precision_i & csr_broadcast_i)begin
                    A0_buffer_req_o         = ~csr_A_addr_i[6];
                    A0_buffer_we_o          = 1'b0;
                    A0_buffer_addr_o        = {6{csr_A_addr_i[6]}} | csr_A_addr_i[5:0];
                    A1_buffer_req_o         = csr_A_addr_i[6];
                    A1_buffer_we_o          = 1'b0;
                    A1_buffer_addr_o        = {6{csr_A_addr_i[6]}} & csr_A_addr_i[5:0];
                end
                else begin
                    A0_buffer_req_o         = 1'b1;
                    A0_buffer_we_o          = 1'b0;
                    A0_buffer_addr_o        = csr_A_addr_i[5:0];
                    A1_buffer_req_o         = 1'b1;
                    A1_buffer_we_o          = 1'b0;
                    A1_buffer_addr_o        = csr_A_addr_i[5:0];
                end
                if(csr_C2C_A0_input_sel_i | csr_C2C_A0_recv_en_i)begin
                    A0_buffer_req_o         = 1'b0;
                    A0_buffer_we_o          = 1'b0;
                    A0_buffer_addr_o        = 6'd0;
                end
                if(csr_C2C_A1_input_sel_i | csr_C2C_A1_recv_en_i)begin
                    A1_buffer_req_o         = 1'b0;
                    A1_buffer_we_o          = 1'b0;
                    A1_buffer_addr_o        = 6'd0;
                end
            end

            CAL: begin
                cal_start               = 1'b1;
                A_buffer_addr           = csr_A_addr_i + load_addr_q;
                if(~csr_precision_i & csr_broadcast_i)begin
                    A0_buffer_req_o         = ~A_buffer_addr[6];
                    A0_buffer_we_o          = 1'b0;
                    A0_buffer_addr_o        = {6{A_buffer_addr[6]}} | A_buffer_addr[5:0];
                    A1_buffer_req_o         = A_buffer_addr[6];
                    A1_buffer_we_o          = 1'b0;
                    A1_buffer_addr_o        = {6{A_buffer_addr[6]}} & A_buffer_addr[5:0];
                end
                else begin
                    A0_buffer_req_o         = 1'b1;
                    A0_buffer_we_o          = 1'b0;
                    A0_buffer_addr_o        = A_buffer_addr[5:0];
                    A1_buffer_req_o         = 1'b1;
                    A1_buffer_we_o          = 1'b0;
                    A1_buffer_addr_o        = A_buffer_addr[5:0];
                end
                if(csr_C2C_A0_input_sel_i | csr_C2C_A0_recv_en_i)begin
                    A0_buffer_req_o         = 1'b0;
                    A0_buffer_we_o          = 1'b0;
                    A0_buffer_addr_o        = 6'd0;
                end
                if(csr_C2C_A1_input_sel_i | csr_C2C_A1_recv_en_i)begin
                    A1_buffer_req_o         = 1'b0;
                    A1_buffer_we_o          = 1'b0;
                    A1_buffer_addr_o        = 6'd0;
                end    
            end

            default: begin
            end
        endcase
    end

endmodule
