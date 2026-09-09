//-----------------------------------------------------------------------------
// File: token_promote_tile_score_unit.sv
// Description: Per-tile scoring helper for token-promotion score modes.
//-----------------------------------------------------------------------------

module token_promote_tile_score_unit #(
    parameter integer TILE_SIZE  = 16,
    parameter integer ELEM_WIDTH = 16
) (
    input  logic                                                           clk_i,
    input  logic                                                           rst_ni,
    input  logic                                                           valid_i,
    input  logic        [                             1:0]                 score_mode_i,
    input  logic signed [                   TILE_SIZE-1:0][ELEM_WIDTH-1:0] vec_op_i,
    output logic                                                           valid_o,
    output logic        [ELEM_WIDTH+$clog2(TILE_SIZE)-1:0]                 tile_mag_o
);

    localparam integer TILE_MAG_WIDTH = ELEM_WIDTH + $clog2(TILE_SIZE);
    localparam logic [1:0] TOKEN_PROMOTE_SCORE_MODE_B1 = 2'b00;
    localparam logic [1:0] TOKEN_PROMOTE_SCORE_MODE_B2 = 2'b01;

    typedef logic signed [TILE_MAG_WIDTH-1:0] tile_sum_t;
    typedef logic [TILE_MAG_WIDTH-1:0] tile_mag_t;

    integer    elem_idx;
    logic      valid_q;
    tile_sum_t tile_sum_d;
    tile_mag_t tile_abs_sum_d;
    tile_mag_t tile_mag_d;
    tile_mag_t tile_mag_q;

    function automatic tile_mag_t abs_elem(input logic signed [ELEM_WIDTH-1:0] value_i);
        begin
            abs_elem = value_i[ELEM_WIDTH-1] ? tile_mag_t'($unsigned(-value_i)) : tile_mag_t'($unsigned(value_i));
        end
    endfunction

    function automatic tile_mag_t abs_tile_sum(input tile_sum_t value_i);
        begin
            abs_tile_sum = value_i[TILE_MAG_WIDTH-1] ? $unsigned(-value_i) : $unsigned(value_i);
        end
    endfunction

    function automatic tile_sum_t sign_extend_elem(input logic [ELEM_WIDTH-1:0] value_i);
        begin
            sign_extend_elem = tile_sum_t'({{(TILE_MAG_WIDTH - ELEM_WIDTH) {value_i[ELEM_WIDTH-1]}}, value_i});
        end
    endfunction

    // -------------------------------------------------------------------------
    // Tile scoring datapath
    // -------------------------------------------------------------------------

    always_comb begin
        tile_sum_d     = '0;
        tile_abs_sum_d = '0;
        tile_mag_d     = '0;

        for (elem_idx = 0; elem_idx < TILE_SIZE; elem_idx = elem_idx + 1) begin
            tile_sum_d     = tile_sum_d + sign_extend_elem(vec_op_i[elem_idx]);
            tile_abs_sum_d = tile_abs_sum_d + tile_mag_t'(abs_elem(vec_op_i[elem_idx]));
        end

        case (score_mode_i)
            TOKEN_PROMOTE_SCORE_MODE_B1: tile_mag_d = abs_tile_sum(tile_sum_d);
            TOKEN_PROMOTE_SCORE_MODE_B2: tile_mag_d = tile_abs_sum_d;
            default:                     tile_mag_d = abs_tile_sum(tile_sum_d);
        endcase
    end

    // -------------------------------------------------------------------------
    // Output staging
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            valid_q <= 1'b0;
        end else begin
            valid_q <= valid_i;
        end
    end

    always_ff @(posedge clk_i) begin
        if (valid_i) begin
            tile_mag_q <= tile_mag_d;
        end
    end

    assign valid_o    = valid_q;
    assign tile_mag_o = tile_mag_q;

endmodule
