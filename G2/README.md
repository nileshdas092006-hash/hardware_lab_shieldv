# G2 · RV32M + SoC

**Members:** Nishant (multiply/divide unit) · Nilesh Das (SoC, FPGA, team lead)
**Plan blocks:** B1 to B11 ("Module B" in the build plan)
**Commit plan:** [COMMIT_PLAN.md](COMMIT_PLAN.md)

G2 builds what sits around the core:

1. **The M-unit** (Nishant): hardware for the "M" in RV32IM, the eight multiply and
   divide instructions. The course requires them.
2. **The SoC shell** (Nilesh): everything that turns a bare CPU into a working board.
   "SoC" means system-on-chip: CPU, memory and input/output devices, all in the FPGA.

## Part 1: the M-unit

| Instruction | Does | Hardware | Cycles |
|---|---|---|---|
| MUL | low 32 bits of a × b | DSP blocks | 2 |
| MULH / MULHSU / MULHU | high 32 bits, signed×signed / signed×unsigned / unsigned×unsigned | same multiplier | 2 |
| DIV / DIVU | quotient, signed / unsigned | 32-step restoring divider | 34 |
| REM / REMU | remainder, signed / unsigned | same divider | 34 |

Both sit behind one **start / busy / done handshake** (IF-1): the core pulses `start`,
waits, and takes `result` when `done` = 1. It does not care whether that took 2 cycles or
34, which is why the core could be built against `munit_stub.v` first.

## Part 2: the SoC shell

```
                 ┌──────── bus_decoder ─────────────────────────┐
   core ── IF-2 ─┤ 0x0001_xxxx  → dmem (data RAM)               │
                 │ 0x1000_0000  → led_reg      ──► 16 LEDs       │
                 │ 0x1000_0004  → seg7_driver  ──► 8 digits      │
                 │ 0x1000_0008  ← switch_sync  ◄── 16 switches   │
                 │ 0x1000_0010  → uart_tx      ──► USB → laptop  │
                 │ 0x1000_0020  ← perf_counters                  │
                 │ 0x1000_0030  ↔ ShieldV registers (G3)         │
                 └──────────────────────────────────────────────┘
   clk_rst (100 → 50 MHz, clean reset) ──► everything
   fpga_top + nexys_a7.xdc ──► board pins
```

**Memory-mapped I/O:** every device has an address. A C store to `0x1000_0000` goes to
the LEDs instead of RAM. No new instructions needed. Full map:
[docs/interfaces.md](../docs/interfaces.md).

`soc_top.v` joins the core, M-unit, ShieldV, data RAM and devices; it has no
board-specific parts, so the same file is simulated and synthesised. `fpga_top.v` adds
the clock manager and the pins.

## Who does what

| Member | Blocks | Folder |
|---|---|---|
| Nishant | B1 multiplier, B2 divider, B3 handshake, M-unit stub, 10,000-case random tests | [Nishant/](Nishant/README.md) |
| Nilesh | B4 bus decoder, B5 LEDs, B6 switches, B7 7-segment, B8 UART, B9 counters, B10 clock/reset, B11 FPGA top + pins, SoC, bus exerciser, Vivado scripts, ILA, CI, test scripts | [Nilesh/](Nilesh/README.md) |

## Check G2 yourself

```
python scripts/run_tests.py multiplier divider munit
python scripts/run_tests.py uart seg7 io_regs bus_decoder perf bus_exerciser
make fpga TOP=exerciser_top        # I/O-only bitstream for the first board test
make fpga PROG=attack              # the full system
```

## New on Oct 11

- **Nishant:** the M-unit also serves the out-of-order core (one operation at a time; a
  flush cannot stop it, so `core_ooo.v` drops the answer of a cancelled DIV). New study:
  `scripts/canary.py` compares compiler stack canaries (`-fstack-protector-all`) with
  ShieldV on cost and on which attacks each stops.
- **Nilesh:** new counters BRANCHES, MISPRED, VIOL and CORE_ID (`perf_counters.v`), the
  core build option in `soc_top.v`, both cores in `soc_tb.v`, Vivado variants
  `fpga.py build <prog> --ooo` and `--no-shield` (ShieldV's own cost), `docs/PROVENANCE.md`
  and the top-level block diagram `diagrams/top_block_diagram.svg`.

## Status

- MUL: 10,256 checks pass, 2 cycles. DIV: 10,400 checks incl. every spec edge case, 34 cycles.
- All six I/O testbenches pass; the bus exerciser prints `SHIELDV OK` in simulation.
- Vivado (Oct 11): in-order system meets 50 MHz (WNS +0.461 ns), 2,110 LUTs, 8 BRAM, 4 DSP;
  out-of-order system also meets 50 MHz (9,806 LUTs); ShieldV costs +317 LUTs (docs/results/cost.md);
  `exerciser_top` also builds and meets timing.
- **Not yet done:** anything on the real board.
