`timescale 1ns / 1ps



module topk_HIT (
    input  logic [3:0] cached_value[5:0],
    input  logic [3:0] query,
    output logic [5:0] HIT_position,
    output logic       HIT
);
    always_comb begin
        HIT_position = 0;
        for (int i = 0; i < 6; i++) begin
            if (query == cached_value[i]) begin
                HIT_position[i] = 1;
                break;
            end
        end
    end
    assign HIT = (|HIT_position);
endmodule
