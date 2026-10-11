# G1 · Core

**Members:** Avani Sharma (datapath) · Laxmidhar Mohapatra (pipeline control)
**Plan blocks:** A1 to A15 ("Module A" in the build plan)
**Commit plan:** [COMMIT_PLAN.md](COMMIT_PLAN.md)

G1 is the processor itself: the part that fetches, decodes and executes RV32I
instructions. Every other group depends on it, so G1 is the **critical path**. That is
why there are two cores here: Avani's single-cycle core (simple, simulation only) came
first, and Laxmidhar's 3-stage pipeline reuses the same blocks.

## How an instruction moves through the pipeline

```
          IF/ID (stage 1)               EX (stage 2)                  MEM/WB (stage 3)
 ┌─────────────────────────────┐ ┌─────────────────────────────┐ ┌──────────────────────────┐
 │ pc_reg ─► imem (BRAM)        │ │ forward_unit ─► alu          │ │ bus answer ─► lsu (load  │
 │ decoder, imm_gen             │║│ branch_unit (taken? target?) │║│ alignment) ─► wb_mux ─►  │
 │ regfile read (write-through) │║│ M-unit start (IF-1)          │║│ regfile write            │
 │                              │║│ ShieldV check (IF-3)         │║│                          │
 │                              │║│ lsu store side ─► bus (IF-2) │║│                          │
 └─────────────────────────────┘ └─────────────────────────────┘ └──────────────────────────┘
               pipe_ifid_ex ───┘                  pipe_ex_wb ───┘
      hazard_unit (stall) and flush_unit (bubble) control all three stages
```

Four design decisions worth understanding for the viva:

1. **Fetch and decode share one stage** even though the instruction RAM is synchronous
   (answers one clock later). The trick: `pc_reg` also outputs `pc_next`, the address it
   is *about* to hold, and that goes to the RAM. The instruction arrives exactly when the
   PC register takes that value.
2. **No load-use stall.** The data RAM answers in MEM/WB, which is right behind EX, so a
   loaded value can be forwarded to the very next instruction like any ALU result.
3. **Register-file write-through.** An instruction two places behind a writer reads the
   register in the same cycle it is written; the register file hands over the new value.
   (The single-cycle core turns this off: there, writer and reader are the same
   instruction, and it would form a loop.)
4. **ShieldV can stop the PC.** A tampered return is caught in EX; `sh_freeze` holds the
   PC, IF/ID and EX in the same cycle, so the attacker's address is never fetched.

## Who does what

| Member | Blocks | Folder |
|---|---|---|
| Avani | A1 PC, A2 instruction RAM, A3 decoder, A4 immediate gen, A5 register file, A6 ALU, A7 branch unit, A13 writeback mux, A15 data RAM, single-cycle core, riscv-tests | [Avani/](Avani/README.md) |
| Laxmidhar | A8 pipeline registers, A9 forwarding, A10 hazard/stall, A11 flush, A12 load/store unit, A14 trace port, pipelined core, timing diagrams | [Laxmidhar/](Laxmidhar/README.md) |

## New on Oct 11: the out-of-order core (goal tier)

The new abstract adds a second core, `Laxmidhar/rtl/core_ooo.v`, with **exactly the same
ports** as `core_pipe.v`. `soc_top.v` picks one at build time (`--core ooo` in the scripts,
`` `define SHIELDV_OOO `` in Verilog). It reuses Avani's decoder, immediate generator,
register file, ALU, branch unit, PC register and memories, and adds:

```
 FETCH + DISPATCH (one stage)                EXECUTE (out of order)          COMMIT (in order)
 pc_reg -> imem -> decoder -> rename_table -+-> rs (ALU, 4) -> alu/branch -+
   ^  next-PC guess:                        +-> rs (MUL, 2) -> munit ------+-> cdb_arbiter -> rob (16) -> head
   |  bp_tournament, btb, ras (Avani)       +-> lsq (8)     -> data bus ---+   (one result      | shown to ShieldV
   +---- mispredict or trap: flush every entry younger than the head <------  per cycle)        v  (IF-3), then
                                                                                                 register / store
```

ShieldV sees each instruction at the reorder-buffer head, in program order, on the same
IF-3 wires the in-order core drives from EX. Nothing is written to registers or memory
before commit, so a wrong guess (a mispredicted branch, or a return ShieldV traps) is
undone by throwing away every younger entry.

| Member | New blocks (all with testbenches) |
|---|---|
| Avani | A16 `bp_bimodal.v`, A17 `bp_gshare.v`, A18 `bp_tournament.v`, A19 `btb.v`, A20 `ras.v` |
| Laxmidhar | A21 `rename_table.v`, A22 `rob.v`, A23 `rs.v`, A24 `lsq.v`, A25 `cdb_arbiter.v`, `core_ooo.v`; golden model `scripts/rv32im_iss.py`, `scripts/random_diff.py` |

Check it: `python scripts/run_tests.py bp_ btb ras rename rob_tb rs_tb lsq cdb core_ooo`,
`python scripts/riscv_tests.py --core ooo`, `python scripts/run_prog.py all --core ooo`,
`python scripts/random_diff.py`. Results: [docs/results/README.md](../docs/results/README.md).
Top-level block diagram: [diagrams/top_block_diagram.png](../diagrams/top_block_diagram.png).

## Words you will meet

- **Hazard**: the next instruction cannot safely run yet.
  - *Data hazard*: it needs a value that is not in the register file yet. Fixed by
    **forwarding** (pass the fresh value straight across) or a **stall** (wait).
  - *Control hazard*: a branch taken in EX means the instruction already fetched behind it
    is wrong. Fixed by a **flush** (turn it into a bubble).
- **Bubble**: an empty slot, marked `valid = 0`. It never writes a register, never
  touches memory and never touches the shadow stack.
- **Stall**: hold a stage still for a cycle (busy divider, ShieldV freeze).

## Check G1 yourself

```
python scripts/run_tests.py alu regfile imm_gen decoder branch pc_reg mem wb_mux core_single
python scripts/run_tests.py lsu pipe_regs hazard core_pipe
python scripts/riscv_tests.py          # 48/48 official instruction tests
```

## G1 is done when

- riscv-tests rv32ui + rv32um all pass: **done in simulation (48/48)**
- 5+ C programs give the right answer: **done (6 workloads)**
- The core synthesises at ≥ 50 MHz: **done (WNS +0.62 ns at 50 MHz)**
- Both members can answer viva questions on forwarding, stalls and flushes: **your job**
- Goal tier: the out-of-order core passes riscv-tests: **done in simulation (48/48)**; on the
  board: **not yet**
