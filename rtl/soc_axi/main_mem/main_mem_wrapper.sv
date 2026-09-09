//////////////////////////////////////////////////////////////////////////////////
// Description:     Main memory consisted of multiple SRAM macros
//////////////////////////////////////////////////////////////////////////////////

module main_mem_wrapper #(
    parameter int AXI_ADDR_WIDTH    = 64,
    parameter int AXI_DATA_WIDTH    = 64,
    parameter int AXI_ADDR_OFFSET   = 3,
    parameter int NUM_MACROS        = 16,   // 128KB total memory
    parameter int MACRO_ADDR_WIDTH  = 10,   // 8KB per macro
    parameter int CS_WIDTH          = $clog2(NUM_MACROS)
) (
    input  logic                                clk_i,
    input  logic                                rstn_i,

    // axi2mem interface
    input  logic                                    axi_req_i,
    input  logic                                    axi_write_en_i,
    input  logic [  AXI_ADDR_WIDTH-1:0]    			axi_addr_i,
    input  logic [AXI_DATA_WIDTH/8-1:0]             axi_byte_en_i,
    input  logic [  AXI_DATA_WIDTH-1:0]             axi_wdata_i,
    output logic [  AXI_DATA_WIDTH-1:0]             axi_rdata_o,
    output logic                                    axi_rdata_valid_o
);
    // Time precision & unit
    timeprecision 1ps;
    timeunit 1ps;

	// Internal signals
    logic [AXI_DATA_WIDTH-1:0]                 		main_mem_wdata;
    logic [NUM_MACROS-1:0]                          main_mem_en;
    logic [NUM_MACROS-1:0]                          main_mem_wen;
    logic [MACRO_ADDR_WIDTH-1:0]                    main_mem_addr;
    logic [AXI_DATA_WIDTH/8-1:0][8-1:0]      		bit_mask;
    logic [AXI_DATA_WIDTH/8-1:0]               		byte_mask;

    // SRAM read signal
    logic [NUM_MACROS-1:0][AXI_DATA_WIDTH-1:0]      main_mem_rdata, main_mem_rdata_q, main_mem_rdata_d;
    logic                                           axi_rdata_valid_q, axi_rdata_valid_d;
    logic                                           axi_read_req_q, axi_read_req_d;
    logic [CS_WIDTH-1:0]                            axi_cs_d, axi_cs_q;

    // buf
    always_comb begin
        axi_read_req_d          = 1'b0;
        axi_cs_d                = axi_cs_q;
        if (axi_req_i && !axi_write_en_i) begin
            axi_read_req_d      = 1'b1;
            axi_cs_d            = axi_addr_i[AXI_ADDR_OFFSET+CS_WIDTH+MACRO_ADDR_WIDTH-1 -: CS_WIDTH];
        end
    end

    always_ff@( posedge clk_i or negedge rstn_i ) begin
        if (~rstn_i) begin
            axi_cs_q            <=  '0;
            axi_read_req_q      <=  1'b0;
            main_mem_rdata_q    <=  '0;
            axi_rdata_valid_q   <=  1'b0;
        end else begin
            axi_cs_q            <=  axi_cs_d;
            axi_read_req_q      <=  axi_read_req_d;
            main_mem_rdata_q    <=  main_mem_rdata_d;
            axi_rdata_valid_q   <=  axi_rdata_valid_d;
        end
    end

	// main_mem_rdata -> axi_rdata_o (1 cycle delay)
	always_comb begin
        main_mem_rdata_d         = '0;
        axi_rdata_valid_d        = 1'b0;
        if (axi_read_req_q) begin
            main_mem_rdata_d     = main_mem_rdata;
            axi_rdata_valid_d    = 1'b1;
        end
    end
    assign axi_rdata_o = axi_rdata_valid_q ? main_mem_rdata_q[axi_cs_q] : '0;
    // assign axi_rdata_o = main_mem_rdata[axi_cs_q];
    assign axi_rdata_valid_o = axi_rdata_valid_q;

	// axi_req_i -> main_mem_en
    always_comb begin: generate_en
        main_mem_en                                                                         = '0;
        if(axi_req_i) begin
            main_mem_en                                                                     = '0;
            main_mem_en[axi_addr_i[AXI_ADDR_OFFSET+CS_WIDTH+MACRO_ADDR_WIDTH-1 -: CS_WIDTH]]  = 1'b1;
        end
    end

    // axi_write_en_i -> main_mem_wen
    always_comb begin: generate_wen
        main_mem_wen                                                                        = '0;
        if(axi_req_i) begin
            main_mem_wen                                                                    = '0;
            main_mem_wen[axi_addr_i[AXI_ADDR_OFFSET+CS_WIDTH+MACRO_ADDR_WIDTH-1 -: CS_WIDTH]] = axi_write_en_i;
        end
    end

	// axi_addr_i -> main_mem_addr
	always_comb begin: generate_addr
        main_mem_addr = '0;
        if(axi_req_i) begin
            main_mem_addr = axi_addr_i[AXI_ADDR_OFFSET+MACRO_ADDR_WIDTH-1 -: MACRO_ADDR_WIDTH];
        end
    end

	// axi_wdata_i -> main_mem_wdata
    always_comb begin: generate_wdata
        main_mem_wdata  = '0;
        if(axi_req_i) begin
            // main_mem_wdata[axi_addr_i[AXI_ADDR_OFFSET]] = axi_wdata_i;
            main_mem_wdata = axi_wdata_i;
        end
    end

    assign byte_mask = axi_byte_en_i;
	// byte_mask -> bit_mask
    always_comb begin : generate_bit_mask
        for(int i = 0; i < AXI_DATA_WIDTH/8; i++) begin
            bit_mask[i] = {8{byte_mask[i]}};
        end
    end

	// Generate SRAM
    genvar i;
    generate
        for (i = 0; i < NUM_MACROS; i++) begin : gen_main_mem
            sram_be_1024x64 main_mem_inst (
                .clk_i          ( clk_i             ),
                .chip_enable_i  ( main_mem_en[i]    ),
                .write_enable_i ( main_mem_wen[i]   ),
                .addr_i         ( main_mem_addr     ),
                .write_data_i   ( main_mem_wdata    ),
                .bit_enable_i   ( bit_mask          ),
                .read_data_o    ( main_mem_rdata[i] )
            );

`ifndef SYNTHESIS
            // pragma translate_off
            // Simulation-only SRAM preload; synthesis tools must skip this block.
            initial begin : init_main_mem_from_bin
                localparam string INIT_BIN_DIR   = "../build";
                localparam int unsigned MEM_IDX = i;
                string init_bin_file;
                logic [1000*8-1:0] init_bin_file_arg;
                integer init_bin_fd;

                init_bin_file = $sformatf("%s/init_mem_%0d.bin", INIT_BIN_DIR, MEM_IDX);
                init_bin_file_arg = init_bin_file;
                init_bin_fd = $fopen(init_bin_file, "r");
                if (init_bin_fd != 0) begin
                    $fclose(init_bin_fd);
                    #1;
                    main_mem_inst.sram_inst.loadmem(init_bin_file_arg);
                    $display(
                        "[main_mem_wrapper] Loaded %s into macro %0d.",
                        init_bin_file,
                        MEM_IDX
                    );
                end else begin
                    $display(
                        "[main_mem_wrapper] Warning: init bin file %s not found for macro %0d, skipping preload.",
                        init_bin_file,
                        MEM_IDX
                    );
                end
            end
            // pragma translate_on
`endif
        end

    endgenerate

endmodule
