module mux2_unit (
    input  wire I0,
    input  wire I1,
    input  wire S,
    output wire Zout
);

    assign Zout = (S) ? I1 : I0;

endmodule
