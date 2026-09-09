//-----------------------------------------------------------------------------
// File: token_promotion_unit.sv
// Date Created: 2026-03-17
// Description: Stateful token-promotion backend for the vector unit.
//-----------------------------------------------------------------------------

module token_promotion_unit #(
    parameter integer NUM_SEQS    = 8,
    parameter integer TILE_SIZE   = 16,
    parameter integer ELEM_WIDTH  = 16,
    parameter integer SHIFT_CFG_W = 4,
    parameter integer TILE_CNT_W  = 5
) (
    input  logic                                                   clk_i,
    input  logic                                                   rst_ni,
    input  logic                                                   valid_i,
    input  logic                                                   token_start_i,
    input  logic signed [           TILE_SIZE-1:0][ELEM_WIDTH-1:0] vec_op_i,
    input  logic        [                    15:0]                 shared_exp_i,
    input  logic        [                     1:0]                 score_mode_i,
    input  logic        [NUM_SEQS*SHIFT_CFG_W-1:0]                 shift_cfg_i,
    input  logic        [          TILE_CNT_W-1:0]                 num_tiles_i,
    input  logic        [  $clog2(NUM_SEQS+1)-1:0]                 num_seqs_i,
    input  logic        [          TILE_CNT_W-1:0]                 acc_thres_i,
    output logic                                                   ready_o,
    output logic                                                   busy_o,
    output logic                                                   instr_done_o,
    output logic                                                   done_o,
    output logic                                                   promote_token_o,
    output logic        [    $clog2(NUM_SEQS)-1:0]                 token_max_seq_id_o,
    output logic        [          TILE_CNT_W-1:0]                 token_max_acc_o,
    output logic        [    $clog2(NUM_SEQS)-1:0]                 seq_idx_o,
    output logic        [          TILE_CNT_W-1:0]                 tile_idx_o,
    output logic        [          TILE_CNT_W-1:0]                 processed_tile_count_o
);

    localparam integer PSUM_WIDTH = ELEM_WIDTH + $clog2(TILE_SIZE);
    localparam integer NUM_SEQS_CFG_W = (NUM_SEQS > 1) ? $clog2(NUM_SEQS + 1) : 1;
    localparam logic [1:0] TOKEN_PROMOTE_SCORE_MODE_B1 = 2'b00;
    localparam logic [1:0] TOKEN_PROMOTE_SCORE_MODE_B2 = 2'b01;

    logic stage0_token_start_d, stage0_token_start_q;
    logic [15:0] stage0_exp_d, stage0_exp_q;
    logic [1:0] token_score_mode_d, token_score_mode_q;
    logic token_mode_active_d, token_mode_active_q;
    logic [                 1:0] active_score_mode;
    logic                        tile_score_valid;
    logic [      PSUM_WIDTH-1:0] tile_mag;
    logic                        tile_done;
    logic [$clog2(NUM_SEQS)-1:0] tile_winner_seq_id;

    function automatic logic score_mode_supported(input logic [1:0] score_mode_value_i);
        begin
            score_mode_supported = (score_mode_value_i == TOKEN_PROMOTE_SCORE_MODE_B1) || (score_mode_value_i == TOKEN_PROMOTE_SCORE_MODE_B2);
        end
    endfunction

    function automatic logic [1:0] normalize_score_mode(input logic [1:0] score_mode_value_i);
        begin
            case (score_mode_value_i)
                TOKEN_PROMOTE_SCORE_MODE_B2: normalize_score_mode = TOKEN_PROMOTE_SCORE_MODE_B2;
                default:                     normalize_score_mode = TOKEN_PROMOTE_SCORE_MODE_B1;
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // Stage 0 input capture
    // -------------------------------------------------------------------------

    always_comb begin
        stage0_token_start_d = valid_i ? token_start_i : 1'b0;
        stage0_exp_d         = valid_i ? shared_exp_i : stage0_exp_q;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            stage0_token_start_q <= 1'b0;
        end else begin
            stage0_token_start_q <= stage0_token_start_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            stage0_exp_q <= '0;
        end else begin
            stage0_exp_q <= stage0_exp_d;
        end
    end

    // -------------------------------------------------------------------------
    // Token score-mode tracking
    // -------------------------------------------------------------------------

    always_comb begin
        token_score_mode_d  = token_score_mode_q;
        token_mode_active_d = token_mode_active_q;

        if (done_o) begin
            token_mode_active_d = 1'b0;
        end

        if (valid_i && token_start_i) begin
            token_score_mode_d  = score_mode_i;
            token_mode_active_d = 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            token_score_mode_q  <= TOKEN_PROMOTE_SCORE_MODE_B1;
            token_mode_active_q <= 1'b0;
        end else begin
            token_score_mode_q  <= token_score_mode_d;
            token_mode_active_q <= token_mode_active_d;
        end
    end

    // -------------------------------------------------------------------------
    // Tile scoring
    // -------------------------------------------------------------------------

    assign active_score_mode = normalize_score_mode(token_start_i ? score_mode_i : token_score_mode_q);

    token_promote_tile_score_unit #(
        .TILE_SIZE (TILE_SIZE),
        .ELEM_WIDTH(ELEM_WIDTH)
    ) i_token_promote_tile_score_unit (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .valid_i     (valid_i),
        .score_mode_i(active_score_mode),
        .vec_op_i    (vec_op_i),
        .valid_o     (tile_score_valid),
        .tile_mag_o  (tile_mag)
    );

    // -------------------------------------------------------------------------
    // Tile winner tracking
    // -------------------------------------------------------------------------

    max_tile_update_unit #(
        .NUM_SEQUENCES    (NUM_SEQS),
        .PSUM_WIDTH       (PSUM_WIDTH),
        .SHIFT_WIDTH_WIDTH(SHIFT_CFG_W),
        .NUM_TILES_WIDTH  (TILE_CNT_W)
    ) i_max_tile_update_unit (
        .clk_i               (clk_i),
        .rst_ni              (rst_ni),
        .token_start_i       (stage0_token_start_q),
        .contrib_valid_i     (tile_score_valid),
        .tile_mag_i          (tile_mag),
        .shared_exp_i        (stage0_exp_q),
        .shift_cfg_i         (shift_cfg_i),
        .num_seqs_i          (num_seqs_i),
        .tile_done_o         (tile_done),
        .tile_winner_seq_id_o(tile_winner_seq_id),
        .seq_idx_o           (seq_idx_o),
        .tile_idx_o          (tile_idx_o)
    );

    // -------------------------------------------------------------------------
    // Token accumulation
    // -------------------------------------------------------------------------

    token_acc_unit #(
        .NUM_SEQUENCES  (NUM_SEQS),
        .NUM_TILES_WIDTH(TILE_CNT_W)
    ) i_token_acc_unit (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),
        .token_start_i         (token_start_i),
        .tile_valid_i          (tile_done),
        .tile_winner_seq_id_i  (tile_winner_seq_id),
        .num_tiles_i           (num_tiles_i),
        .num_seqs_i            (num_seqs_i),
        .acc_thres_i           (acc_thres_i),
        .busy_o                (busy_o),
        .done_o                (done_o),
        .promote_token_o       (promote_token_o),
        .token_max_seq_id_o    (token_max_seq_id_o),
        .token_max_acc_o       (token_max_acc_o),
        .processed_tile_count_o(processed_tile_count_o)
    );

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------

    assign ready_o      = 1'b1;
    assign instr_done_o = tile_score_valid;

    initial begin : sim_assertions
        forever begin
            @(posedge clk_i);

            if (valid_i) begin
                if (!ready_o) begin
                    $error("token_promotion_unit received valid_i while not ready.");
                end

                if (token_start_i) begin
                    if (!score_mode_supported(score_mode_i)) begin
                        $error("token_promotion_unit received unsupported score_mode_i=%0b. Falling back to B1.", score_mode_i);
                    end
                    if (num_seqs_i == '0) begin
                        $error("token_promotion_unit requires num_seqs_i to be non-zero at token start.");
                    end
                    if (num_seqs_i > NUM_SEQS_CFG_W'(NUM_SEQS)) begin
                        $error("token_promotion_unit num_seqs_i=%0d exceeds NUM_SEQS=%0d.", num_seqs_i, NUM_SEQS);
                    end
                end else if (token_mode_active_q) begin
                    if (score_mode_i != token_score_mode_q) begin
                        $error("token_promotion_unit score_mode_i changed mid-token: latched=%0b current=%0b. Continuing with latched mode.",
                               token_score_mode_q, score_mode_i);
                    end
                end else begin
                    $error("token_promotion_unit received non-start contribution without an active token.");
                end
            end
        end
    end

endmodule
