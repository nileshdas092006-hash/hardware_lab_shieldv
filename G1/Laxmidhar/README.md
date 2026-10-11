# Laxmidhar Mohapatra · G1 pipeline control

You turn the datapath into a **3-stage pipeline** and keep it safe: three instructions
are in flight at once, and your logic makes sure they never step on each other. Also
yours: the **timing diagrams** (1.5 marks), cut from real simulation.

## Your files

| Block | RTL (`rtl/`) | Testbench (`tb/`) | What it does |
|---|---|---|---|
| A12 Load/store unit | `lsu.v` | `lsu_tb.v` | byte enables for sb/sh/sw; alignment and sign-extension for lb/lh/lbu/lhu |
| A8 Pipeline registers | `pipe_ifid_ex.v`, `pipe_ex_wb.v` | `pipe_regs_tb.v` | carry each instruction to the next stage; stall holds, flush makes a bubble |
| A9 Forwarding | `forward_unit.v` | `hazard_tb.v` | sends MEM/WB's fresh result to EX |
| A10 Hazard/stall | `hazard_unit.v` | `hazard_tb.v` | one place that stalls: M-unit busy or ShieldV freeze |
| A11 Flush | `flush_unit.v` | `hazard_tb.v` | kills the wrong-path instruction after a taken branch/jump/trap |
| A14 Trace port | `trace_port.v` | (used by all system tests) | stage PCs, stall, flush, valid every cycle (IF-4) |
| Pipelined core | `core_pipe.v` | `core_pipe_tb.v` + `asm/hazards.S` | everything wired into the real CPU |
| Timing diagram | `/scripts/diagrams.py` (signal list inside) | `python scripts/diagrams.py timing` | the final timing diagram |

Run them: `python scripts/run_tests.py lsu pipe_regs hazard core_pipe`.
`hazards.S` is 11 hand-written hazard tests (ALU→ALU, load→use, load→jalr, taken
branch, jal, DIV→dependent, MUL→MUL, sub-word stores...); `core_pipe_tb` also checks the
pipeline really stalled, flushed and forwarded while running it.

## New on Oct 11: the out-of-order engine (goal tier)

| Block | RTL (`rtl/`) | Testbench (`tb/`) | What it does |
|---|---|---|---|
| A21 Rename table | `rename_table.v` | `rename_table_tb.v` | each register: "in the register file" or "coming from ROB entry N" |
| A22 Reorder buffer | `rob.v` | `rob_tb.v` | 16 entries; results arrive in any order, leave (commit) in program order |
| A23 Reservation station | `rs.v` | `rs_tb.v` | waits for operands on the CDB, issues the first ready one |
| A24 Load/store queue | `lsq.v` | `lsq_tb.v` | stores write at commit; loads go early only when safe; I/O loads only at the head |
| A25 CDB arbiter | `cdb_arbiter.v` | `cdb_arbiter_tb.v` | one result broadcast per cycle (load > M-unit > ALU) |
| Out-of-order core | `core_ooo.v` | `core_ooo_tb.v` (runs `hazards.S`) | everything wired; same ports as `core_pipe.v` |
| Golden model | `/scripts/rv32im_iss.py` | `/scripts/random_diff.py` | random programs compared instruction by instruction on both cores |

Simplifications chosen on purpose (say them in the viva): mispredictions are repaired at
commit, not at execute; no store-to-load forwarding; one instruction dispatched and one
committed per cycle. An ALU result goes on the CDB in the same cycle when the bus is free.
`core_ooo_tb` checks the core really issued out of order while running `hazards.S`.
The final timing diagram: `diagrams/timing_diagram.svg` (`python scripts/diagrams.py timing`).

## The three hazards, in plain words

1. **Data hazard → forwarding.** `add x5,x1,x2` then `sub x6,x5,x3`: sub needs x5 before
   it is written back. `forward_unit.v` sees MEM/WB is about to write x5 and feeds that
   value into EX directly.
2. **Load then use → also forwarding (no stall here).** Our data RAM answers in MEM/WB,
   right behind EX, so the loaded value can be forwarded the same way. A classic
   5-stage pipeline would need a stall; ours does not. Be ready to explain why.
3. **Control hazard → flush.** A taken branch is decided in EX, but IF/ID already
   fetched pc+4. `flush_unit.v` turns that instruction into a bubble (valid = 0).
   Cost: 1 cycle per taken branch or jump.

The only stalls are a busy M-unit (MUL 2 cycles, DIV 34) and a ShieldV freeze.

## Why your blocks matter for ShieldV

- **ShieldV may only count real instructions.** A call fetched down a wrong path and
  flushed must never push. The `ex_valid` you export (IF-3) guarantees that. Examiners
  will ask about this.
- `ex_valid` deliberately ignores `sh_freeze`: ShieldV *makes* `sh_freeze` from
  `ex_valid`, so including it would create a combinational loop.
- A return depends on `ra` loaded just before it: the load→jalr forwarding path is
  exactly what the attack goes through.
- When ShieldV freezes, your hazard unit holds PC, IF/ID and EX indefinitely.

## Timing diagram

There is one timing diagram for the whole project: `diagrams/timing_diagram.svg` (and `.png`),
**12 clock cycles** from a real simulation. `python scripts/diagrams.py timing` runs
`G3/Priynk/sw/workloads/timing_final.S` (in-order core, SW0 = 1), dumps the 12 cycles that start when
the first store to SHIELD_CTRL is in EX and cuts them with `scripts/vcd2wave.py`. In those 12 cycles:
the lock store (`locked` rises), the attacker's store of 0 to SHIELD_CTRL (it stays 0x13), a call
(`push`, `flush`, bubble), a MUL (`stall`, `m_busy`), the return (`pop`), the stack overwrite, `lw ra`
forwarded straight into `ret`, and that `ret` caught (`mismatch`, `trap`). The cycle-by-cycle table is
in `diagrams/README.md`; the signal list is `TIMING_SIGNALS` in `scripts/diagrams.py`.
