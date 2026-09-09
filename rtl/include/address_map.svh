`ifndef _ADDRESS_MAP_SVH_
`define _ADDRESS_MAP_SVH_

// Address mask
`define ADDR_MASK 64'h0000_00FF

// Invalid read data
`define AXI_INVALID_READ_DATA 64'hBADC_AB1E_CA11_AB1E

// Vector unit window offsets (relative to instance BASE_ADDR parameter)
// Control/status registers
`define VU_CTRL_STATUS_OFFSET 16'h0000
`define VU_LOOP_MODE_OFFSET 16'h0008
`define VU_INSTR_COUNT_OFFSET 16'h0010
`define VU_DEBUG_OFFSET 16'h0018

// Instruction buffer window
`define VU_INSTR_BUF_OFFSET 16'h1000
`define VU_INSTR_BUF_END_OFFSET 16'h11FF

// Scalar RF window (4 groups x 64 entries x 8B = 2KB)
`define VU_SCALAR_RF_OFFSET 16'h2000
`define VU_SCALAR_RF_END_OFFSET 16'h27FF

// Token-promotion config / status window
`define VU_TOKEN_PROMOTE_CTRL_STATUS_OFFSET 16'h3000
`define VU_TOKEN_PROMOTE_SHIFT_CFG_OFFSET 16'h3008
`define VU_TOKEN_PROMOTE_TILE_CFG_OFFSET 16'h3010
`define VU_TOKEN_PROMOTE_RESULT_OFFSET 16'h3018
`define VU_TOKEN_PROMOTE_DEBUG_OFFSET 16'h3020
`define VU_TOKEN_PROMOTE_END_OFFSET 16'h30FF

// Vector RF window (64 entries x 16 banks x 8B = 8KB)
`define VU_VECTOR_RF_OFFSET 16'h4000
`define VU_VECTOR_RF_END_OFFSET 16'h5FFF

// DMA config / status window
`define VU_DMA_OFFSET 16'h6000
`define VU_DMA_END_OFFSET 16'h60FF
`define VU_DMA_SRC_LO_OFFSET 16'h6000
`define VU_DMA_SRC_HI_OFFSET 16'h6008
`define VU_DMA_DST_LO_OFFSET 16'h6010
`define VU_DMA_DST_HI_OFFSET 16'h6018
`define VU_DMA_LEN_OFFSET 16'h6020
`define VU_DMA_CONFIG_OFFSET 16'h6028
`define VU_DMA_LAUNCH_OFFSET 16'h6030
`define VU_DMA_STATUS_OFFSET 16'h6038
`define VU_DMA_INSTR_SRC_BASE_LO_OFFSET 16'h6040
`define VU_DMA_INSTR_SRC_BASE_HI_OFFSET 16'h6048
`define VU_DMA_INSTR_DST_BASE_LO_OFFSET 16'h6050
`define VU_DMA_INSTR_DST_BASE_HI_OFFSET 16'h6058

// Cache-PE core data window inside the dLLM accelerator wrapper
`define CACHE_PE_CORE_DATA_BASE_ADDR 64'h3000_0000
`define CACHE_PE_CORE_DATA_END_ADDR 64'h3003_FFFF

// Cache-PE per-core config register file inside the dLLM accelerator wrapper
`define CACHE_PE_CORE_CFG_REGFILE_BASE_ADDR 64'h4000_0000
`define CACHE_PE_CORE_CFG_REGFILE_END_ADDR 64'h4000_007F

// Cache-PE core control / status window inside the dLLM accelerator wrapper
`define CACHE_PE_CORE_STATUS_BASE_ADDR 64'h4000_0080
`define CACHE_PE_CORE_STATUS_END_ADDR 64'h4000_00A7
`define CACHE_PE_CORE_CAL_START_ADDR 64'h4000_0080
`define CACHE_PE_CORE_W_LOAD_START_ADDR 64'h4000_0088
`define CACHE_PE_CORE_CAL_DONE_ADDR 64'h4000_0090
`define CACHE_PE_CORE_W_LOAD_DONE_ADDR 64'h4000_0098
`define CACHE_PE_CORE_DONE_ALL_ADDR 64'h4000_00A0

// SFU config / metadata / result window inside the dLLM accelerator wrapper (Phase 2)
`define SFU_CFG_BASE_ADDR 64'h5000_0000
`define SFU_CFG_END_ADDR 64'h5000_23FF

// Per-SFU configuration registers (4 * 64-bit words)
`define SFU_CFG_REGFILE_BASE_ADDR 64'h5000_0000
`define SFU_CFG_REGFILE_END_ADDR 64'h5000_0018

// Wave control / status
`define SFU_WAVE_EN_ADDR 64'h5000_0020
`define SFU_WAVE_DONE_ADDR 64'h5000_0028
`define SFU_ACTIVE_ADDR 64'h5000_0030

// Tile decision readback / clear
`define SFU_TILE_DECISION_ADDR 64'h5000_0038
`define SFU_TILE_DECISION_VALID_ADDR 64'h5000_0040
`define SFU_TILE_CLR_ADDR 64'h5000_0048

// Loop control (Phase 3)
`define SFU_LOOP_EN_ADDR 64'h5000_0058
`define SFU_LOOP_COUNT_ADDR 64'h5000_0060

// SFU test mode (direct-start bypass)
`define SFU_TEST_START_ADDR 64'h5000_0050

// Scale vector storage (4 SFUs * 16 words = 64 words)
`define SFU_SCALE_BASE_ADDR 64'h5000_0100
`define SFU_SCALE_END_ADDR 64'h5000_02FF

// SFU result buffer readback (4 SFUs * 256 words = 1024 words)
`define SFU_RESULT_BASE_ADDR 64'h5000_0400
`define SFU_RESULT_END_ADDR 64'h5000_23FF

`endif
