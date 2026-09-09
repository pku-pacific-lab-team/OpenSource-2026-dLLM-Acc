`timescale 1ns / 1ps

module topk_ss #(
    parameter int SPACE      = 8
) (
    input   logic        [3:0]   A                  ,
    input   logic                rst_n              ,
    input   logic                check              ,
    input   logic                en                 ,
    input   logic                out_en             ,
    input   logic                clk                ,
    output  logic        [3:0]   AC_out     [3:0]   ,
    output  logic                vld_out_o            
);
    logic        [SPACE  : 0]    CNT        [5:0]   ;
    logic        [3      : 0]    AC         [5:0]   ;
    logic        [5      : 0]    min_Addr           ;
    logic                        fsm_first_check    ;
    logic                        fsm_out_en         ;
    logic                        rst_cnt            ;
    logic                        gclk_output        ;
    logic        [2      : 0]    STAGE              ;

    

    topk_MIN_6 #(
        .SPACE          (SPACE              )
    )u_MIN( 
        .data_i         (CNT                ),
        .addr_o         (min_Addr           )
    );

    logic [3:0] query;

    logic   [5:0] HIT_position;
    logic         HIT;
    topk_HIT u_HIT_AS(
        .HIT_position   (HIT_position       ),
        .HIT            (HIT                ),
        .cached_value   (AC                 ),
        .query          (query              )
    );
    
    logic   [5:0] min_cnt;
    assign min_cnt  =   (!HIT)*min_Addr ;
    
    logic en_i;
    assign en_i=en&(!out_en)&(!check);

    logic fsm_en;

    logic [      3:0] AC_fsm   [5:0];
    logic [SPACE  :0] CNT_fsm [5:0];

    logic [      3:0] AC_sel   [4:0];
    logic [SPACE  :0] CNT_sel [4:0];

    genvar i;
    generate
        for(i=0;i<6;i++)begin
            topk_counter #(
                .CNT_WIDTH (SPACE)
            )u_counter(
                .clk    (clk               ),
                .en_i   (en_i               ),
                .hit    (HIT_position[i]    ),
                .min_cnt(min_cnt[i]         ),
                .rst_n  (rst_n&rst_cnt      ),
                .A      (A                  ),
                .CNT    (CNT[i]             ),
                .AS     (AC[i]              ),
                .fsm_en (fsm_en             ),
                .CNT_fsm(CNT_fsm[i]         ),
                .A_fsm  (AC_fsm[i]           )
            );
        end
    endgenerate

    logic [3:0] prd_AC_d;
    logic [3:0] prd_AC_q;
    logic [SPACE:0] prd_CNT_d;
    logic [SPACE:0] prd_CNT_q;

    logic [SPACE: 0] CNT_cache_d [3:0];
    logic [3    : 0] AC_cache_d  [3:0];
    logic [SPACE: 0] CNT_cache_q [3:0];
    logic [3    : 0] AC_cache_q  [3:0];



    always_comb begin : output_ctrlr
        query=A;
        for(int i=0;i<4;i++)begin
            AC_out[i]=AC_cache_q[i]*fsm_out_en;
        end
        AC_fsm=AC;
        CNT_fsm=CNT;
        fsm_en=0;
        prd_AC_d=prd_AC_q;
        prd_CNT_d=prd_CNT_q;
        CNT_cache_d=CNT_cache_q;
        AC_cache_d=AC_cache_q;
        if(STAGE==1||STAGE==2)begin
            CNT_fsm[5]=1'b1<<<SPACE;
            AC_fsm[5]=0;
            fsm_en=1;
            for(int i=0;i<5;i++)begin
                CNT_fsm[i]=CNT_sel[i];
                AC_fsm[i]=AC_sel[i];
            end
        end
        if(STAGE==3)begin
            if(fsm_first_check)begin
                for(int i=0;i<4;i++)begin
                    AC_cache_d[i]  = AC[i];
                    CNT_cache_d[i] = CNT[i];
                end
            end
            else begin
                for(int i=0;i<4;i++)begin
                    if(min_Addr[i])begin
                        prd_AC_d=AC[i];
                        prd_CNT_d=CNT[i];
                        break;
                    end
                end
                fsm_en=1;
                for(int i=0;i<4;i++)begin
                    CNT_fsm[i]=CNT_cache_q[i];
                    AC_fsm[i]=AC_cache_q[i];
                end
            end
        end
        if(STAGE==4)begin
            if(~fsm_first_check)begin
                query=prd_AC_q;
                for(int i=0;i<4;i++)begin
                    if(min_Addr[i])begin
                        if((CNT_cache_q[i]<prd_CNT_q)&&(~(|HIT_position[3:0])))begin
                            CNT_cache_d[i] = prd_CNT_q;
                            AC_cache_d [i] = prd_AC_q;
                        end
                        break;
                    end
                end
            end
        end

    end

    always_ff @( posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            for(int i=0;i<4;i++)begin
                AC_cache_q[i]<=0;
                CNT_cache_q[i]<=0;
            end
            prd_CNT_q<=0;
            prd_AC_q<=0;
        end
        else if(0<STAGE&&STAGE<5)begin
            AC_cache_q  <= AC_cache_d   ;
            CNT_cache_q <= CNT_cache_d  ;
            prd_CNT_q   <= prd_CNT_d    ;
            prd_AC_q    <= prd_AC_d     ;
        end
    end


    topk_SEL_6_5#(
        .WIDTH(SPACE)
    )u_sel_CNT(
        .data_i (CNT            ),
        .sel_i  (min_Addr[4:0]  ),
        .data_o (CNT_sel        )
    );

    topk_SEL_6_5#(
        .WIDTH(3)
    )u_sel_AC(
        .data_i (AC             ),
        .sel_i  (min_Addr[4:0]  ),
        .data_o (AC_sel         )
    );


    

    topk_ctrlr u_ctrlr(
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .check          (check          ),
        .out_en         (out_en         ),
        .fsm_first_check(fsm_first_check),
        .fsm_out_en     (fsm_out_en     ),
        .rst_cnt        (rst_cnt        ),
        .vld_out        (vld_out_o      ),
        .STAGE          (STAGE          )
    );


endmodule