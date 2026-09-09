`timescale 1ns / 1ps


module topk_MIN_6 #(
    parameter int SPACE =7
) (
    input   logic   [SPACE:0] data_i [5:0],
    output  logic   [5    :0] addr_o
);


//lv1
    logic   [1      :0]     lv1_addr_0;
    logic   [SPACE  :0]     lv1_data_0;
    logic   [1      :0]     lv1_addr_1;
    logic   [SPACE  :0]     lv1_data_1;
    logic   [1      :0]     lv1_addr_2;
    logic   [SPACE  :0]     lv1_data_2;
    
    always_comb begin
        if(data_i[0]<data_i[1])begin
            lv1_data_0=data_i[0];
            lv1_addr_0=2'b01;
        end
        else begin
            lv1_data_0=data_i[1];
            lv1_addr_0=2'b10;
        end
    end

    always_comb begin
        if(data_i[2]<data_i[3])begin
            lv1_data_1=data_i[2];
            lv1_addr_1=2'b01;
        end
        else begin
            lv1_data_1=data_i[3];
            lv1_addr_1=2'b10;
        end
    end

    always_comb begin
        if(data_i[4]<data_i[5])begin
            lv1_data_2=data_i[4];
            lv1_addr_2=2'b01;
        end
        else begin
            lv1_data_2=data_i[5];
            lv1_addr_2=2'b10;
        end
    end

//lv2

    logic [SPACE    :0]     lv2_data;
    logic [3        :0]     lv2_addr;
    always_comb begin
        if(lv1_data_0<lv1_data_1)begin
            lv2_data=lv1_data_0;
            lv2_addr={{2'b00},{lv1_addr_0}};
        end
        else begin
            lv2_data=lv1_data_1;
            lv2_addr={{lv1_addr_1},{2'b00}};
        end
    end

//lv3
    always_comb begin
        if(lv2_data<lv1_data_2)begin
            addr_o={{2'b00},{lv2_addr}};
        end
        else begin
            addr_o={{lv1_addr_2},{4'b0000}};
        end
    end

endmodule
