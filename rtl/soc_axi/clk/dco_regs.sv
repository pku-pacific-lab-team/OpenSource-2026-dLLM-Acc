//------------------------------------------------------------------------------
// Description: DCO Configuration Registers (axi2mem-style interface)
//------------------------------------------------------------------------------

module dco_regs #(
    parameter int unsigned AXI_ADDR_WIDTH = 64,
    parameter int unsigned AXI_DATA_WIDTH = 64
)(
    input  logic                          clk,
    input  logic                          rst_n,
    output logic [5:0]                    cc_sel_o,
    output logic [5:0]                    fc_sel_o,
    output logic [2:0]                    div_sel_o,
    output logic [1:0]                    freq_sel_o,
    // axi2mem interface
    input  logic                          axi_req_i,
    input  logic                          axi_we_i,
    input  logic [AXI_ADDR_WIDTH-1:0]     axi_addr_i,
    input  logic [AXI_DATA_WIDTH/8-1:0]   axi_be_i,
    input  logic [AXI_DATA_WIDTH-1:0]     axi_wdata_i,
    output logic [AXI_DATA_WIDTH-1:0]     axi_rdata_o
);

    logic [5:0] cc_sel_q;
    logic [5:0] fc_sel_q;
    logic [2:0] div_sel_q;
    logic [1:0] freq_sel_q;

	logic [11:0] axi_addr_q, axi_addr_d;

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			axi_addr_q <= '0;
		end
		else begin
			axi_addr_q <= axi_addr_d;
		end
	end

	always_comb begin
		axi_addr_d = axi_addr_q;
		if (axi_req_i && ~axi_we_i) begin
			axi_addr_d = axi_addr_i[11:0];
		end
	end

    assign cc_sel_o   = cc_sel_q;
    assign fc_sel_o   = fc_sel_q;
    assign div_sel_o  = div_sel_q;
    assign freq_sel_o = freq_sel_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cc_sel_q   <= 6'b111_111;
            fc_sel_q   <= 6'b111_111;
            div_sel_q  <= 3'b100;
            freq_sel_q <= 2'b11;
        end else if (axi_req_i && axi_we_i) begin
            unique case (axi_addr_i[11:0])
                12'h000: cc_sel_q   <= axi_wdata_i[5:0];
                12'h008: fc_sel_q   <= axi_wdata_i[5:0];
                12'h010: div_sel_q  <= axi_wdata_i[2:0];
                12'h018: freq_sel_q <= axi_wdata_i[1:0];
                default: ;
            endcase
        end
    end

    always_comb begin
        unique case (axi_addr_q)
            12'h000: axi_rdata_o = {{(AXI_DATA_WIDTH-6){1'b0}}, cc_sel_q};
            12'h008: axi_rdata_o = {{(AXI_DATA_WIDTH-6){1'b0}}, fc_sel_q};
            12'h010: axi_rdata_o = {{(AXI_DATA_WIDTH-3){1'b0}}, div_sel_q};
            12'h018: axi_rdata_o = {{(AXI_DATA_WIDTH-2){1'b0}}, freq_sel_q};
            default: axi_rdata_o = '0;
        endcase
    end

endmodule
