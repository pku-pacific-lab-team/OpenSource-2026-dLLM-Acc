# dLLM Accelerator SoC

RTL and test-chip measurement results for a diffusion large language model accelerator with an INT PE array, vector units, a CVA6 CPU, DMA, and AXI peripherals.

## Structure

| Directory | Contents |
| --- | --- |
| `rtl/` | Accelerator and SoC RTL sources |
| `measurement-results/` | Test-chip measurement results (CSV): [maximum frequency](measurement-results/max-frequency.csv), [power and efficiency](measurement-results/power-efficiency.csv), [energy breakdown](measurement-results/energy-breakdown.csv) |

## Design

| Path | Contents |
| --- | --- |
| `rtl/dllm_acc/cache_PE_accelerator/` | Compute cores (W4A4 / W4A8) |
| `rtl/dllm_acc/special_function_unit/` | BF16 dequantization and cross-core accumulation |
| `rtl/dllm_acc/vector_unit/` | SIMD vector unit: BF16 lanes, quantization, token promotion, top-k |
| `rtl/dllm_acc/*.sv` | Accelerator wrapper, configuration registers, and control |
| `rtl/soc.sv`, `rtl/include/` | SoC top level and address map |

The CPU, DMA, bus, and peripherals in the other directories are third-party IP. Memories use a generic behavioral SRAM model in `rtl/misc/`; no technology library is needed.

## Build

The RTL top module is `soc`. The source list is [rtl/filelist.f](rtl/filelist.f), where `SRC_DIR` points to the `rtl/` directory. Checked with Verilator 5.034:

```bash
SRC_DIR=$PWD/rtl verilator --lint-only --timing -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK --top-module soc -f rtl/filelist.f
```

Testbench is currently not included.

## License

First-party RTL uses [Apache-2.0](LICENSE). See [THIRD_PARTY.md](THIRD_PARTY.md) for third-party licenses.
