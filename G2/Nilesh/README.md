# Nilesh Das · G2 SoC and FPGA · team lead

You own everything that connects the CPU to the real board, the Vivado flow, and the
shared test infrastructure. Also yours: ILA debugging, the demo video, integration every
Sunday and the weekly reports.

## Your files

| Block | File | Testbench | What it does |
|---|---|---|---|
| B10 Clock & reset | `rtl/clk_rst.v`, `rtl/rst_sync.v` | `tb/io_regs_tb.v` | MMCM makes 50 MHz from 100 MHz; reset released cleanly on a clock edge |
| B5 LEDs | `rtl/led_reg.v` | `tb/io_regs_tb.v` | store to 0x1000_0000 lights the LEDs |
| B6 Switches | `rtl/switch_sync.v` | `tb/io_regs_tb.v` | two flip-flops per switch against metastability (SW0 = protection) |
| B7 7-segment | `rtl/seg7_driver.v` | `tb/seg7_driver_tb.v` | 8 hex digits, one lit at a time; shows the fault PC when frozen |
| B8 UART | `rtl/uart_tx.v` | `tb/uart_tx_tb.v` | 115200 baud 8N1 to the laptop |
| B4 Bus decoder | `rtl/bus_decoder.v` | `tb/bus_decoder_tb.v` | sends each load/store to RAM or a device by address |
| B9 Counters | `rtl/perf_counters.v` | `tb/perf_counters_tb.v` | cycles, instructions, calls, returns (for CPI and overhead) |
| SoC | `rtl/soc_top.v` | `tb/soc_tb.v` (system test) | joins core, M-unit, ShieldV, RAM and devices |
| B11 FPGA top | `rtl/fpga_top.v`, `fpga/nexys_a7.xdc` | `make fpga` | pins of the Nexys A7 |
| Bring-up | `rtl/bus_exerciser.v`, `rtl/exerciser_top.v` | `tb/bus_exerciser_tb.v` | proves the I/O on the board without a CPU |
| Vivado flow | `fpga/build.tcl`, `program.tcl`, `ila.tcl`, `synth_block.tcl`, `create_project.tcl` | – | bitstream, reports, logic analyzer, per-block size, clickable project |

Shared infrastructure you maintain (at the repo root): `Makefile`, `scripts/sim.py`,
`run_tests.py`, `run_prog.py`, `lint.py`, `fpga.py`, `measure.py`,
`.github/workflows/sim.yml`, `.gitignore` and the `docs/` pages.

## The ideas, in plain words

**Why synchronise switches?** A switch can flip exactly on a clock edge. The flip-flop
that samples it can hang "half way" for a moment (metastability). Two flip-flops in a
row give it a full cycle to settle.

**8 digits with few pins.** All digits share the 7 segment wires; one digit is switched
on at a time, fast enough that the eye sees all eight.

**UART.** The line idles high. A byte is: one low start bit, 8 data bits (LSB first),
one high stop bit. At 50 MHz and 115200 baud each bit lasts 434 clock cycles.

**Why read data one cycle later?** Block RAM answers on the next clock edge, so the bus
contract (IF-2) says *all* reads answer next cycle; `bus_decoder.v` registers device
reads to match the RAM.

**Why scripts, not clicking in Vivado?** One command rebuilds the exact same bitstream
and writes the utilization and timing reports the course asks for.

## Commands you will use

```
python scripts/run_tests.py uart seg7 io_regs bus_decoder perf bus_exerciser
make fpga TOP=exerciser_top    # first board test: LEDs follow switches, "SHIELDV OK" on UART
make fpga PROG=attack          # full system; reports in build/fpga/fpga_top/
make program                   # board on USB
python scripts/fpga.py build attack --ila    # with the logic analyzer
make block BLOCK=shieldv       # size of one module (give this to each member)
make measure                   # overhead + CPI table for the report
```

## Current numbers (Vivado 2025.2, xc7a100tcsg324-1)

- `fpga_top` at 50 MHz (Oct 11): **timing met, WNS +0.461 ns**; 2,110 LUTs, 1,083 FFs, 8 BRAM36, 4 DSP.
- `--no-shield`: 1,793 LUTs, WNS +1.480 ns. `--ooo`: 9,806 LUTs (15.5 %), WNS +0.159 ns. See `docs/results/cost.md`.
- Critical path: data RAM → load align → forwarding → ALU → bus decode → ShieldV
  register write (16 logic levels). Watch it if timing gets worse.
- `exerciser_top`: builds, timing met.

## New on Oct 11

- `perf_counters.v`: BRANCHES (0x50), MISPRED (0x54), VIOL (0x58), CORE_ID (0x5C).
- `soc_top.v`: `` `define SHIELDV_OOO `` swaps in the out-of-order core (same ports).
- `soc_tb.v`: works with both cores; reset is now released between clock edges (a race
  logged the first instruction twice on the in-order core); `+trigger_waddr` for timing diagrams.
- Vivado: `python scripts/fpga.py build attack --no-shield` (ShieldV replaced by its stub)
  and `--ooo`. Numbers in `docs/results/cost.md`.
- `diagrams/top_block_diagram.svg`: the top-level block diagram (`python scripts/diagrams.py block`).

## Team-lead jobs

- **Sunday integration:** merge the week's pull requests, run `make test`,
  `make programs`, `make riscv-tests`.
- **Weekly reports:** each points at a finished rung or block (`docs/results/`).
- **Demo:** runbook rehearsed twice, backup bitstreams for rungs I3 and I4, 4-minute video.

Your commits: rows **G2-NL00 … G2-NL36** in [../COMMIT_PLAN.md](../COMMIT_PLAN.md).
