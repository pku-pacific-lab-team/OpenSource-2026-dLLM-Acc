//-----------------------------------------------------------------------------
// File: int4x4_mul.sv
// Description: 4-bit x 4-bit multiplier with configurable sign mode.
//              Atomic building block for int4x8_mul and int8x8_mul.
//
//              unsigned_mode=0: signed 4x4 (INT4x4 / INT4x8 PE array modes)
//              unsigned_mode=1: unsigned 4x4 (BF16 mantissa decomposition)
//
//              Implemented via 5-bit signed multiply to handle both modes
//              with a single datapath.
//              Pure combinational.
//-----------------------------------------------------------------------------

module int4x4_mul (
    input  logic [3:0] a_i,
    input  logic [3:0] b_i,
    input  logic       unsigned_mode_i,
    output logic [7:0] prod_o
);

    // Extend to 5-bit signed: zero-extend for unsigned, sign-extend for signed.
    logic signed [4:0] a_ext, b_ext;
    assign a_ext  = unsigned_mode_i ? {1'b0, a_i} : {a_i[3], a_i};
    assign b_ext  = unsigned_mode_i ? {1'b0, b_i} : {b_i[3], b_i};

    // 5x5 signed multiply -> 10 bits; lower 8 bits are correct for both modes.
    //   Unsigned: max 15*15 = 225, fits in 8 unsigned bits.
    //   Signed:   range [-64, 49], fits in 8 signed bits.
    assign prod_o = 8'(a_ext * b_ext);

endmodule
