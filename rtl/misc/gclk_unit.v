module gclk_unit (
    input  wire clk_i,
    input  wire en_i,
    input  wire test_en_i,
    output wire gclk_o
);

    reg en_latch;

    always @(clk_i or en_i or test_en_i) begin
        if (!clk_i)
            en_latch <= en_i | test_en_i;
    end

    assign gclk_o = clk_i & en_latch;

endmodule

