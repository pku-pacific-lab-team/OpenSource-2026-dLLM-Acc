module mux4_unit (
    input  wire I0,
    input  wire I1,
    input  wire I2,
    input  wire I3,
    input  wire S0,
    input  wire S1,
    output wire Zout
);

    assign Zout = (S1) ? ((S0) ? I3 : I2) : ((S0) ? I1 : I0);

endmodule
