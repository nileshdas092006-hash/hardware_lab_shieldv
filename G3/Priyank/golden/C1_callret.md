# C1 Call / return / indirect-jump detector

## What it does

Looks at the instruction in EX and says whether it is a **call** (push `pc+4` onto the
shadow stack), a **return** (pop and compare), or an **indirect jump** that must land on an
`lpad` instruction. It uses the same rules as the ratified RISC-V shadow-stack extension
(Zicfiss). Only `jal` and `jalr` matter, and only **x1 (ra)** and **x5 (t0)** count as link
registers. The block is purely combinational.

## Ports

| port | width | dir | meaning |
|------|-------|-----|---------|
| `instr` | 32 | in | the instruction in EX |
| `is_call` | 1 | out | push `pc + 4` |
| `is_ret` | 1 | out | pop and compare with the jump target |
| `needs_lpad` | 1 | out | indirect jump or call: the target must be an `lpad` (goal tier) |

## The rule table

| instruction | rd | rs1 | meaning | shadow stack |
|-------------|----|-----|---------|--------------|
| `jal` | link (x1/x5) | - | call | push |
| `jal` | other | - | plain jump | - |
| `jalr` | link | other | indirect call | push |
| `jalr` | other | link | return | pop + check |
| `jalr` | link | link, rd ≠ rs1 | coroutine swap | pop + check, then push |
| `jalr` | link | link, rd = rs1 | call | push |
| `jalr` | other | other | indirect jump | - |

## Input -> expected output

| case | assembly | encoding | is_call | is_ret | needs_lpad | why |
|------|----------|----------|---------|--------|------------|-----|
| direct call | `jal ra, +16` | `0x010000EF` | 1 | 0 | 0 | rd = ra |
| plain jump | `jal x0, +16` (`j`) | `0x0100006F` | 0 | 0 | 0 | rd = x0, nothing to remember |
| call via t0 | `jal t0, +16` | `0x010002EF` | 1 | 0 | 0 | x5 is also a link register |
| return | `jalr x0, 0(ra)` (`ret`) | `0x00008067` | 0 | 1 | 0 | rs1 = ra, rd is not a link |
| return via t0 | `jalr x0, 0(t0)` | `0x00028067` | 0 | 1 | 0 | |
| return, result kept | `jalr a0, 0(ra)` | `0x00008567` | 0 | 1 | 0 | rd = a0 is not a link, so this is still a return |
| indirect call | `jalr ra, 0(a5)` | `0x000780E7` | 1 | 0 | **1** | a function-pointer call: push, **and** the target must be an lpad |
| coroutine swap | `jalr ra, 0(t0)` | `0x000280E7` | 1 | 1 | 0 | both are links and different: pop, check, push |
| call, rd = rs1 | `jalr ra, 0(ra)` | `0x000080E7` | 1 | 0 | 0 | same link register: treated as a call |
| indirect jump | `jalr x0, 0(a5)` (`jr a5`) | `0x00078067` | 0 | 0 | **1** | e.g. a switch jump table |
| exempt jump | `jalr x0, 0(t2)` | `0x00038067` | 0 | 0 | 0 | x7 is exempt (Zicfilp, used for software-checked jumps) |
| not a jump | `addi ra, ra, 4` | `0x00408093` | 0 | 0 | 0 | writes ra, but it is not a jump |
| branch | `beq x0, x0, +8` | `0x00000463` | 0 | 0 | 0 | branches never touch the shadow stack |

## Edge cases I worry about

- `jalr` must also have `funct3 = 000`. Any other `funct3` is not a jump.
- A return whose result goes to a normal register (`jalr a0, 0(ra)`) is still a return.
- An attacker cannot hide a return as an `addi`. Only real `jalr`s move the PC, and every one of them is classified.
- These outputs are only acted on when `ex_valid = 1`, so bubbles never push or pop (`commit_ctrl.v`).

Compare with `G3/Priyank/tb/callret_detect_tb.v`.

---
*Drafted with Claude (AI) from `rtl/callret_detect.v` on 27 Oct 2026. The encodings were computed from the RISC-V spec formats. Priyank to check every row against the testbench and the `*.dis` listings before committing.
Checked by: Priyank date: 27th October*
