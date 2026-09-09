//////////////////////////////////////////////////////////////////////////////////
// Description:     Portable SRAM interfaces; generic memory implementation
//////////////////////////////////////////////////////////////////////////////////

module sram_be_1024x64 (
    input  wire        clk_i,
    input  wire        chip_enable_i,
    input  wire        write_enable_i,
    input  wire [ 9:0] addr_i,
    input  wire [63:0] write_data_i,
    input  wire [63:0] bit_enable_i,
    output wire [63:0] read_data_o
);

    wire       ruser_unused;
    wire [7:0] byte_mask;

    assign byte_mask = {
        bit_enable_i[56], bit_enable_i[48], bit_enable_i[40], bit_enable_i[32], bit_enable_i[24], bit_enable_i[16], bit_enable_i[8], bit_enable_i[0]
    };

    sram #(
        .DATA_WIDTH(64),
        .USER_WIDTH(1),
        .USER_EN   (0),
        .NUM_WORDS (1024),
        .SIM_INIT  ("none"),
        .OUT_REGS  (0)
    ) sram_inst (
        .clk_i  (clk_i),
        .rst_ni (1'b1),
        .req_i  (chip_enable_i),
        .we_i   (write_enable_i),
        .addr_i (addr_i),
        .wuser_i('0),
        .wdata_i(write_data_i),
        .be_i   (byte_mask),
        .ruser_o(ruser_unused),
        .rdata_o(read_data_o)
    );

endmodule

module sram_be_128x46 (
    input  wire        clk_i,
    input  wire        chip_enable_i,
    input  wire        write_enable_i,
    input  wire [ 6:0] addr_i,
    input  wire [45:0] write_data_i,
    input  wire [45:0] bit_enable_i,
    output wire [45:0] read_data_o
);

    wire       ruser_unused;
    wire [5:0] byte_mask;

    assign byte_mask = {bit_enable_i[40], bit_enable_i[32], bit_enable_i[24], bit_enable_i[16], bit_enable_i[8], bit_enable_i[0]};

    sram #(
        .DATA_WIDTH(46),
        .USER_WIDTH(1),
        .USER_EN   (0),
        .NUM_WORDS (128),
        .SIM_INIT  ("none"),
        .OUT_REGS  (0)
    ) rf_inst (
        .clk_i  (clk_i),
        .rst_ni (1'b1),
        .req_i  (chip_enable_i),
        .we_i   (write_enable_i),
        .addr_i (addr_i),
        .wuser_i('0),
        .wdata_i(write_data_i),
        .be_i   (byte_mask),
        .ruser_o(ruser_unused),
        .rdata_o(read_data_o)
    );

endmodule

module sram_be_128x128 (
    input  wire         clk_i,
    input  wire         chip_enable_i,
    input  wire         write_enable_i,
    input  wire [  6:0] addr_i,
    input  wire [127:0] write_data_i,
    input  wire [127:0] bit_enable_i,
    output wire [127:0] read_data_o
);

    wire        ruser_unused;
    wire [15:0] byte_mask;

    assign byte_mask = {
        bit_enable_i[120],
        bit_enable_i[112],
        bit_enable_i[104],
        bit_enable_i[96],
        bit_enable_i[88],
        bit_enable_i[80],
        bit_enable_i[72],
        bit_enable_i[64],
        bit_enable_i[56],
        bit_enable_i[48],
        bit_enable_i[40],
        bit_enable_i[32],
        bit_enable_i[24],
        bit_enable_i[16],
        bit_enable_i[8],
        bit_enable_i[0]
    };

    sram #(
        .DATA_WIDTH(128),
        .USER_WIDTH(1),
        .USER_EN   (0),
        .NUM_WORDS (128),
        .SIM_INIT  ("none"),
        .OUT_REGS  (0)
    ) rf_inst (
        .clk_i  (clk_i),
        .rst_ni (1'b1),
        .req_i  (chip_enable_i),
        .we_i   (write_enable_i),
        .addr_i (addr_i),
        .wuser_i('0),
        .wdata_i(write_data_i),
        .be_i   (byte_mask),
        .ruser_o(ruser_unused),
        .rdata_o(read_data_o)
    );

endmodule

module sram_be_64x32 (
    input  wire        clk_i,
    input  wire        chip_enable_i,
    input  wire        write_enable_i,
    input  wire [ 5:0] addr_i,
    input  wire [31:0] write_data_i,
    input  wire [31:0] bit_enable_i,
    output wire [31:0] read_data_o
);

    wire       ruser_unused;
    wire [3:0] byte_mask;
    assign byte_mask = {bit_enable_i[24], bit_enable_i[16], bit_enable_i[8], bit_enable_i[0]};
    sram #(
        .DATA_WIDTH(32),
        .USER_WIDTH(1),
        .USER_EN   (0),
        .NUM_WORDS (64),
        .SIM_INIT  ("none"),
        .OUT_REGS  (0)
    ) sram_inst (
        .clk_i  (clk_i),
        .rst_ni (1'b1),
        .req_i  (chip_enable_i),
        .we_i   (write_enable_i),
        .addr_i (addr_i),
        .wuser_i('0),
        .wdata_i(write_data_i),
        .be_i   (byte_mask),
        .ruser_o(ruser_unused),
        .rdata_o(read_data_o)
    );

endmodule


module sram_be_64x64 (
    input  wire        clk_i,
    input  wire        chip_enable_i,
    input  wire        write_enable_i,
    input  wire [ 5:0] addr_i,
    input  wire [63:0] write_data_i,
    input  wire [63:0] bit_enable_i,
    output wire [63:0] read_data_o
);

    wire       ruser_unused;
    wire [7:0] byte_mask;
    assign byte_mask = {bit_enable_i[56], bit_enable_i[48], bit_enable_i[40], bit_enable_i[32], bit_enable_i[24], bit_enable_i[16], bit_enable_i[8], bit_enable_i[0]};
    sram #(
        .DATA_WIDTH(64),
        .USER_WIDTH(1),
        .USER_EN   (0),
        .NUM_WORDS (64),
        .SIM_INIT  ("none"),
        .OUT_REGS  (0)
    ) sram_inst (
        .clk_i  (clk_i),
        .rst_ni (1'b1),
        .req_i  (chip_enable_i),
        .we_i   (write_enable_i),
        .addr_i (addr_i),
        .wuser_i('0),
        .wdata_i(write_data_i),
        .be_i   (byte_mask),
        .ruser_o(ruser_unused),
        .rdata_o(read_data_o)
    );

endmodule

module sram_64x64 (
    input  wire        clk_i,
    input  wire        chip_enable_i,
    input  wire        write_enable_i,
    input  wire [ 5:0] addr_i,
    input  wire [63:0] write_data_i,
    output wire [63:0] read_data_o
);

    wire ruser_unused;

    sram #(
        .DATA_WIDTH(64),
        .USER_WIDTH(1),
        .USER_EN   (0),
        .NUM_WORDS (64),
        .SIM_INIT  ("none"),
        .OUT_REGS  (0)
    ) sram_inst (
        .clk_i  (clk_i),
        .rst_ni (1'b1),
        .req_i  (chip_enable_i),
        .we_i   (write_enable_i),
        .addr_i (addr_i),
        .wuser_i('0),
        .wdata_i(write_data_i),
        .be_i   ('1),
        .ruser_o(ruser_unused),
        .rdata_o(read_data_o)
    );

endmodule

module sram_256x64 (
    input  wire        clk_i,
    input  wire        chip_enable_i,
    input  wire        write_enable_i,
    input  wire [ 7:0] addr_i,
    input  wire [63:0] write_data_i,
    output wire [63:0] read_data_o
);

    wire ruser_unused;

    sram #(
        .DATA_WIDTH(64),
        .USER_WIDTH(1),
        .USER_EN   (0),
        .NUM_WORDS (256),
        .SIM_INIT  ("none"),
        .OUT_REGS  (0)
    ) sram_inst (
        .clk_i  (clk_i),
        .rst_ni (1'b1),
        .req_i  (chip_enable_i),
        .we_i   (write_enable_i),
        .addr_i (addr_i),
        .wuser_i('0),
        .wdata_i(write_data_i),
        .be_i   ('1),
        .ruser_o(ruser_unused),
        .rdata_o(read_data_o)
    );

endmodule


