# G1 · Core · commit plan

65 commits: 32 by Avani, 33 by Laxmidhar (updated 2026-10-11 for the new abstract: the
branch predictor and the out-of-order core are new). All the code already exists in this folder;
the plan adds it to git **one small step at a time, on the dates you study each block**,
so the history shows steady work and you understand each file before you commit it.

How to use it (details in [docs/how-to-commit.md](../docs/how-to-commit.md)):

1. Study the block (read its README section, the RTL and the testbench).
2. Write the files marked **(you write)** yourself: golden tables, learning-log lines.
3. Run the block's test (the command in the "check" column must pass).
4. `git add` exactly the files in the row, `git commit -m "<message>"`, `git push`.
5. Tick the box.

Commit from your **own** GitHub account. Paths are relative to `G1/`.

## Avani · datapath (branch names start with `g1/avani-`)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G1-A01 | Oct 5 | `docs(alu): add golden I/O table for the ALU` | `Avani/golden/A6_alu.md` **(you write)** | – |
| ☐ | G1-A02 | Oct 5 | `test(alu): add self-checking ALU testbench with edge cases` | `Avani/tb/alu_tb.v` | – |
| ☐ | G1-A03 | Oct 6 | `feat(alu): implement RV32I ALU operations` | `Avani/rtl/alu.v` | `run_tests.py alu` |
| ☐ | G1-A04 | Oct 6 | `test(regfile): add golden table and register file testbench` | `Avani/golden/A5_regfile.md` **(you write)**, `Avani/tb/regfile_tb.v` | – |
| ☐ | G1-A05 | Oct 7 | `feat(regfile): add 32x32 register file with x0 and write-through` | `Avani/rtl/regfile.v` | `run_tests.py regfile` |
| ☐ | G1-A06 | Oct 7 | `docs(imm): add immediate table for I/S/B/U/J formats` | `Avani/golden/A4_imm_gen.md` **(you write)** | – |
| ☐ | G1-A07 | Oct 7 | `test(imm): check immediates against assembler output` | `Avani/tb/imm_gen_tb.v` | – |
| ☐ | G1-A08 | Oct 8 | `feat(imm): implement immediate generator` | `Avani/rtl/imm_gen.v` | `run_tests.py imm_gen` |
| ☐ | G1-A09 | Oct 8 | `docs(decoder): add control-word table for RV32IM` | `Avani/golden/A3_decoder.md` **(you write)** | – |
| ☐ | G1-A10 | Oct 8 | `test(decoder): add table-driven decoder testbench` | `Avani/tb/decoder_tb.v` | – |
| ☐ | G1-A11 | Oct 9 | `feat(decoder): implement instruction decoder and control signals` | `Avani/rtl/decoder.v` | `run_tests.py decoder` |
| ☐ | G1-A12 | Oct 9 | `test(branch): add branch compare and jump target tests` | `Avani/tb/branch_unit_tb.v` | – |
| ☐ | G1-A13 | Oct 9 | `feat(branch): implement branch unit with jalr bit-0 clear` | `Avani/rtl/branch_unit.v` | `run_tests.py branch` |
| ☐ | G1-A14 | Oct 10 | `feat(pc): add PC with hold, trap and redirect` | `Avani/rtl/pc_reg.v`, `Avani/tb/pc_reg_tb.v` | `run_tests.py pc_reg` |
| ☐ | G1-A15 | Oct 10 | `test(mem): add instruction and data RAM testbench` | `Avani/tb/mem_tb.v` | – |
| ☐ | G1-A16 | Oct 10 | `feat(mem): add 16 KB instruction RAM loaded from hex` | `Avani/rtl/imem.v` | – |
| ☐ | G1-A17 | Oct 11 | `feat(mem): add 16 KB byte-writable data RAM` | `Avani/rtl/dmem.v` | `run_tests.py mem` |
| ☐ | G1-A18 | Oct 11 | `feat(wb): add writeback mux with testbench` | `Avani/rtl/wb_mux.v`, `Avani/tb/wb_mux_tb.v` | `run_tests.py wb_mux` |
| ☐ | G1-A19 | Oct 11 | `feat(core): wire the single-cycle RV32IM core` | `Avani/rtl/core_single.v` | – |
| ☐ | G1-A20 | Oct 12 | `test(core): run fib on the single-cycle core` | `Avani/tb/core_single_tb.v` | `run_tests.py core_single` |
| ☐ | G1-A21 | Oct 15 | `test(regress): add riscv-tests environment for our core` | `Avani/tb/riscv_tests/riscv_test.h` | – |
| ☐ | G1-A22 | Oct 16 | `test(regress): add riscv-tests runner (rv32ui + rv32um)` | `/scripts/riscv_tests.py` | `riscv_tests.py` (rung I1) |
| ☐ | G1-A23 | Oct 24 | `docs(datapath): add learning log` | `Avani/learning-log.md` **(you write)** | – |
| ☐ | G1-A24 | Oct 31 | `docs(datapath): add datapath block diagram` | `Avani/datapath.drawio` **(you draw)** | – |

### Avani · branch predictor and prediction study (new scope, goal tier)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G1-A25 | Oct 13 | `docs(bp): add golden table for 2-bit counters and gshare indexing` | `Avani/golden/A16-A18_predictor.md` **(you write)** | – |
| ☐ | G1-A26 | Oct 14 | `feat(bp): add bimodal branch history table with testbench` | `Avani/rtl/bp_bimodal.v`, `Avani/tb/bp_bimodal_tb.v` | `run_tests.py bp_bimodal` |
| ☐ | G1-A27 | Oct 15 | `feat(bp): add gshare predictor` | `Avani/rtl/bp_gshare.v` | – |
| ☐ | G1-A28 | Oct 16 | `feat(bp): add tournament chooser with speculative and commit history` | `Avani/rtl/bp_tournament.v`, `Avani/tb/bp_tournament_tb.v` | `run_tests.py bp_tournament` |
| ☐ | G1-A29 | Oct 17 | `feat(btb): add branch target buffer for indirect jumps` | `Avani/rtl/btb.v`, `Avani/tb/btb_tb.v` | `run_tests.py btb` |
| ☐ | G1-A30 | Oct 18 | `feat(ras): add return-address stack with a commit copy` | `Avani/rtl/ras.v`, `Avani/tb/ras_tb.v` | `run_tests.py ras` (M2) |
| ☐ | G1-A31 | Oct 31 | `docs(regress): record riscv-tests on both cores` | `Avani/reports/riscv_both_cores.md` **(from `riscv_tests.py` and `riscv_tests.py --core ooo`)** | M5 |
| ☐ | G1-A32 | Nov 3 | `docs(bp): add prediction-accuracy study` | `Avani/reports/prediction.md` **(you write, from `measure.py`)** | – |

## Laxmidhar · pipeline control (branch names start with `g1/laxmidhar-`)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G1-L01 | Oct 6 | `docs(lsu): add golden table for every load/store width and offset` | `Laxmidhar/golden/A12_lsu.md` **(you write)** | – |
| ☐ | G1-L02 | Oct 7 | `test(lsu): add load/store unit testbench` | `Laxmidhar/tb/lsu_tb.v` | – |
| ☐ | G1-L03 | Oct 8 | `feat(lsu): implement byte enables, alignment and sign extension` | `Laxmidhar/rtl/lsu.v` | `run_tests.py lsu` |
| ☐ | G1-L04 | Oct 10 | `docs(pipeline): add expected waveforms for stall, flush and forward` | `Laxmidhar/golden/A8-A11_pipeline.md` **(you write)** | – |
| ☐ | G1-L05 | Oct 12 | `feat(pipe): add IF/ID-to-EX pipeline register with valid bit` | `Laxmidhar/rtl/pipe_ifid_ex.v` | – |
| ☐ | G1-L06 | Oct 12 | `feat(pipe): add EX-to-MEM/WB pipeline register` | `Laxmidhar/rtl/pipe_ex_wb.v` | – |
| ☐ | G1-L07 | Oct 12 | `test(pipe): check stall holds and flush makes a bubble` | `Laxmidhar/tb/pipe_regs_tb.v` | `run_tests.py pipe_regs` |
| ☐ | G1-L08 | Oct 13 | `feat(fwd): add forwarding unit` | `Laxmidhar/rtl/forward_unit.v` | – |
| ☐ | G1-L09 | Oct 13 | `feat(hazard): add central stall unit (M-unit busy, ShieldV freeze)` | `Laxmidhar/rtl/hazard_unit.v` | – |
| ☐ | G1-L10 | Oct 14 | `feat(flush): flush wrong-path instruction on taken branch or trap` | `Laxmidhar/rtl/flush_unit.v` | – |
| ☐ | G1-L11 | Oct 14 | `test(hazard): test forwarding, stall and flush decisions` | `Laxmidhar/tb/hazard_tb.v` | `run_tests.py hazard` |
| ☐ | G1-L12 | Oct 15 | `feat(trace): add trace port (IF-4)` | `Laxmidhar/rtl/trace_port.v` | – |
| ☐ | G1-L13 | Oct 15 | `feat(core): wire the 3-stage pipelined core` | `Laxmidhar/rtl/core_pipe.v` | `make lint` |
| ☐ | G1-L14 | Oct 16 | `test(core): add directed hazard program in assembly` | `Laxmidhar/tb/asm/hazards.S` | – |
| ☐ | G1-L15 | Oct 17 | `test(core): run hazards.S on the pipeline and count stalls/flushes` | `Laxmidhar/tb/core_pipe_tb.v` | `run_tests.py core_pipe` (rung I1) |
| ☐ | G1-L16 | Oct 20 | `build(timing): add VCD to WaveDrom/SVG converter` | `/scripts/vcd2wave.py` | – |
| ☐ | G1-L17 | Oct 21 | `build(timing): add the diagram script (top block diagram + final timing diagram)` | `/scripts/diagrams.py` | `python scripts/diagrams.py` |
| ☐ | G1-L18 | Oct 30 | `docs(timing): add the final timing diagram of the whole project from simulation` | `/diagrams/timing_diagram.svg`, `/diagrams/timing_diagram.png` | `python scripts/diagrams.py timing` |
| ☐ | G1-L19 | Oct 31 | `docs(timing): explain the final timing diagram cycle by cycle` | `Laxmidhar/timing_notes.md` **(you write)** | – |
| ☐ | G1-L20 | Nov 3 | `docs(timing): add ILA capture of the attack on the board` | `Laxmidhar/ila_attack.png` **(you capture)** | – |
| ☐ | G1-L21 | Nov 4 | `docs(pipeline): add learning log` | `Laxmidhar/learning-log.md` **(you write)** | – |
| ☐ | G1-L22 | Nov 4 | `docs(pipeline): add pipeline control diagram` | `Laxmidhar/pipeline.drawio` **(you draw)** | – |

### Laxmidhar · out-of-order engine and random testing (new scope, goal tier)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G1-L23 | Oct 15 | `docs(ooo): rename a 6-instruction program by hand` | `Laxmidhar/golden/A21_rename.md` **(you write)** | – |
| ☐ | G1-L24 | Oct 17 | `feat(rat): add register alias table with testbench` | `Laxmidhar/rtl/rename_table.v`, `Laxmidhar/tb/rename_table_tb.v` | `run_tests.py rename` (M2) |
| ☐ | G1-L25 | Oct 20 | `docs(rob): trace the same program through the ROB by hand` | `Laxmidhar/golden/A22_rob.md` **(you write)** | – |
| ☐ | G1-L26 | Oct 21 | `feat(rob): add 16-entry reorder buffer with testbench` | `Laxmidhar/rtl/rob.v`, `Laxmidhar/tb/rob_tb.v` | `run_tests.py rob_tb` |
| ☐ | G1-L27 | Oct 23 | `feat(rs): add reservation station with CDB wake-up` | `Laxmidhar/rtl/rs.v`, `Laxmidhar/tb/rs_tb.v` | `run_tests.py rs_tb` |
| ☐ | G1-L28 | Oct 24 | `feat(lsq): add load/store queue with memory-ordering rules` | `Laxmidhar/rtl/lsq.v`, `Laxmidhar/tb/lsq_tb.v` | `run_tests.py lsq` |
| ☐ | G1-L29 | Oct 25 | `feat(cdb): add common data bus arbiter` | `Laxmidhar/rtl/cdb_arbiter.v`, `Laxmidhar/tb/cdb_arbiter_tb.v` | `run_tests.py cdb` (M4) |
| ☐ | G1-L30 | Oct 28 | `feat(ooo): wire the out-of-order core with the same ports as core_pipe` | `Laxmidhar/rtl/core_ooo.v` | `make lint` |
| ☐ | G1-L31 | Oct 29 | `test(ooo): run hazards.S on the out-of-order core` | `Laxmidhar/tb/core_ooo_tb.v` | `run_tests.py core_ooo` |
| ☐ | G1-L32 | Oct 30 | `test(golden): add RV32IM instruction-set simulator as golden model` | `/scripts/rv32im_iss.py` | `rv32im_iss.py <imem.hex> <dmem.hex> out.log` |
| ☐ | G1-L33 | Oct 31 | `test(random): random programs vs the golden model on both cores` | `/scripts/random_diff.py` | `random_diff.py`, `riscv_tests.py --core ooo` (M5) |

## Group gates (milestones from the abstract)

- **Oct 12 (M1):** single-cycle core runs fib (after G1-A20).
- **Oct 16–18 (M2), rung I1:** riscv-tests rv32ui pass and hazards.S passes on the pipeline
  (after G1-A22, G1-L15); predictor and rename table verified as blocks (after G1-A30, G1-L24).
- **Oct 25 (M4):** reorder buffer, reservation stations and load/store queue verified as blocks (after G1-L29).
- **Oct 29–30, rung I4:** ShieldV freezes the pipeline correctly (`make sim PROG=attack SW=1`).
- **Nov 1 (M5):** out-of-order core passes riscv-tests in simulation (`riscv_tests.py --core ooo`, after G1-L33).
- **Nov 2–6 (M6):** out-of-order core through Vivado (`fpga.py build attack --ooo`), CPI and prediction study.

If you change a file (a fix, a clearer comment), that is an extra commit with `fix(...)`
or `docs(...)`. More small commits are better than fewer big ones; aim for 30+ each.
