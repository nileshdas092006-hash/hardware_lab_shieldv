# Avani Sharma · G1 datapath

You own the parts of the core that **compute**: where the next instruction is, what it
means, and what result it produces. Together they form a complete single-cycle RV32IM
processor (`core_single.v`), and Laxmidhar's pipelined core reuses every one of them.
Also yours: the **riscv-tests regression** (the official test programs for every
instruction).

## Your files

| Block | RTL (`rtl/`) | Testbench (`tb/`) | What it does |
|---|---|---|---|
| A6 ALU | `alu.v` | `alu_tb.v` (22,000 checks) | add, sub, and, or, xor, shifts, set-less-than (signed and unsigned), pass-through for lui |
| A5 Register file | `regfile.v` | `regfile_tb.v` | 32 × 32-bit, 2 read ports, 1 write port, x0 always 0, write-through |
| A4 Immediate gen | `imm_gen.v` | `imm_gen_tb.v` | rebuilds the constant hidden in I, S, B, U, J instructions |
| A3 Decoder | `decoder.v` | `decoder_tb.v` | turns 32 instruction bits into every control signal |
| A7 Branch unit | `branch_unit.v` | `branch_unit_tb.v` | beq…bgeu decisions, jump targets, link value pc+4 |
| A1 PC | `pc_reg.v` | `pc_reg_tb.v` | program counter; next PC = hold / trap / jump target / pc+4 |
| A2 Instruction RAM | `imem.v` | `mem_tb.v` | 16 KB block RAM, loaded from `imem.hex` |
| A15 Data RAM | `dmem.v` | `mem_tb.v` | 16 KB block RAM with byte enables; the stack lives here |
| A13 Writeback mux | `wb_mux.v` | `wb_mux_tb.v` | picks ALU / load / link / M-unit result for rd |
| Single-cycle core | `core_single.v` | `core_single_tb.v` | all of the above as one CPU, runs `fib` (simulation only) |
| riscv-tests env | – | `riscv_tests/riscv_test.h` | lets the official tests run on our bare-metal core |

Run them: `python scripts/run_tests.py alu regfile imm_gen decoder branch pc_reg mem wb_mux core_single`
and `python scripts/riscv_tests.py`.

## The ideas, in plain words

**Why is the immediate so scrambled?** RISC-V keeps the register fields (rd, rs1, rs2) in
the same bit positions in every instruction and puts the sign bit always at bit 31. The
price is that B and J immediates are shuffled. `imm_gen.v` un-shuffles them; most beginner
CPU bugs live here, which is why `imm_gen_tb.v` checks against what the assembler produced.

**Signed vs unsigned compare.** `0xFFFFFFFF` is −1 signed but 4,294,967,295 unsigned. `slt`
and `blt` use `$signed(...)`; `sltu` and `bltu` do not. `alu_tb.v` and `branch_unit_tb.v`
test exactly that edge.

**jalr clears bit 0.** The target of `jalr` is `(rs1 + imm)` with the lowest bit forced to
0. That target is precisely what ShieldV compares on every return.

**Why x0 needs special care.** Writing x0 must do nothing and reading it must give 0, even
in the write-through path. `regfile_tb.v` checks both.

## New on Oct 11: the branch predictor (goal tier, used by the out-of-order core)

| Block | RTL (`rtl/`) | Testbench (`tb/`) | What it does |
|---|---|---|---|
| A16 Bimodal | `bp_bimodal.v` | `bp_bimodal_tb.v` | 64 two-bit counters indexed by the PC |
| A17 gshare | `bp_gshare.v` | `bp_tournament_tb.v` | 256 counters indexed by PC XOR the last 8 outcomes |
| A18 Tournament | `bp_tournament.v` | `bp_tournament_tb.v` | a chooser picks bimodal or gshare per branch; speculative + commit history |
| A19 BTB | `btb.v` | `btb_tb.v` | remembers where each indirect `jalr` went last time |
| A20 Return-address stack | `ras.v` | `ras_tb.v` | predicts returns; a commit copy repairs it after a flush |

In plain words: a 2-bit counter needs two wrong guesses in a row to change its mind, so
one odd loop exit does not spoil the next loop. gshare adds history, so it can learn
"every 4th time this branch falls through". The tournament keeps whichever of the two is
right more often for each branch. Your study: `python scripts/measure.py` prints the
accuracy per workload (target 85 % or better; see `docs/results/overhead.md`).

The RAS is **not** ShieldV's shadow stack: the RAS is a guess that can be wrong and only
costs time; the shadow stack is the security check and stops the program.

## How this matters for ShieldV

- The register file holds `ra` (x1), the return address the attack corrupts.
- The branch unit's `link` (pc+4) is what ShieldV pushes; its `target` is what it checks.
- The data RAM holds the normal stack, the thing the attacker overwrites.
- The PC's `hold` input is how the CPU freezes when ShieldV raises the alarm.

## Your learning loop for each block

1. Read about it (Harris & Harris, *Digital Design and Computer Architecture: RISC-V*, ch. 7).
2. Write `golden/<id>_<block>.md` yourself **before** reading the RTL
   ([template](../../docs/golden-template.md)).
3. Read the RTL and testbench; compare with your table. Every difference is a lesson.
4. Change something on purpose (e.g. break `sra`), rerun the test, watch it fail.
5. Add five plain-language lines to `learning-log.md`.

Your commits: rows **G1-A01 … G1-A24** in [../COMMIT_PLAN.md](../COMMIT_PLAN.md).
