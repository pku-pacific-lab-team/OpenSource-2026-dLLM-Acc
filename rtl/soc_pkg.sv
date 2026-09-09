// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Description: Contains SoC information as constants
package soc_pkg;
  // M-Mode Hart, S-Mode Hart
  localparam int unsigned NumTargets = 2;
  // Uart, SPI, Ethernet, reserved
  localparam int unsigned NumSources = 30;
  localparam int unsigned MaxPriority = 7;

  localparam NrSlaves = 4; // actually masters, but slaves on the crossbar

  typedef enum int unsigned {
        Debug       = 0,
        ROM         = 1,
        CLINT       = 2,
        PLIC        = 3,
        UART        = 4,
        Timer       = 5,
        SysDCO      = 6,
        SysPLL      = 7,
        DLLMAcc     = 8,
        VU0         = 9,
        VU1         = 10,
        SRAM        = 11
  } axi_slaves_t;

  localparam NB_PERIPHERALS = SRAM + 1;


  localparam logic[63:0] DebugLength    = 64'h1000;
  localparam logic[63:0] ROMLength      = 64'h10000;
  localparam logic[63:0] CLINTLength    = 64'hC0000;
  localparam logic[63:0] PLICLength     = 64'h3FF_FFFF;
  localparam logic[63:0] UARTLength     = 64'h1000;
  localparam logic[63:0] TimerLength    = 64'h1000;
  localparam logic[63:0] SysDCOLength   = 64'h1000;
  localparam logic[63:0] SysPLLLength   = 64'h1000;
  localparam logic[63:0] DLLMAccLength  = 64'h3000_0000;
  localparam logic[63:0] VU0Length      = 64'h1000_0000;
  localparam logic[63:0] VU1Length      = 64'h1000_0000;
  localparam logic[63:0] SRAMLength     = 64'h2000_0000;
  // Instantiate AXI protocol checkers
  localparam bit GenProtocolChecker = 1'b0;

  typedef enum logic [63:0] {
    DebugBase    = 64'h0000_0000,
    ROMBase      = 64'h0001_0000,
    CLINTBase    = 64'h0200_0000,
    PLICBase     = 64'h0C00_0000,
    UARTBase     = 64'h1000_0000,
    TimerBase    = 64'h1800_0000,
    SysDCOBase   = 64'h2000_0000,
    SysPLLBase   = 64'h2400_0000,
    DLLMAccBase  = 64'h3000_0000,
    VU0Base      = 64'h6000_0000,
    VU1Base      = 64'h7000_0000,
    SRAMBase     = 64'h8000_0000
  } soc_bus_start_t;

  localparam NrRegion = 1;
  localparam logic [NrRegion-1:0][NB_PERIPHERALS-1:0] ValidRule = {{NrRegion * NB_PERIPHERALS}{1'b1}};

endpackage
