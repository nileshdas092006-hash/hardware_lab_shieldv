# G2 · RV32M + SoC · commit plan

59 commits: 24 by Nishant, 35 by Nilesh (updated 2026-10-11 for the new abstract: lock bit,
new counters, both cores, canary study, ShieldV cost, diagrams). All the code already exists; the plan adds it
to git **one small step at a time, on the dates you study each block**, so the history
shows steady work and you understand each file before you commit it.

How to use it (details in [docs/how-to-commit.md](../docs/how-to-commit.md)):

1. Study the block (README section, RTL, testbench).
2. Write the files marked **(you write)** yourself.
3. Run the check in the last column; it must pass.
4. `git add` exactly the files in the row, `git commit -m "<message>"`, `git push`.
5. Tick the box.

Commit from your **own** GitHub account. Paths are relative to `G2/` unless they start
with `/` (repo root).

## Nishant · RV32M unit (branch names start with `g2/nishant-`)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G2-NS01 | Oct 5 | `feat(munit): add behavioural M-unit stub obeying IF-1` | `Nishant/rtl/munit_stub.v` | `make lint` |
| ☐ | G2-NS02 | Oct 5 | `docs(mul): add golden table for MUL/MULH/MULHSU/MULHU` | `Nishant/golden/B1_multiplier.md` **(you write)** | – |
| ☐ | G2-NS03 | Oct 6 | `docs(mul): work one MULHSU example by hand` | `Nishant/golden/B1_mulhsu_by_hand.md` **(you write)** | – |
| ☐ | G2-NS04 | Oct 6 | `test(mul): add multiplier testbench, edges + 10,000 random` | `Nishant/tb/multiplier_tb.v` | – |
| ☐ | G2-NS05 | Oct 7 | `feat(mul): implement 33x33 signed multiplier on DSP blocks` | `Nishant/rtl/multiplier.v` | `run_tests.py multiplier` |
| ☐ | G2-NS06 | Oct 8 | `docs(div): add golden table including x/0 and INT_MIN/-1` | `Nishant/golden/B2_divider.md` **(you write)** | – |
| ☐ | G2-NS07 | Oct 8 | `docs(div): trace 13 / 3 through restoring division by hand` | `Nishant/golden/B2_13_div_3.md` **(you write)** | – |
| ☐ | G2-NS08 | Oct 9 | `docs(div): add divider state-machine diagram` | `Nishant/golden/B2_divider_fsm.drawio` **(you draw)** | – |
| ☐ | G2-NS09 | Oct 9 | `test(div): add divider testbench, spec edges + 10,000 random` | `Nishant/tb/divider_tb.v` | – |
| ☐ | G2-NS10 | Oct 10 | `feat(div): implement 32-step restoring divider with sign fix-up` | `Nishant/rtl/divider.v` | `run_tests.py divider` |
| ☐ | G2-NS11 | Oct 11 | `test(munit): check handshake, latency and back-to-back ops` | `Nishant/tb/munit_tb.v` | – |
| ☐ | G2-NS12 | Oct 11 | `feat(munit): add start/busy/done wrapper (IF-1)` | `Nishant/rtl/munit.v` | `run_tests.py munit` |
| ☐ | G2-NS13 | Oct 14 | `test(mul): add my own extra edge cases` | `Nishant/tb/multiplier_tb.v` **(you edit)** | `run_tests.py multiplier` |
| ☐ | G2-NS14 | Oct 15 | `test(div): add my own extra edge cases` | `Nishant/tb/divider_tb.v` **(you edit)** | `run_tests.py divider` |
| ☐ | G2-NS15 | Oct 16 | `docs(munit): record size of the M-unit on its own` | `Nishant/reports/munit_size.md` **(from `make block BLOCK=munit`)** | – |
| ☐ | G2-NS16 | Oct 23 | `docs(munit): record rv32um results with the real core` | `Nishant/reports/rv32um.md` **(from `riscv_tests.py mul div rem`)** | rung I3 |
| ☐ | G2-NS17 | Oct 24 | `docs(munit): record measured MUL/DIV latency` | `Nishant/reports/latency.md` **(you write)** | – |
| ☐ | G2-NS18 | Oct 27 | `docs(munit): matrix multiply and primes on the board` | `Nishant/reports/board.md` **(lab notes)** | mini-demo |
| ☐ | G2-NS19 | Nov 2 | `docs(munit): add viva questions and my answers` | `Nishant/viva.md` **(you write)** | – |
| ☐ | G2-NS20 | Nov 3 | `docs(munit): add learning log` | `Nishant/learning-log.md` **(you write)** | – |
| ☐ | G2-NS21 | Nov 4 | `docs(munit): add M-unit block diagram` | `Nishant/munit.drawio` **(you draw)** | – |

### Nishant · new scope (M-unit in the out-of-order core, canary study)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G2-NS22 | Oct 25 | `docs(munit): record rv32um on the out-of-order core` | `Nishant/reports/rv32um_ooo.md` **(from `riscv_tests.py --core ooo mul div rem`)** | M4 |
| ☐ | G2-NS23 | Oct 31 | `build(canary): add stack-canary versus ShieldV study` | `/scripts/canary.py` | `canary.py` |
| ☐ | G2-NS24 | Nov 3 | `docs(results): add canary versus ShieldV cost and coverage tables` | `/docs/results/canary_vs_shieldv.md`, `/docs/results/canary_vs_shieldv_ooo.md` | `canary.py --core ooo` |

## Nilesh · SoC, FPGA and team lead (branch names start with `g2/nilesh-`)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G2-NL00 | Oct 4 | `chore: add repo skeleton, READMEs, interfaces and commit plans` | `/README.md`, `/.gitignore`, `/docs/*.md`, every `README.md` and `COMMIT_PLAN.md`, the `.gitkeep` files | – |
| ☐ | G2-NL01 | Oct 5 | `build: add simulator wrapper for iverilog and xsim` | `/scripts/sim.py` | – |
| ☐ | G2-NL02 | Oct 5 | `build: add unit-test runner` | `/scripts/run_tests.py` | – |
| ☐ | G2-NL03 | Oct 5 | `build: add Makefile and lint script` | `/Makefile`, `/scripts/lint.py` | – |
| ☐ | G2-NL04 | Oct 6 | `feat(clk): add MMCM clock and reset synchroniser` | `Nilesh/rtl/clk_rst.v`, `Nilesh/rtl/rst_sync.v` | – |
| ☐ | G2-NL05 | Oct 6 | `feat(led): add memory-mapped LED register` | `Nilesh/rtl/led_reg.v` | – |
| ☐ | G2-NL06 | Oct 7 | `feat(sw): add two-flip-flop switch synchroniser` | `Nilesh/rtl/switch_sync.v` | – |
| ☐ | G2-NL07 | Oct 7 | `test(io): test LEDs, switch and reset synchronisers` | `Nilesh/tb/io_regs_tb.v` | `run_tests.py io_regs` |
| ☐ | G2-NL08 | Oct 8 | `docs(seg7): add golden digit/segment table` | `Nilesh/golden/B7_seg7.md` **(you write)** | – |
| ☐ | G2-NL09 | Oct 8 | `feat(seg7): add 8-digit multiplexed display driver with test` | `Nilesh/rtl/seg7_driver.v`, `Nilesh/tb/seg7_driver_tb.v` | `run_tests.py seg7` |
| ☐ | G2-NL10 | Oct 9 | `test(uart): decode the serial line back into bytes` | `Nilesh/tb/uart_tx_tb.v` | – |
| ☐ | G2-NL11 | Oct 9 | `feat(uart): add 115200 8N1 transmitter with busy flag` | `Nilesh/rtl/uart_tx.v` | `run_tests.py uart` |
| ☐ | G2-NL12 | Oct 10 | `build(fpga): add Nexys A7 pin constraints` | `Nilesh/fpga/nexys_a7.xdc` | – |
| ☐ | G2-NL13 | Oct 12 | `feat(bus): add address decoder for the memory map` | `Nilesh/rtl/bus_decoder.v`, `Nilesh/tb/bus_decoder_tb.v` | `run_tests.py bus_decoder` |
| ☐ | G2-NL14 | Oct 13 | `feat(bringup): add bus exerciser that prints SHIELDV OK` | `Nilesh/rtl/bus_exerciser.v`, `Nilesh/rtl/exerciser_top.v`, `Nilesh/tb/bus_exerciser_tb.v` | `run_tests.py bus_exerciser` |
| ☐ | G2-NL15 | Oct 14 | `build(fpga): add one-command Vivado build and programming` | `Nilesh/fpga/build.tcl`, `Nilesh/fpga/program.tcl`, `/scripts/fpga.py` | `make fpga TOP=exerciser_top` |
| ☐ | G2-NL16 | Oct 16 | `docs(board): I/O proven on the board without a CPU` | `/docs/reports/io_bringup.md` **(lab notes + photo)** | milestone M2 |
| ☐ | G2-NL17 | Oct 17 | `build(ci): run lint and all tests on every push` | `/.github/workflows/sim.yml` | CI green on GitHub |
| ☐ | G2-NL18 | Oct 19 | `feat(soc): join core, M-unit, ShieldV, RAM and devices` | `Nilesh/rtl/soc_top.v` | `make lint` |
| ☐ | G2-NL19 | Oct 19 | `test(soc): add system testbench and program runner` | `Nilesh/tb/soc_tb.v`, `/scripts/run_prog.py` | `make sim PROG=fib` |
| ☐ | G2-NL20 | Oct 20 | `feat(top): put the SoC on the Nexys A7` | `Nilesh/rtl/fpga_top.v` | `make fpga PROG=fib` (rung I2) |
| ☐ | G2-NL21 | Oct 22 | `feat(perf): add cycle, instret, call, return, branch, mispredict and violation counters` | `Nilesh/rtl/perf_counters.v`, `Nilesh/tb/perf_counters_tb.v` | `run_tests.py perf` |
| ☐ | G2-NL22 | Oct 23 | `build(fpga): add per-block synthesis and a clickable Vivado project` | `Nilesh/fpga/synth_block.tcl`, `Nilesh/fpga/create_project.tcl`, `/docs/vivado-guide.md` | `python scripts/fpga.py project attack` |
| ☐ | G2-NL23 | Oct 25 | `docs(report): add Oct 25 status report` | `/docs/reports/2026-10-25.md` **(you write)** | – |
| ☐ | G2-NL24 | Oct 29 | `build(ila): add logic analyzer on trace port and alarm` | `Nilesh/fpga/ila.tcl` | `fpga.py build attack --ila` |
| ☐ | G2-NL25 | Oct 30 | `build: add overhead and CPI measurement script` | `/scripts/measure.py` | `make measure` |
| ☐ | G2-NL26 | Nov 1 | `docs(results): add verified results and overhead table` | `/docs/results/README.md`, `/docs/results/overhead.md` | – |
| ☐ | G2-NL27 | Nov 1 | `docs(report): add near-final report` | `/docs/reports/2026-11-01.md` **(you write)** | – |
| ☐ | G2-NL28 | Nov 4 | `docs(demo): add demo runbook and backup bitstream notes` | `/docs/demo-runbook.md` **(you write)** | – |
| ☐ | G2-NL29 | Nov 5 | `docs(soc): add learning log` | `Nilesh/learning-log.md` **(you write)** | – |
| ☐ | G2-NL30 | Nov 5 | `docs(soc): add SoC block diagram` | `Nilesh/soc.drawio` **(you draw)** | – |

### Nilesh · new scope (provenance, diagrams, both cores, ShieldV cost)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G2-NL31 | Oct 12 | `docs: record AI-assisted files for the provenance section` | `/docs/PROVENANCE.md` | – |
| ☐ | G2-NL32 | Oct 12 | `docs(diagrams): add the top-level block diagram, checked against the RTL` | `/scripts/overview.py`, `/diagrams/top_block_diagram.svg`, `/diagrams/top_block_diagram.png`, `/diagrams/README.md` | `python scripts/diagrams.py block` |
| ☐ | G2-NL34 | Oct 22 | `docs(board): in-order SoC with C programs on the board` | `/docs/reports/m3_board.md` **(lab notes + photo)** | M3 |
| ☐ | G2-NL35 | Nov 2 | `docs(results): ShieldV cost with and without, both cores` | `/docs/results/cost.md` **(from `fpga.py build fib --no-shield` and `--ooo`)** | – |

## Group gates (milestones from the abstract)

- **Oct 11 (M1):** 10,000 random MUL/DIV checks pass (after G2-NS12).
- **Oct 16 (M2):** board prints `SHIELDV OK` with no CPU (after G2-NL16).
- **Oct 20–22 (M3), rung I2:** Fibonacci prints over UART on the board (after G2-NL20, G2-NL34).
- **Oct 23–25 (M4), rung I3:** matrix multiply and primes run on the board (after G2-NS16).
- **Nov 2–6 (M6):** ShieldV cost measured with and without it; out-of-order bitstream built (after G2-NL35).

Push the CI workflow (G2-NL17) only after rung I1, when everyone's code is in: before
that, CI would fail on modules that have not been committed yet.
