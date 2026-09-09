//-----------------------------------------------------------------------------
// File: max_tile_update_unit.sv
// Description: Tile-level winner tracker for the revised token-promotion backend.
//-----------------------------------------------------------------------------

module max_tile_update_unit #(
    parameter integer NUM_SEQUENCES     = 8,
    parameter integer PSUM_WIDTH        = 21,
    parameter integer SHIFT_WIDTH_WIDTH = 4,
    parameter integer NUM_TILES_WIDTH   = 5
) (
    input  logic                                       clk_i,
    input  logic                                       rst_ni,
    input  logic                                       token_start_i,
    input  logic                                       contrib_valid_i,
    input  logic [                     PSUM_WIDTH-1:0] tile_mag_i,
    input  logic [                               15:0] shared_exp_i,
    input  logic [NUM_SEQUENCES*SHIFT_WIDTH_WIDTH-1:0] shift_cfg_i,
    input  logic [        $clog2(NUM_SEQUENCES+1)-1:0] num_seqs_i,
    output logic                                       tile_done_o,
    output logic [          $clog2(NUM_SEQUENCES)-1:0] tile_winner_seq_id_o,
    output logic [          $clog2(NUM_SEQUENCES)-1:0] seq_idx_o,
    output logic [                NUM_TILES_WIDTH-1:0] tile_idx_o
);

    localparam integer SEQ_ID_WIDTH = (NUM_SEQUENCES > 1) ? $clog2(NUM_SEQUENCES) : 1;
    localparam integer NUM_SEQS_CFG_WIDTH = (NUM_SEQUENCES > 1) ? $clog2(NUM_SEQUENCES + 1) : 1;
    localparam integer SHARED_EXP_WIDTH = 16;
    localparam integer EFFECTIVE_EXP_OPERAND_WIDTH = ((SHARED_EXP_WIDTH + 1) > SHIFT_WIDTH_WIDTH) ? (SHARED_EXP_WIDTH + 1) : SHIFT_WIDTH_WIDTH;
    localparam integer SEQ_IDX_O_WIDTH = $bits(seq_idx_o);
    localparam integer EFFECTIVE_EXP_WIDTH = EFFECTIVE_EXP_OPERAND_WIDTH + 1;
    localparam logic signed [EFFECTIVE_EXP_WIDTH-1:0] MIN_EFFECTIVE_EXP = {1'b1, {(EFFECTIVE_EXP_WIDTH - 1) {1'b0}}};

    logic        [ NUM_SEQS_CFG_WIDTH-1:0] active_num_seqs;
    logic        [       SEQ_ID_WIDTH-1:0] last_seq_idx;
    logic signed [  SHIFT_WIDTH_WIDTH-1:0] seq_shift;
    logic signed [EFFECTIVE_EXP_WIDTH-1:0] shared_exp_ext;
    logic signed [EFFECTIVE_EXP_WIDTH-1:0] seq_shift_ext;
    logic signed [EFFECTIVE_EXP_WIDTH-1:0] effective_exp;
    logic        [       SEQ_ID_WIDTH-1:0] curr_seq_idx;
    logic        [    NUM_TILES_WIDTH-1:0] curr_tile_idx;
    logic                                  last_seq;

    logic [SEQ_ID_WIDTH-1:0] seq_idx_d, seq_idx_q;
    logic [NUM_TILES_WIDTH-1:0] tile_idx_d, tile_idx_q;

    logic signed [EFFECTIVE_EXP_WIDTH-1:0] best_effective_exp_d, best_effective_exp_q;
    logic signed [EFFECTIVE_EXP_WIDTH-1:0] temp_effective_exp;
    logic [PSUM_WIDTH-1:0] best_mag_d, best_mag_q;
    logic [PSUM_WIDTH-1:0] temp_mag;
    logic [SEQ_ID_WIDTH-1:0] best_seq_id_d, best_seq_id_q;
    logic [SEQ_ID_WIDTH-1:0] temp_seq_id;
    logic tile_done_d, tile_done_q;
    logic [SEQ_ID_WIDTH-1:0] tile_winner_seq_id_d, tile_winner_seq_id_q;

    function automatic logic candidate_better(input logic signed [EFFECTIVE_EXP_WIDTH-1:0] cand_exp_i, input logic [PSUM_WIDTH-1:0] cand_mag_i,
                                              input logic signed [EFFECTIVE_EXP_WIDTH-1:0] best_exp_i, input logic [PSUM_WIDTH-1:0] best_mag_i);
        begin
            // V1 compare rule:
            // 1. Larger effective exponent wins, where effective_exp = shared_exp + signed(seq_shift)
            // 2. Ties on effective exponent break toward larger tile magnitude
            // 3. Full ties keep the earlier sequence ID
            candidate_better = (cand_exp_i > best_exp_i) || ((cand_exp_i == best_exp_i) && (cand_mag_i > best_mag_i));
        end
    endfunction

    // -------------------------------------------------------------------------
    // Candidate effective-exponent and magnitude evaluation
    // -------------------------------------------------------------------------

    always_comb begin
        active_num_seqs = num_seqs_i;

        if (num_seqs_i == '0) begin
            active_num_seqs = NUM_SEQS_CFG_WIDTH'(1);
        end else if (num_seqs_i > NUM_SEQS_CFG_WIDTH'(NUM_SEQUENCES)) begin
            active_num_seqs = NUM_SEQS_CFG_WIDTH'(NUM_SEQUENCES);
        end
    end

    assign curr_seq_idx   = token_start_i ? '0 : seq_idx_q;
    assign curr_tile_idx  = token_start_i ? '0 : tile_idx_q;
    assign last_seq_idx   = SEQ_ID_WIDTH'(active_num_seqs - NUM_SEQS_CFG_WIDTH'(1));
    assign last_seq       = contrib_valid_i && (curr_seq_idx == last_seq_idx);

    assign seq_shift      = shift_cfg_i[curr_seq_idx*SHIFT_WIDTH_WIDTH+:SHIFT_WIDTH_WIDTH];
    assign shared_exp_ext = $signed({{(EFFECTIVE_EXP_WIDTH - SHARED_EXP_WIDTH - 1) {1'b0}}, 1'b0, shared_exp_i});
    assign seq_shift_ext  = $signed({{(EFFECTIVE_EXP_WIDTH - SHIFT_WIDTH_WIDTH) {seq_shift[SHIFT_WIDTH_WIDTH-1]}}, seq_shift});
    assign effective_exp  = shared_exp_ext + seq_shift_ext;

    // -------------------------------------------------------------------------
    // Tile winner next-state
    // -------------------------------------------------------------------------

    always_comb begin
        best_effective_exp_d = best_effective_exp_q;
        best_mag_d           = best_mag_q;
        best_seq_id_d        = best_seq_id_q;
        tile_done_d          = 1'b0;
        tile_winner_seq_id_d = tile_winner_seq_id_q;

        temp_effective_exp   = token_start_i ? MIN_EFFECTIVE_EXP : best_effective_exp_q;
        temp_mag             = token_start_i ? '0 : best_mag_q;
        temp_seq_id          = token_start_i ? '0 : best_seq_id_q;

        if (contrib_valid_i) begin
            if (candidate_better(effective_exp, tile_mag_i, temp_effective_exp, temp_mag)) begin
                temp_effective_exp = effective_exp;
                temp_mag           = tile_mag_i;
                temp_seq_id        = curr_seq_idx;
            end

            if (last_seq) begin
                tile_done_d          = 1'b1;
                tile_winner_seq_id_d = temp_seq_id;
                best_effective_exp_d = MIN_EFFECTIVE_EXP;
                best_mag_d           = '0;
                best_seq_id_d        = '0;
            end else begin
                best_effective_exp_d = temp_effective_exp;
                best_mag_d           = temp_mag;
                best_seq_id_d        = temp_seq_id;
            end
        end else if (token_start_i) begin
            best_effective_exp_d = MIN_EFFECTIVE_EXP;
            best_mag_d           = '0;
            best_seq_id_d        = '0;
        end
    end

    // -------------------------------------------------------------------------
    // Tile completion status
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            tile_done_q          <= 1'b0;
            tile_winner_seq_id_q <= '0;
        end else begin
            tile_done_q          <= tile_done_d;
            tile_winner_seq_id_q <= tile_winner_seq_id_d;
        end
    end

    // -------------------------------------------------------------------------
    // Running tile winner datapath
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            best_effective_exp_q <= MIN_EFFECTIVE_EXP;
            best_mag_q           <= '0;
            best_seq_id_q        <= '0;
        end else begin
            best_effective_exp_q <= best_effective_exp_d;
            best_mag_q           <= best_mag_d;
            best_seq_id_q        <= best_seq_id_d;
        end
    end

    // -------------------------------------------------------------------------
    // Sequence and tile counters
    // -------------------------------------------------------------------------

    always_comb begin
        seq_idx_d  = seq_idx_q;
        tile_idx_d = tile_idx_q;

        if (token_start_i) begin
            seq_idx_d  = '0;
            tile_idx_d = '0;
        end

        if (contrib_valid_i) begin
            if (last_seq) begin
                seq_idx_d  = '0;
                tile_idx_d = curr_tile_idx + NUM_TILES_WIDTH'(1);
            end else begin
                seq_idx_d  = curr_seq_idx + SEQ_ID_WIDTH'(1);
                tile_idx_d = curr_tile_idx;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            seq_idx_q  <= '0;
            tile_idx_q <= '0;
        end else begin
            seq_idx_q  <= seq_idx_d;
            tile_idx_q <= tile_idx_d;
        end
    end

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------

    assign tile_done_o          = tile_done_q;
    assign tile_winner_seq_id_o = tile_winner_seq_id_q;
    assign seq_idx_o            = SEQ_IDX_O_WIDTH'(curr_seq_idx);
    assign tile_idx_o           = curr_tile_idx;

    initial begin : sim_assertions
        forever begin
            @(posedge clk_i);
            if (!rst_ni) continue;

            if (token_start_i) begin
                assert (num_seqs_i != '0)
                else $error("max_tile_update_unit requires num_seqs_i to be non-zero at token start.");
                assert (num_seqs_i <= NUM_SEQS_CFG_WIDTH'(NUM_SEQUENCES))
                else $error("max_tile_update_unit num_seqs_i=%0d exceeds NUM_SEQUENCES=%0d.", num_seqs_i, NUM_SEQUENCES);
                assert (!contrib_valid_i || (curr_seq_idx == '0))
                else $error("max_tile_update_unit expected token_start_i to align with the first sequence.");
            end

            if (contrib_valid_i) begin
                assert (num_seqs_i != '0)
                else $error("max_tile_update_unit requires num_seqs_i to be non-zero during contribution processing.");
                assert (num_seqs_i <= NUM_SEQS_CFG_WIDTH'(NUM_SEQUENCES))
                else $error("max_tile_update_unit num_seqs_i=%0d exceeds NUM_SEQUENCES=%0d.", num_seqs_i, NUM_SEQUENCES);
                assert ({{(NUM_SEQS_CFG_WIDTH - SEQ_ID_WIDTH) {1'b0}}, curr_seq_idx} < active_num_seqs)
                else $error("max_tile_update_unit curr_seq_idx=%0d is outside active num_seqs_i=%0d.", curr_seq_idx, num_seqs_i);
            end
        end
    end

endmodule
