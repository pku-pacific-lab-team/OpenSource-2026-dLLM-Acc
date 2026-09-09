// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Description: Portable digital SoC with an externally supplied system clock
// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// Modified for accelerator SoC integration and an external system clock.

`include "axi_typedef.svh"
`include "axi_assign.svh"
`include "reg_typedef.svh"
`include "reg_assign.svh"

module soc (
    input   logic       sys_clk_i,
    input   logic       rstn_i,
    output  logic       clk_led_o,

    // JTAG
    input   logic       jtag_tck_i,
    input   logic       jtag_tms_i,
    input   logic       jtag_tdi_i,
    output  logic       jtag_tdo_o,

    // UART
    input   logic       uart_rx_i,
    output  logic       uart_tx_o
);

// on-chip clock
logic clk;

// CVA6 config
localparam bit IsRVFI = bit'(0);
localparam config_pkg::cva6_cfg_t CVA6Cfg = '{
    NrCommitPorts:         cva6_config_pkg::CVA6ConfigNrCommitPorts                              ,
    AxiAddrWidth:          cva6_config_pkg::CVA6ConfigAxiAddrWidth                               ,
    AxiDataWidth:          cva6_config_pkg::CVA6ConfigAxiDataWidth                               ,
    AxiIdWidth:            cva6_config_pkg::CVA6ConfigAxiIdWidth                                 ,
    AxiUserWidth:          cva6_config_pkg::CVA6ConfigDataUserWidth                              ,
    NrLoadBufEntries:      cva6_config_pkg::CVA6ConfigNrLoadBufEntries                           ,
    RASDepth:              cva6_config_pkg::CVA6ConfigRASDepth                                   ,
    BTBEntries:            cva6_config_pkg::CVA6ConfigBTBEntries                                 ,
    BHTEntries:            cva6_config_pkg::CVA6ConfigBHTEntries                                 ,
    FpuEn:                 bit'(cva6_config_pkg::CVA6ConfigFpuEn)                                ,
    XF16:                  bit'(cva6_config_pkg::CVA6ConfigF16En)                                ,
    XF16ALT:               bit'(cva6_config_pkg::CVA6ConfigF16AltEn)                             ,
    XF8:                   bit'(cva6_config_pkg::CVA6ConfigF8En)                                 ,
    RVA:                   bit'(cva6_config_pkg::CVA6ConfigAExtEn)                               ,
    RVV:                   bit'(cva6_config_pkg::CVA6ConfigVExtEn)                               ,
    RVC:                   bit'(cva6_config_pkg::CVA6ConfigCExtEn)                               ,
    RVZCB:                 bit'(cva6_config_pkg::CVA6ConfigZcbExtEn)                             ,
    XFVec:                 bit'(cva6_config_pkg::CVA6ConfigFVecEn)                               ,
    CvxifEn:               bit'(cva6_config_pkg::CVA6ConfigCvxifEn)                              ,
    ZiCondExtEn:           bit'(0)                                                               ,
    RVF:                   bit'(0)                                                               ,
    RVD:                   bit'(0)                                                               ,
    FpPresent:             bit'(0)                                                               ,
    NSX:                   bit'(0)                                                               ,
    FLen:                  unsigned'(0)                                                          ,
    RVFVec:                bit'(0)                                                               ,
    XF16Vec:               bit'(0)                                                               ,
    XF16ALTVec:            bit'(0)                                                               ,
    XF8Vec:                bit'(0)                                                               ,
    NrRgprPorts:           unsigned'(0)                                                          ,
    NrWbPorts:             unsigned'(0)                                                          ,
    EnableAccelerator:     bit'(0)                                                               ,
    RVS:                   bit'(1)                                                               ,
    RVU:                   bit'(1)                                                               ,
    HaltAddress:           dm::HaltAddress                                                       ,
    ExceptionAddress:      dm::ExceptionAddress                                                  ,
    DmBaseAddress:         soc_pkg::DebugBase                                                    ,
    NrPMPEntries:          unsigned'(cva6_config_pkg::CVA6ConfigNrPMPEntries)                    ,
    NOCType:               config_pkg::NOC_TYPE_AXI4_ATOP                                        ,
    // idempotent region
    NrNonIdempotentRules:  unsigned'(1)                                                          ,
    NonIdempotentAddrBase: 1024'({64'b0})                                                        ,
    NonIdempotentLength:   1024'({64'b0})                                                        ,
    NrExecuteRegionRules:  unsigned'(3)                                                          ,
    ExecuteRegionAddrBase: 1024'({soc_pkg::SRAMBase,   soc_pkg::ROMBase,   soc_pkg::DebugBase})  ,
    ExecuteRegionLength:   1024'({soc_pkg::SRAMLength, soc_pkg::ROMLength, soc_pkg::DebugLength}),
    // cached region
    NrCachedRegionRules:   unsigned'(1)                                                          ,
    CachedRegionAddrBase:  1024'({soc_pkg::SRAMBase})                                            ,
    CachedRegionLength:    1024'({soc_pkg::SRAMLength})                                          ,
    MaxOutstandingStores:  unsigned'(7)                                                          ,
    DebugEn: bit'(1)                                                                             ,
    NonIdemPotenceEn: bit'(0)                                                                    ,
    AxiBurstWriteEn: bit'(0)
};

localparam type rvfi_instr_t = logic;

localparam NumWords         = 16384                             ;
localparam NBSlave          = 4                                 ; // debug, cpu, vu0-dma, vu1-dma
localparam AxiAddrWidth     = 64                                ;
localparam AxiDataWidth     = 64                                ;
localparam AxiIdWidthMaster = 4                                 ;
localparam AxiIdWidthSlaves = AxiIdWidthMaster + $clog2(NBSlave); // 5
localparam AxiUserWidth     = ariane_pkg::AXI_USER_WIDTH        ;
localparam AxiUserEn        = ariane_pkg::AXI_USER_EN           ;

`AXI_TYPEDEF_ALL(axi_slave,
                 logic [    AxiAddrWidth-1:0],
                 logic [AxiIdWidthSlaves-1:0],
                 logic [    AxiDataWidth-1:0],
                 logic [(AxiDataWidth/8)-1:0],
                 logic [    AxiUserWidth-1:0])

AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthMaster ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) slave[NBSlave-1:0]();

AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) master[soc_pkg::NB_PERIPHERALS-1:0]();

// disable test-enable
logic test_en             ;
logic ndmreset            ;
logic ndmreset_n          ;
logic debug_req_irq       ;
logic timer_irq           ;
logic ipi                 ;
logic rtc                 ;
logic pll_locked          ;
assign pll_locked = rstn_i;


// ROM
 logic                    rom_req  ;
 logic [AxiAddrWidth-1:0] rom_addr ;
 logic [AxiDataWidth-1:0] rom_rdata;

// Debug
logic          debug_req_valid ;
logic          debug_req_ready ;
dm::dmi_req_t  debug_req       ;
logic          debug_resp_valid;
logic          debug_resp_ready;
dm::dmi_resp_t debug_resp      ;

logic dmactive;

// IRQ
logic [1:0] irq                ;
assign test_en    = 1'b0       ;

rstgen i_rstgen_main (
    .clk_i        ( clk                      ),
    .rst_ni       ( pll_locked & (~ndmreset) ),
    .test_mode_i  ( test_en                  ),
    .rst_no       ( ndmreset_n               ),
    .init_no      (                          ) // keep open
);


// ---------------
// AXI Xbar
// ---------------
axi_pkg::xbar_rule_64_t [soc_pkg::NB_PERIPHERALS-1:0] addr_map;

assign addr_map = '{
    '{ idx: soc_pkg::Debug,    start_addr: soc_pkg::DebugBase,    end_addr: soc_pkg::DebugBase     + soc_pkg::DebugLength    },
    '{ idx: soc_pkg::ROM,      start_addr: soc_pkg::ROMBase,      end_addr: soc_pkg::ROMBase       + soc_pkg::ROMLength      },
    '{ idx: soc_pkg::CLINT,    start_addr: soc_pkg::CLINTBase,    end_addr: soc_pkg::CLINTBase     + soc_pkg::CLINTLength    },
    '{ idx: soc_pkg::PLIC,     start_addr: soc_pkg::PLICBase,     end_addr: soc_pkg::PLICBase      + soc_pkg::PLICLength     },
    '{ idx: soc_pkg::UART,     start_addr: soc_pkg::UARTBase,     end_addr: soc_pkg::UARTBase      + soc_pkg::UARTLength     },
    '{ idx: soc_pkg::Timer,    start_addr: soc_pkg::TimerBase,    end_addr: soc_pkg::TimerBase     + soc_pkg::TimerLength    },
    '{ idx: soc_pkg::SysDCO,   start_addr: soc_pkg::SysDCOBase,   end_addr: soc_pkg::SysDCOBase    + soc_pkg::SysDCOLength   },
    '{ idx: soc_pkg::SysPLL,   start_addr: soc_pkg::SysPLLBase,   end_addr: soc_pkg::SysPLLBase    + soc_pkg::SysPLLLength   },
    '{ idx: soc_pkg::DLLMAcc,  start_addr: soc_pkg::DLLMAccBase,  end_addr: soc_pkg::DLLMAccBase   + soc_pkg::DLLMAccLength  },
    '{ idx: soc_pkg::VU0,      start_addr: soc_pkg::VU0Base,      end_addr: soc_pkg::VU0Base       + soc_pkg::VU0Length      },
    '{ idx: soc_pkg::VU1,      start_addr: soc_pkg::VU1Base,      end_addr: soc_pkg::VU1Base       + soc_pkg::VU1Length      },
    '{ idx: soc_pkg::SRAM,     start_addr: soc_pkg::SRAMBase,     end_addr: soc_pkg::SRAMBase      + soc_pkg::SRAMLength     }
};

localparam axi_pkg::xbar_cfg_t AXI_XBAR_CFG = '{
    NoSlvPorts:         soc_pkg::NrSlaves      ,
    NoMstPorts:         soc_pkg::NB_PERIPHERALS,
    MaxMstTrans:        4                      , // Probably requires update
    MaxSlvTrans:        1                      , // Probably requires update
    FallThrough:        1'b0                   ,
    LatencyMode:        axi_pkg::CUT_ALL_PORTS ,
    AxiIdWidthSlvPorts: AxiIdWidthMaster       ,
    AxiIdUsedSlvPorts:  AxiIdWidthMaster       ,
    UniqueIds:          1'b0                   ,
    AxiAddrWidth:       AxiAddrWidth           ,
    AxiDataWidth:       AxiDataWidth           ,
    NoAddrRules:        soc_pkg::NB_PERIPHERALS
};

axi_xbar_intf #(
    .AXI_USER_WIDTH ( AxiUserWidth            ),
    .Cfg            ( AXI_XBAR_CFG            ),
    .rule_t         ( axi_pkg::xbar_rule_64_t )
) i_axi_xbar (
    .clk_i                 ( clk        ),
    .rst_ni                ( ndmreset_n ),
    .test_i                ( test_en    ),
    .slv_ports             ( slave      ),
    .mst_ports             ( master     ),
    .addr_map_i            ( addr_map   ),
    .en_default_mst_port_i ( '0         ),
    .default_mst_port_i    ( '0         )
);


// ---------------
// Debug Module
// ---------------
dmi_jtag i_dmi_jtag (
    .clk_i                ( clk              ),
    .rst_ni               ( rstn_i           ),
    .dmi_rst_no           (                  ), // keep open
    .testmode_i           ( test_en          ),
    .dmi_req_valid_o      ( debug_req_valid  ),
    .dmi_req_ready_i      ( debug_req_ready  ),
    .dmi_req_o            ( debug_req        ),
    .dmi_resp_valid_i     ( debug_resp_valid ),
    .dmi_resp_ready_o     ( debug_resp_ready ),
    .dmi_resp_i           ( debug_resp       ),
    .tck_i                ( jtag_tck_i       ),
    .tms_i                ( jtag_tms_i       ),
    .trst_ni              ( rstn_i           ),
    .td_i                 ( jtag_tdi_i       ),
    .td_o                 ( jtag_tdo_o       ),
    .tdo_oe_o             (                  )
);

ariane_axi::req_t    dm_axi_m_req           ;
ariane_axi::resp_t   dm_axi_m_resp          ;

logic                      dm_slave_req     ;
logic                      dm_slave_we      ;
logic [riscv::XLEN-1:0]    dm_slave_addr    ;
logic [riscv::XLEN/8-1:0]  dm_slave_be      ;
logic [riscv::XLEN-1:0]    dm_slave_wdata   ;
logic [riscv::XLEN-1:0]    dm_slave_rdata   ;

logic                      dm_master_req    ;
logic [riscv::XLEN-1:0]    dm_master_add    ;
logic                      dm_master_we     ;
logic [riscv::XLEN-1:0]    dm_master_wdata  ;
logic [riscv::XLEN/8-1:0]  dm_master_be     ;
logic                      dm_master_gnt    ;
logic                      dm_master_r_valid;
logic [riscv::XLEN-1:0]    dm_master_r_rdata;

// debug module
logic [63:0] dm_usr  ;
assign dm_usr = 64'b0;

dm_top #(
    .NrHarts          ( 1                           ),
    .BusWidth         ( riscv::XLEN                 ),
    .SelectableHarts  ( 1'b1                        )
) i_dm_top (
    .clk_i            ( clk                         ),
    .rst_ni           ( rstn_i                      ), // PoR
    .testmode_i       ( test_en                     ),
    .ndmreset_o       ( ndmreset                    ),
    .dmactive_o       ( dmactive                    ), // active debug session
    .debug_req_o      ( debug_req_irq               ),
    .unavailable_i    ( '0                          ),
    .hartinfo_i       ( {ariane_pkg::DebugHartInfo} ),
    .slave_req_i      ( dm_slave_req                ),
    .slave_we_i       ( dm_slave_we                 ),
    .slave_addr_i     ( dm_slave_addr               ),
    .slave_be_i       ( dm_slave_be                 ),
    .slave_wdata_i    ( dm_slave_wdata              ),
    .slave_rdata_o    ( dm_slave_rdata              ),
    .master_req_o     ( dm_master_req               ),
    .master_add_o     ( dm_master_add               ),
    .master_we_o      ( dm_master_we                ),
    .master_wdata_o   ( dm_master_wdata             ),
    .master_be_o      ( dm_master_be                ),
    .master_gnt_i     ( dm_master_gnt               ),
    .master_r_valid_i ( dm_master_r_valid           ),
    .master_r_rdata_i ( dm_master_r_rdata           ),
    .dmi_rst_ni       ( rstn_i                      ),
    .dmi_req_valid_i  ( debug_req_valid             ),
    .dmi_req_ready_o  ( debug_req_ready             ),
    .dmi_req_i        ( debug_req                   ),
    .dmi_resp_valid_o ( debug_resp_valid            ),
    .dmi_resp_ready_i ( debug_resp_ready            ),
    .dmi_resp_o       ( debug_resp                  )
);

axi2mem #(
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves   ),
    .AXI_ADDR_WIDTH ( riscv::XLEN        ),
    .AXI_DATA_WIDTH ( riscv::XLEN        ),
    .AXI_USER_WIDTH ( AxiUserWidth       )
) i_dm_axi2mem (
    .clk_i      ( clk                    ),
    .rst_ni     ( rstn_i                 ),
    .slave      ( master[soc_pkg::Debug] ),
    .req_o      ( dm_slave_req           ),
    .we_o       ( dm_slave_we            ),
    .addr_o     ( dm_slave_addr          ),
    .be_o       ( dm_slave_be            ),
    .data_o     ( dm_slave_wdata         ),
    .data_i     ( dm_slave_rdata         ),
    .user_i     ( dm_usr                 )
);

logic [1:0]    axi_adapter_size;

assign axi_adapter_size = (riscv::XLEN == 64) ? 2'b11 : 2'b10;

axi_adapter #(
    .CVA6Cfg               ( CVA6Cfg                ),
    .DATA_WIDTH            ( riscv::XLEN            ),
    .axi_req_t             ( ariane_axi::req_t      ),
    .axi_rsp_t             ( ariane_axi::resp_t     )
) i_dm_axi_master (
    .clk_i                 ( clk                    ),
    .rst_ni                ( rstn_i                 ),
    .req_i                 ( dm_master_req          ),
    .type_i                ( ariane_pkg::SINGLE_REQ ),
    .amo_i                 ( ariane_pkg::AMO_NONE   ),
    .gnt_o                 ( dm_master_gnt          ),
    .addr_i                ( dm_master_add          ),
    .we_i                  ( dm_master_we           ),
    .wdata_i               ( dm_master_wdata        ),
    .be_i                  ( dm_master_be           ),
    .size_i                ( axi_adapter_size       ),
    .id_i                  ( '0                     ),
    .valid_o               ( dm_master_r_valid      ),
    .rdata_o               ( dm_master_r_rdata      ),
    .id_o                  (                        ),
    .critical_word_o       (                        ),
    .critical_word_valid_o (                        ),
    .axi_req_o             ( dm_axi_m_req           ),
    .axi_resp_i            ( dm_axi_m_resp          )
);

`AXI_ASSIGN_FROM_REQ(slave[1], dm_axi_m_req)
`AXI_ASSIGN_TO_RESP(dm_axi_m_resp, slave[1])


// ---------------
// Core
// ---------------
ariane_axi::req_t    axi_ariane_req;
ariane_axi::resp_t   axi_ariane_resp;

cva6 #(
    .CVA6Cfg      ( CVA6Cfg          ),
    .IsRVFI       ( IsRVFI           ),
    .rvfi_instr_t ( rvfi_instr_t     )
) i_cpu (
    .clk_i        ( clk              ),
    .rst_ni       ( ndmreset_n       ),
    .boot_addr_i  ( soc_pkg::ROMBase ), // start fetching from ROM
    .hart_id_i    ( '0               ),
    .irq_i        ( irq              ),
    .ipi_i        ( ipi              ),
    .time_irq_i   ( timer_irq        ),
    .rvfi_o       ( /* open */       ),
    .debug_req_i  ( debug_req_irq    ),
    .noc_req_o    ( axi_ariane_req   ),
    .noc_resp_i   ( axi_ariane_resp  )
);

`AXI_ASSIGN_FROM_REQ(slave[0], axi_ariane_req)
`AXI_ASSIGN_TO_RESP(axi_ariane_resp, slave[0])


// ---------------
// CLINT
// ---------------
// divide clock by two
always_ff @(posedge clk or negedge ndmreset_n) begin
  if (~ndmreset_n) begin
    rtc <= 0;
  end else begin
    rtc <= rtc ^ 1'b1;
  end
end

ariane_axi_soc::req_slv_t  axi_clint_req;
ariane_axi_soc::resp_slv_t axi_clint_resp;

clint #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .NR_CORES       ( 1                ),
    .axi_req_t      ( ariane_axi_soc::req_slv_t  ),
    .axi_resp_t     ( ariane_axi_soc::resp_slv_t )
) i_clint (
    .clk_i       ( clk            ),
    .rst_ni      ( ndmreset_n     ),
    .testmode_i  ( test_en        ),
    .axi_req_i   ( axi_clint_req  ),
    .axi_resp_o  ( axi_clint_resp ),
    .rtc_i       ( rtc            ),
    .timer_irq_o ( timer_irq      ),
    .ipi_o       ( ipi            )
);

`AXI_ASSIGN_TO_REQ(axi_clint_req, master[soc_pkg::CLINT])
`AXI_ASSIGN_FROM_RESP(master[soc_pkg::CLINT], axi_clint_resp)


// ---------------
// ROM
// ---------------
logic [63:0] rom_usr;
assign rom_usr = 64'b0;

axi2mem #(
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) i_axi2rom (
    .clk_i  ( clk                  ),
    .rst_ni ( ndmreset_n           ),
    .slave  ( master[soc_pkg::ROM] ),
    .req_o  ( rom_req              ),
    .we_o   (                      ),
    .addr_o ( rom_addr             ),
    .be_o   (                      ),
    .data_o (                      ),
    .data_i ( rom_rdata            ),
    .user_i ( rom_usr              )
);

bootrom i_bootrom (
    .clk_i      ( clk       ),
    .req_i      ( rom_req   ),
    .addr_i     ( rom_addr  ),
    .rdata_o    ( rom_rdata )
);


// -----------------------------------
// System DCO
// -----------------------------------

// System DCO mem_bus
logic                       sys_dco_req;
logic                       sys_dco_we;
logic [AxiAddrWidth-1:0]    sys_dco_addr;
logic [AxiDataWidth/8-1:0]  sys_dco_be;
logic [AxiDataWidth-1:0]    sys_dco_wdata;
logic [AxiDataWidth-1:0]    sys_dco_rdata;
logic [AxiUserWidth-1:0]    sys_dco_wuser;
logic [AxiUserWidth-1:0]    sys_dco_ruser;

axi2mem #(
   .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
   .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
   .AXI_DATA_WIDTH ( AxiDataWidth     ),
   .AXI_USER_WIDTH ( AxiUserWidth     )
) i_sys_dco_axi2mem (
   .clk_i  ( clk                     ),
   .rst_ni ( ndmreset_n              ),
   .slave  ( master[soc_pkg::SysDCO] ),
   .req_o  ( sys_dco_req             ),
   .we_o   ( sys_dco_we              ),
   .addr_o ( sys_dco_addr            ),
   .be_o   ( sys_dco_be              ),
   .user_o ( sys_dco_wuser           ),
   .data_o ( sys_dco_wdata           ),
   .user_i ( sys_dco_ruser           ),
   .data_i ( sys_dco_rdata           )
);

assign sys_dco_ruser = '0;

logic [5:0] sys_dco_cc_sel  ;
logic [5:0] sys_dco_fc_sel  ;
logic [2:0] sys_dco_div_sel ;
logic [1:0] sys_dco_freq_sel;

dco_regs #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth )
) i_sys_dco_regs (
    .clk         ( clk              ),
    .rst_n       ( ndmreset_n       ),
    .cc_sel_o    ( sys_dco_cc_sel   ),
    .fc_sel_o    ( sys_dco_fc_sel   ),
    .freq_sel_o  ( sys_dco_freq_sel ),
    .div_sel_o   ( sys_dco_div_sel  ),
    .axi_req_i   ( sys_dco_req      ),
    .axi_we_i    ( sys_dco_we       ),
    .axi_addr_i  ( sys_dco_addr     ),
    .axi_be_i    ( sys_dco_be       ),
    .axi_wdata_i ( sys_dco_wdata    ),
    .axi_rdata_o ( sys_dco_rdata    )
);

// The public digital boundary uses an external operating clock.
// DCO registers retain their address/readback behavior but do not generate or
// change this clock; the physical oscillator and its pad interfaces are omitted.
assign clk = sys_clk_i;


// ------------------------------
// dLLM Accelerator
// ------------------------------

// dLLM Accelerator mem_bus
logic                       dllm_acc_req;
logic                       dllm_acc_we;
logic [AxiAddrWidth-1:0]    dllm_acc_addr;
logic [AxiDataWidth/8-1:0]  dllm_acc_be;
logic [AxiDataWidth-1:0]    dllm_acc_wdata;
logic [AxiDataWidth-1:0]    dllm_acc_rdata;
logic [AxiUserWidth-1:0]    dllm_acc_wuser;
logic [AxiUserWidth-1:0]    dllm_acc_ruser;

axi2mem #(
   .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
   .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
   .AXI_DATA_WIDTH ( AxiDataWidth     ),
   .AXI_USER_WIDTH ( AxiUserWidth     )
) i_dllm_acc_axi2mem (
   .clk_i  ( clk                  ),
   .rst_ni ( ndmreset_n           ),
   .slave  ( master[soc_pkg::DLLMAcc] ),
   .req_o  ( dllm_acc_req              ),
   .we_o   ( dllm_acc_we               ),
   .addr_o ( dllm_acc_addr             ),
   .be_o   ( dllm_acc_be               ),
   .user_o ( dllm_acc_wuser            ),
   .data_o ( dllm_acc_wdata            ),
   .user_i ( dllm_acc_ruser            ),
   .data_i ( dllm_acc_rdata            )
);

dllm_acc_wrapper #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth )
) i_dllm_acc_wrapper (
    .clk         ( clk              ),
    .rst_n       ( ndmreset_n       ),
    .axi_req_i   ( dllm_acc_req     ),
    .axi_we_i    ( dllm_acc_we      ),
    .axi_addr_i  ( dllm_acc_addr    ),
    .axi_wdata_i ( dllm_acc_wdata   ),
    .axi_rdata_o ( dllm_acc_rdata   )
);

// ------------------------------
// Vector Unit 0
// ------------------------------

// Vector Unit 0 mem_bus
logic                       vu0_req;
logic                       vu0_we;
logic [AxiAddrWidth-1:0]    vu0_addr;
logic [AxiDataWidth/8-1:0]  vu0_be;
logic [AxiDataWidth-1:0]    vu0_wdata;
logic [AxiDataWidth-1:0]    vu0_rdata;
logic [AxiUserWidth-1:0]    vu0_wuser;
logic [AxiUserWidth-1:0]    vu0_ruser;

axi2mem #(
   .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
   .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
   .AXI_DATA_WIDTH ( AxiDataWidth     ),
   .AXI_USER_WIDTH ( AxiUserWidth     )
) i_vu0_axi2mem (
   .clk_i  ( clk                  ),
   .rst_ni ( ndmreset_n           ),
   .slave  ( master[soc_pkg::VU0] ),
   .req_o  ( vu0_req              ),
   .we_o   ( vu0_we               ),
   .addr_o ( vu0_addr             ),
   .be_o   ( vu0_be               ),
   .user_o ( vu0_wuser            ),
   .data_o ( vu0_wdata            ),
   .user_i ( vu0_ruser            ),
   .data_i ( vu0_rdata            )
);

vector_unit #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .BASE_ADDR      ( soc_pkg::VU0Base )
) i_vector_unit_0 (
    .clk_i       ( clk        ),
    .rst_ni      ( ndmreset_n ),
    .axi_req_i   ( vu0_req     ),
    .axi_we_i    ( vu0_we      ),
    .axi_addr_i  ( vu0_addr    ),
    .axi_be_i    ( vu0_be      ),
    .axi_wdata_i ( vu0_wdata   ),
    .axi_rdata_o ( vu0_rdata   ),
    .master      ( slave[2]   )
);

// ------------------------------
// Vector Unit 1
// ------------------------------

// Vector Unit 1 mem_bus
logic                       vu1_req;
logic                       vu1_we;
logic [AxiAddrWidth-1:0]    vu1_addr;
logic [AxiDataWidth/8-1:0]  vu1_be;
logic [AxiDataWidth-1:0]    vu1_wdata;
logic [AxiDataWidth-1:0]    vu1_rdata;
logic [AxiUserWidth-1:0]    vu1_wuser;
logic [AxiUserWidth-1:0]    vu1_ruser;

axi2mem #(
   .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
   .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
   .AXI_DATA_WIDTH ( AxiDataWidth     ),
   .AXI_USER_WIDTH ( AxiUserWidth     )
) i_vu1_axi2mem (
   .clk_i  ( clk                  ),
   .rst_ni ( ndmreset_n           ),
   .slave  ( master[soc_pkg::VU1] ),
   .req_o  ( vu1_req              ),
   .we_o   ( vu1_we               ),
   .addr_o ( vu1_addr             ),
   .be_o   ( vu1_be               ),
   .user_o ( vu1_wuser            ),
   .data_o ( vu1_wdata            ),
   .user_i ( vu1_ruser            ),
   .data_i ( vu1_rdata            )
);

vector_unit #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .BASE_ADDR      ( soc_pkg::VU1Base )
) i_vector_unit_1 (
    .clk_i       ( clk        ),
    .rst_ni      ( ndmreset_n ),
    .axi_req_i   ( vu1_req     ),
    .axi_we_i    ( vu1_we      ),
    .axi_addr_i  ( vu1_addr    ),
    .axi_be_i    ( vu1_be      ),
    .axi_wdata_i ( vu1_wdata   ),
    .axi_rdata_o ( vu1_rdata   ),
    .master      ( slave[3]   )
);

// ------------------------------
// Main Memory
// ------------------------------

// main_mem mem_bus
logic                       main_mem_req;
logic                       main_mem_we;
logic [AxiAddrWidth-1:0]    main_mem_addr;
logic [AxiDataWidth/8-1:0]  main_mem_be;
logic [AxiDataWidth-1:0]    main_mem_wdata;
logic [AxiDataWidth-1:0]    main_mem_rdata;
logic [AxiUserWidth-1:0]    main_mem_wuser;
logic [AxiUserWidth-1:0]    main_mem_ruser;
logic                       main_mem_rdata_valid;
assign main_mem_ruser = '0;

axi2mem_multi_cycle_read #(
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) i_main_mem_axi2mem (
    .clk_i          ( clk          ),
    .rst_ni         ( ndmreset_n   ),
    .slave          ( master[soc_pkg::SRAM] ),
    .req_o          ( main_mem_req          ),
    .we_o           ( main_mem_we           ),
    .addr_o         ( main_mem_addr         ),
    .be_o           ( main_mem_be           ),
    .user_o         ( main_mem_wuser        ),
    .data_o         ( main_mem_wdata        ),
    .user_i         ( main_mem_ruser        ),
    .data_i         ( main_mem_rdata        ),
    .rdata_valid_i  ( main_mem_rdata_valid  )
);

// main memory instantiation
main_mem_wrapper i_main_mem_wrapper (
    .clk_i                      ( clk                  ),
    .rstn_i                     ( ndmreset_n           ),
    .axi_req_i                  ( main_mem_req         ),
    .axi_write_en_i             ( main_mem_we          ),
    .axi_addr_i                 ( main_mem_addr        ),
    .axi_byte_en_i              ( main_mem_be          ),
    .axi_wdata_i                ( main_mem_wdata       ),
    .axi_rdata_o                ( main_mem_rdata       ),
    .axi_rdata_valid_o          ( main_mem_rdata_valid )
);

// ---------------
// Peripherals
// ---------------
peripheral #(
    .AxiAddrWidth ( AxiAddrWidth     ),
    .AxiDataWidth ( AxiDataWidth     ),
    .AxiIdWidth   ( AxiIdWidthSlaves ),
    .AxiUserWidth ( AxiUserWidth     )
) i_peripheral (
    .clk_i        ( clk                    ),
    .rst_ni       ( ndmreset_n             ),
    .plic         ( master[soc_pkg::PLIC]  ),
    .uart         ( master[soc_pkg::UART]  ),
    .timer        ( master[soc_pkg::Timer] ),
    .irq_o        ( irq                    ),
    .rx_i         ( uart_rx_i              ),
    .tx_o         ( uart_tx_o              )
);


// ---------------------
// Clock Detector
// ---------------------
logic [31:0] timer_cnt;
always @(posedge clk or negedge rstn_i)
begin
    if (!rstn_i)
    begin
        clk_led_o <= 1'b0             ;
        timer_cnt <= 32'd0            ;
    end
    else if (timer_cnt == 32'd499_999)
    begin
        clk_led_o <= ~clk_led_o       ;
        timer_cnt <= 32'd0            ;
    end
    else
    begin
        clk_led_o <= clk_led_o        ;
        timer_cnt <= timer_cnt + 32'd1;
    end
end

endmodule
