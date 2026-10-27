# ShieldV: answers for report sections 3, 4 and 5

All numbers come from the project folder: the Verilog files, Vivado 2025.2 reports
(`docs/results/cost.md`, part xc7a100tcsg324-1) and the test runs. Nothing has run on the board yet.

## 3. Module Summary

| Module | Purpose | File | Software/Hardware module? |
|---|---|---|---|
| **G1: in-order core (Avani, Laxmidhar)** | | | |
| PC register | Program counter and next-PC mux | `pc_reg.v` | Hardware (Verilog) |
| IMEM | 16 KB instruction RAM (BRAM) | `imem.v` | Hardware (Verilog) |
| Decoder | Instruction decoder and control signals | `decoder.v` | Hardware (Verilog) |
| Immediate generator | I/S/B/U/J immediates | `imm_gen.v` | Hardware (Verilog) |
| Register file | 32 x 32-bit registers, 2 read / 1 write | `regfile.v` | Hardware (Verilog) |
| ALU | RV32I arithmetic, logic, shifts, compares | `alu.v` | Hardware (Verilog) |
| Branch unit | Branch compare, jump target, link (pc+4) | `branch_unit.v` | Hardware (Verilog) |
| Pipeline registers | IF/ID→EX and EX→MEM/WB registers | `pipe_ifid_ex.v`, `pipe_ex_wb.v` | Hardware (Verilog) |
| Forwarding unit | Bypasses results to EX (no load-use stall) | `forward_unit.v` | Hardware (Verilog) |
| Hazard unit | Stall on M-unit busy or ShieldV freeze | `hazard_unit.v` | Hardware (Verilog) |
| Flush unit | Flush on taken branch/jump or ShieldV trap | `flush_unit.v` | Hardware (Verilog) |
| Load/store unit | Byte/half/word loads and stores, sign-extension | `lsu.v` | Hardware (Verilog) |
| Writeback mux | Selects ALU / load / link / M-unit result | `wb_mux.v` | Hardware (Verilog) |
| DMEM | 16 KB byte-writable data RAM (BRAM) | `dmem.v` | Hardware (Verilog) |
| Trace port | Retire / branch / mispredict signals for counters | `trace_port.v` | Hardware (Verilog) |
| 3-stage core | Top of the in-order RV32IM pipeline | `core_pipe.v` | Hardware (Verilog) |
| Single-cycle core | Week-1 reference core | `core_single.v` | Hardware (Verilog) |
| **G1: out-of-order core (goal tier)** | | | |
| Rename table | Register alias table (RAT) | `rename_table.v` | Hardware (Verilog) |
| Reorder buffer | 16-entry ROB, in-order commit | `rob.v` | Hardware (Verilog) |
| Reservation station | Waits for operands, issues to units | `rs.v` | Hardware (Verilog) |
| Load/store queue | 8-entry LSQ, store-to-load ordering | `lsq.v` | Hardware (Verilog) |
| CDB arbiter | Picks which result uses the common data bus | `cdb_arbiter.v` | Hardware (Verilog) |
| Bimodal / gshare / tournament predictors | Conditional-branch prediction | `bp_bimodal.v`, `bp_gshare.v`, `bp_tournament.v` | Hardware (Verilog) |
| BTB | Branch target buffer for indirect jumps | `btb.v` | Hardware (Verilog) |
| RAS | Return-address stack predictor | `ras.v` | Hardware (Verilog) |
| OoO core | Top of the Tomasulo RV32IM core (ShieldV checks at commit) | `core_ooo.v` | Hardware (Verilog) |
| **G2: M-unit (Nishant)** | | | |
| Multiplier | MUL, MULH, MULHSU, MULHU (DSP blocks) | `multiplier.v` | Hardware (Verilog) |
| Divider | DIV, DIVU, REM, REMU, 32-step restoring | `divider.v` | Hardware (Verilog) |
| M-unit | start / busy / done handshake to the core | `munit.v` (+ `munit_stub.v` for early tests) | Hardware (Verilog) |
| **G2: SoC and board (Nilesh)** | | | |
| Bus decoder | Address decoding: RAM, I/O, ShieldV registers | `bus_decoder.v` | Hardware (Verilog) |
| LED register | Memory-mapped 16 LEDs | `led_reg.v` | Hardware (Verilog) |
| Switch synchroniser | 2-flip-flop sync for 16 switches | `switch_sync.v` | Hardware (Verilog) |
| 7-segment driver | 8-digit multiplexed display | `seg7_driver.v` | Hardware (Verilog) |
| UART TX | 8N1 serial output to the PC | `uart_tx.v` | Hardware (Verilog) |
| Performance counters | Cycles, instret, branches, mispredicts, calls, returns, violations | `perf_counters.v` | Hardware (Verilog) |
| Clock / reset | 100 → 50 MHz MMCM, reset synchroniser | `clk_rst.v`, `rst_sync.v` | Hardware (Verilog) |
| SoC top / FPGA top | Wires core + ShieldV + memory + I/O; board pins | `soc_top.v`, `fpga_top.v` | Hardware (Verilog) |
| Bus exerciser | I/O bring-up without a CPU | `bus_exerciser.v`, `exerciser_top.v` | Hardware (Verilog) |
| **G3: ShieldV (Priyank)** | | | |
| Call/return detector | Spots calls, returns, indirect jumps in EX | `callret_detect.v` | Hardware (Verilog) |
| Shadow stack | 32-entry return-address stack, full/empty | `shadow_stack.v` | Hardware (Verilog) |
| Commit control | Only real (not flushed) instructions push/pop | `commit_ctrl.v` | Hardware (Verilog) |
| Return compare | Return target vs shadow-stack top | `ret_compare.v` | Hardware (Verilog) |
| Violation FSM | Freeze, trap to handler, or count only | `violation_fsm.v` | Hardware (Verilog) |
| Control register | Enable / mode / landing pads / **lock bit** | `shield_ctrl.v` | Hardware (Verilog) |
| Landing-pad check | Indirect jumps must land on a marker | `lpad_check.v` | Hardware (Verilog) |
| Fault registers | Fault PC, expected, actual, cause, count | `fault_regs.v` | Hardware (Verilog) |
| ShieldV top | Connects the ShieldV blocks | `shieldv.v` (+ `shieldv_stub.v`) | Hardware (Verilog) |
| **Software** | | | |
| Startup code | Stack, .bss, call main, trap entry | `crt0.S`, `link.ld` | Software (assembly) |
| Runtime library | UART print, perf report, fault viewer, canary | `rt.c`, `rt.h` | Software (C) |
| Workloads and attacks | benchmark and timing programs, 4 attack programs | `sw/workloads/*`, `sw/attack/*` | Software (C / assembly) |
| Golden model | RV32IM instruction-set simulator and shadow-stack model | `rv32im_iss.py`, `shadow_model.py` | Software (Python) |
| Test and build scripts | Run tests, random diff, measure CPI, Vivado build | `scripts/*.py`, `build.tcl` | Software (Python / Tcl) |

The hardware contribution is already large (about 55 Verilog modules, 3 of them new security features:
shadow stack, lock bit, landing pads), so no extra hardware is needed for this section.

## 4. Hardware Resource Estimates

These are **measured** results from Vivado implementation (not guesses) for the default build,
in-order core + ShieldV, on the xc7a100tcsg324-1. The out-of-order build is in brackets.

| Resource | Maximum Available | Estimated Usage | % utilization |
|---|---|---|---|
| BRAM (36 Kb tiles) | 135 | 8 (16 KB IMEM + 16 KB DMEM) | 5.9 % |
| DSP blocks | 240 | 4 (multiplier) | 1.7 % |
| LUTs | 63,400 | 2,110 (OoO: 9,806) | 3.3 % (OoO: 15.5 %) |
| FF | 126,800 | 1,083 (OoO: 5,981) | 0.9 % (OoO: 4.7 %) |

ShieldV on its own: 198 LUTs, 150 FF, 0 BRAM, 0 DSP. Both builds meet timing at 50 MHz.

## 5. Verification Plans

- **MUL/DIV:** Unit testbenches compare against a reference model taken from the RISC-V spec. They run 10,000 random cases plus every edge case: divide by 0, INT_MIN / −1, and signed/unsigned mixes. They also check the start/busy/done handshake (MUL ≤ 2 cycles, DIV ≤ 34).
- **Module correctness:** 37 self-checking testbenches cover every block. Edge cases include x0 writes, shadow-stack full/empty, a write to SHIELD_CTRL while locked, flush during a call, and ROB/LSQ full.
- **Processor level:** On both cores, 48/48 official riscv-tests (RV32I + M) and 18/18 C/assembly programs pass. 20 random programs give the same register and memory results as our Python golden ISS.
- **Security and board:** The attack programs must be caught: trap with the right fault PC/expected/actual, 0 extra cycles on normal code. Then the same programs are run on the Nexys A7 with UART output and an ILA capture (still to do).
