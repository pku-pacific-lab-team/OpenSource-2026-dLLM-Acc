//-----------------------------------------------------------------------------
// File: token_acc_unit.sv
// Description: Token-level tile-win accumulator for the revised token-promotion backend.
//-----------------------------------------------------------------------------

module token_acc_unit #(
    parameter integer NUM_SEQUENCES   = 8,
    parameter integer NUM_TILES_WIDTH = 5
) (
    input  logic                               clk_i,
    input  logic                               rst_ni,
    input  logic                               token_start_i,
    input  logic                               tile_valid_i,
    input  logic [  $clog2(NUM_SEQUENCES)-1:0] tile_winner_seq_id_i,
    input  logic [        NUM_TILES_WIDTH-1:0] num_tiles_i,
    input  logic [$clog2(NUM_SEQUENCES+1)-1:0] num_seqs_i,
    input  logic [        NUM_TILES_WIDTH-1:0] acc_thres_i,
    output logic                               busy_o,
    output logic                               done_o,
    output logic                               promote_token_o,
    output logic [  $clog2(NUM_SEQUENCES)-1:0] token_max_seq_id_o,
    output logic [        NUM_TILES_WIDTH-1:0] token_max_acc_o,
    output logic [        NUM_TILES_WIDTH-1:0] processed_tile_count_o
);

    localparam integer SEQ_ID_WIDTH = (NUM_SEQUENCES > 1) ? $clog2(NUM_SEQUENCES) : 1;
    localparam integer NUM_SEQS_CFG_WIDTH = (NUM_SEQUENCES > 1) ? $clog2(NUM_SEQUENCES + 1) : 1;
    localparam integer ACC_WIDTH = NUM_TILES_WIDTH + 1;

    logic                                           token_active_d;
    logic                                           token_active_q;
    logic                                           done_d;
    logic                                           done_q;
    logic                                           promote_token_d;
    logic                                           promote_token_q;
    logic   [      SEQ_ID_WIDTH-1:0]                token_max_seq_id_d;
    logic   [      SEQ_ID_WIDTH-1:0]                token_max_seq_id_q;
    logic   [   NUM_TILES_WIDTH-1:0]                token_max_acc_d;
    logic   [   NUM_TILES_WIDTH-1:0]                token_max_acc_q;
    logic   [     NUM_SEQUENCES-1:0][ACC_WIDTH-1:0] token_acc_d;
    logic   [     NUM_SEQUENCES-1:0][ACC_WIDTH-1:0] token_acc_q;
    logic   [   NUM_TILES_WIDTH-1:0]                processed_tile_count_q;
    logic   [   NUM_TILES_WIDTH-1:0]                curr_processed_tile_count;
    logic                                           last_tile;
    logic   [      SEQ_ID_WIDTH-1:0]                max_seq_id;
    logic   [         ACC_WIDTH-1:0]                max_acc;
    logic   [         ACC_WIDTH-1:0]                acc_thres;
    logic   [NUM_SEQS_CFG_WIDTH-1:0]                active_num_seqs;

    integer                                         seq_idx;

    // -------------------------------------------------------------------------
    // Tile-count tracking
    // -------------------------------------------------------------------------

    assign acc_thres                 = {1'b0, acc_thres_i};
    assign curr_processed_tile_count = token_start_i ? '0 : processed_tile_count_q;
    assign last_tile                 = tile_valid_i && (curr_processed_tile_count == num_tiles_i - NUM_TILES_WIDTH'(1));

    always_comb begin
        active_num_seqs = num_seqs_i;

        if (num_seqs_i == '0) begin
            active_num_seqs = NUM_SEQS_CFG_WIDTH'(1);
        end else if (num_seqs_i > NUM_SEQS_CFG_WIDTH'(NUM_SEQUENCES)) begin
            active_num_seqs = NUM_SEQS_CFG_WIDTH'(NUM_SEQUENCES);
        end
    end

    // -------------------------------------------------------------------------
    // Token accumulator next-state
    // -------------------------------------------------------------------------

    always_comb begin

        max_seq_id         = '0;
        max_acc            = '0;
        token_active_d     = token_active_q;
        done_d             = 1'b0;
        promote_token_d    = promote_token_q;
        token_max_seq_id_d = token_max_seq_id_q;
        token_max_acc_d    = token_max_acc_q;
        token_acc_d        = token_acc_q;

        if (token_start_i) begin
            token_active_d     = 1'b1;
            promote_token_d    = 1'b0;
            token_max_seq_id_d = '0;
            token_max_acc_d    = '0;
            token_acc_d        = '0;
        end

        if (tile_valid_i) begin
            token_acc_d[tile_winner_seq_id_i] = token_acc_d[tile_winner_seq_id_i] + ACC_WIDTH'(1);

            if (last_tile) begin
                max_seq_id = '0;
                max_acc    = token_acc_d[0];
                for (seq_idx = 1; seq_idx < NUM_SEQUENCES; seq_idx = seq_idx + 1) begin
                    if ((NUM_SEQS_CFG_WIDTH'(seq_idx) < active_num_seqs) && (token_acc_d[seq_idx] > max_acc)) begin
                        max_acc    = token_acc_d[seq_idx];
                        max_seq_id = SEQ_ID_WIDTH'(seq_idx);
                    end
                end

                token_active_d     = 1'b0;
                done_d             = 1'b1;
                promote_token_d    = (max_acc > acc_thres);
                token_max_seq_id_d = max_seq_id;
                token_max_acc_d    = max_acc[NUM_TILES_WIDTH-1:0];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Token status registers
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            token_active_q     <= 1'b0;
            done_q             <= 1'b0;
            promote_token_q    <= 1'b0;
            token_max_seq_id_q <= '0;
            token_max_acc_q    <= '0;
        end else begin
            token_active_q     <= token_active_d;
            done_q             <= done_d;
            promote_token_q    <= promote_token_d;
            token_max_seq_id_q <= token_max_seq_id_d;
            token_max_acc_q    <= token_max_acc_d;
        end
    end

    // -------------------------------------------------------------------------
    // Per-sequence accumulation state
    // -------------------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            token_acc_q <= '0;
        end else begin
            token_acc_q <= token_acc_d;
        end
    end

    // -------------------------------------------------------------------------
    // Processed-tile counter
    // -------------------------------------------------------------------------

    my_counter #(
        .WIDTH(NUM_TILES_WIDTH)
    ) i_processed_tile_counter (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .enable_i     (tile_valid_i),
        .clear_i      (token_start_i || last_tile),
        .reset_value_i('0),
        .increment_i  (NUM_TILES_WIDTH'(1)),
        .count_o      (processed_tile_count_q)
    );

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------

    assign busy_o                 = token_active_q;
    assign done_o                 = done_q;
    assign promote_token_o        = promote_token_q;
    assign token_max_seq_id_o     = token_max_seq_id_q;
    assign token_max_acc_o        = token_max_acc_q;
    assign processed_tile_count_o = curr_processed_tile_count;

    initial begin : sim_assertions
        forever begin
            @(posedge clk_i);
            if (!rst_ni) continue;

            if (token_start_i) begin
                assert (num_tiles_i != '0)
                else $error("token_acc_unit requires num_tiles_i to be non-zero at token start.");
                assert (num_seqs_i != '0)
                else $error("token_acc_unit requires num_seqs_i to be non-zero at token start.");
                assert (num_seqs_i <= NUM_SEQS_CFG_WIDTH'(NUM_SEQUENCES))
                else $error("token_acc_unit num_seqs_i=%0d exceeds NUM_SEQUENCES=%0d.", num_seqs_i, NUM_SEQUENCES);
                assert (!token_active_q)
                else $error("token_acc_unit received token_start_i while a token was already active.");
            end

            if (tile_valid_i) begin
                assert (token_active_q)
                else $error("token_acc_unit received tile_valid_i without an active token.");
                assert ({{(NUM_SEQS_CFG_WIDTH - SEQ_ID_WIDTH) {1'b0}}, tile_winner_seq_id_i} < active_num_seqs)
                else $error("token_acc_unit tile_winner_seq_id_i=%0d is outside active num_seqs_i=%0d.", tile_winner_seq_id_i, num_seqs_i);
            end
        end
    end

endmodule
