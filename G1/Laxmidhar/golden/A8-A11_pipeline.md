# A8-A11 Pipeline registers, forwarding, hazard and flush units

## What it does

The 3-stage core is IF/ID → EX → MEM/WB, with two pipeline registers between the stages:
`pipe_ifid_ex` (A8a) and `pipe_ex_wb` (A8b). Every instruction carries a `valid` bit, and a
**bubble** is simply `valid = 0`, an instruction that changes nothing. Three small blocks
decide what moves:

- **A9 forward_unit:** EX takes the fresh MEM/WB result instead of the stale register-file value.
- **A10 hazard_unit:** stalls the front of the pipeline while the M-unit is busy or ShieldV has frozen the core.
- **A11 flush_unit:** turns the wrongly fetched instruction behind a taken branch into a bubble.

## Ports (the decision blocks)

| block | port | dir | meaning |
|-------|------|-----|---------|
| A9 | `ex_rs1`, `ex_rs2` | in | source registers of the instruction in EX |
| A9 | `wb_valid`, `wb_reg_write`, `wb_rd` | in | the instruction in MEM/WB and the register it writes |
| A9 | `fwd_a`, `fwd_b` | out | 1 = EX operand a / b takes the MEM/WB value |
| A10 | `m_wait` | in | MUL/DIV in EX, M-unit not done yet |
| A10 | `sh_freeze` | in | ShieldV caught a bad return |
| A10 | `stall`, `wb_bubble` | out | hold PC, IF/ID and EX; send a bubble into MEM/WB |
| A11 | `ex_redirect` | in | taken branch, `jal` or `jalr` leaving EX |
| A11 | `sh_trap` | in | ShieldV redirects to the trap handler |
| A11 | `flush_ifid`, `kill_ex` | out | IF/ID instruction becomes a bubble; EX instruction must not finish |

## A9 forwarding: input -> expected output

| case | EX instr | MEM/WB instr | wb_valid | expected fwd_a / fwd_b | why |
|------|----------|--------------|----------|------------------------|-----|
| RAW on rs1 | `sub x6, x5, x3` | `add x5, x1, x2` | 1 | 1 / 0 | x5 is written one stage ahead |
| RAW on rs2 | `sub x6, x3, x5` | `add x5, x1, x2` | 1 | 0 / 1 | same, the other operand |
| both operands | `add x7, x5, x5` | `add x5, x1, x2` | 1 | 1 / 1 | both read x5 |
| load then use | `add x6, x5, x1` | `lw x5, 0(x2)` | 1 | 1 / 0 | load data arrives in MEM/WB, so no load-use stall is needed |
| x0 never forwards | `add x6, x0, x3` | `addi x0, x1, 5` | 1 | 0 / 0 | x0 is always 0, a write to it is thrown away |
| bubble ahead | `sub x6, x5, x3` | (bubble with rd = 5) | 0 | 0 / 0 | a bubble writes nothing |
| no register write | `add x6, x5, x3` | `sw x5, 0(x2)` | 1 | 0 / 0 | a store has no rd (`reg_write = 0`) |
| different register | `sub x6, x4, x3` | `add x5, x1, x2` | 1 | 0 / 0 | no dependency |

## A10 hazard and A11 flush: truth tables

| m_wait | sh_freeze | stall | wb_bubble |
|--------|-----------|-------|-----------|
| 0 | 0 | 0 | 0 |
| 1 | 0 | 1 | 1 |
| 0 | 1 | 1 | 1 |
| 1 | 1 | 1 | 1 |

| ex_redirect | sh_trap | flush_ifid | kill_ex |
|-------------|---------|------------|---------|
| 0 | 0 | 0 | 0 |
| 1 | 0 | 1 | 0 |
| 0 | 1 | 1 | 1 |
| 1 | 1 | 1 | 1 |

## Expected waveforms

**Taken branch (flush).** `beq` at 0x10 is taken to 0x40. The `addi` at 0x14 was already fetched.

```
cycle:         0       1        2       3
IF/ID pc:      0x10    0x14     0x40    0x44
EX pc:         -       0x10     0x14    0x40
EX valid:      0       1        0       1      <- 0x14 arrives as a bubble
ex_redirect:   0       1        0       0
flush_ifid:    0       1        0       0
```

**DIV stall.** `div x5, x1, x2` in EX, done after 34 cycles.

```
cycle:         0     1     2   ...  33    34
EX instr:      div   div   div ...  div   next
m_wait:        1     1     1   ...  1     0
stall:         1     1     1   ...  1     0      <- PC, IF/ID and EX hold
MEM/WB valid:  0     0     0   ...  0     1      <- bubbles, then div writes x5 once
```

**ShieldV freeze.** A bad `ret` in EX: `sh_freeze = 1` in the same cycle, and stays 1 until reset.
The PC never takes the attacker's address and MEM/WB only receives bubbles.

## Edge cases I worry about

- A stall must not write the stalled instruction twice. That is why `wb_bubble = stall`.
- A flushed `call` must never push onto the shadow stack. It reaches EX with `valid = 0`, and ShieldV only acts on `ex_valid`.
- A trap with a branch in the same cycle: `kill_ex = 1` wins, so the bad return does not complete.
- Forwarding only looks one stage back. Older instructions have already written the register file, and the register file's write-through covers the instruction writing this cycle.

Compare with `G1/Laxmidhar/tb/pipe_regs_tb.v`, `hazard_tb.v` and the stall/flush counts from `core_pipe_tb.v` (hazards.S).

---
*Drafted with Claude (AI) from `rtl/pipe_ifid_ex.v`, `pipe_ex_wb.v`, `forward_unit.v`, `hazard_unit.v` and `flush_unit.v` on 27 Oct 2026. Laxmidhar to check every row against the testbenches before committing.
Checked by: Laxmidhar date: 27th October*
