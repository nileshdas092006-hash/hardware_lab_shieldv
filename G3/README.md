# G3 · ShieldV

**Member:** Priyank Patel (ShieldV hardware and all C software); folder `Priynk/`
**Plan blocks:** C1 to C11 (hardware) and S1 to S7 (software), "Module C" in the build plan
**Commit plan:** [COMMIT_PLAN.md](COMMIT_PLAN.md)

G3 is the reason the project exists: a security unit that stops **return-address
hijacking**, plus the software it protects and the attack it stops.

## The attack, in plain words

`main` calls `victim()`. The call (`jal`/`jalr ra`) puts the return address (the
instruction after the call) in register `ra`; `victim()` saves `ra` on the stack because
it calls another function itself. `victim()` then copies "user input" into a 4-word local
array without checking the length. The copy runs past the end of the array and
overwrites the saved `ra` with the address of `hacked()`. When `victim()` finishes it
reloads `ra` and executes `ret`, and the CPU jumps into `hacked()`.

In our program the saved `ra` sits 28 bytes above the buffer (the 8th word), visible in
`build/sw/attack/attack.dis`:
```
victim: addi sp,sp,-32      # make a 32-byte frame
        sw   ra,28(sp)      # save the return address at the top of the frame
        mv   a0,sp          # buf[] starts at sp+0
        ...  call copy_words  -> writes 8 words: buf[0..3], padding, saved ra
        lw   ra,28(sp)      # reload the (now corrupted) return address
        ret                 # jumps to hacked()  <-- ShieldV catches this
```

## The defence, in plain words

ShieldV keeps a **second copy** of every return address in its own 32-entry memory, the
**shadow stack**, built from FPGA logic (LUTRAM). No wire connects the data bus to it, so
no store (including the attacker's) can change it.

- On every **call** in EX, push `pc + 4`.
- On every **return** in EX, compare where the `ret` wants to go with the top of the
  shadow stack. Equal: pop and carry on. Different: **freeze the CPU in the same cycle**,
  before the PC changes, so zero attacker instructions run.

```
          ex_instr ──► callret_detect ──► is_call / is_ret / needs_lpad
                                │
 ex_valid ──► commit_ctrl ──────┴──► push / pop ──► shadow_stack ──► top
                                                                     │
 ex_target ─────────────────────────► ret_compare ◄──────────────────┘
                                        │ mismatch / underflow / overflow
 lpad_check (goal) ── fail ─────────────┤
                                        ▼
          shield_ctrl (SW0, mode) ──► violation_fsm ──► sh_freeze / sh_trap ──► core
                                        └──► fault_regs (PC, expected, actual) ──► display, UART
```

**What counts as a call or return** (the ratified Zicfiss rules, so ordinary compiled C
works without compiler changes; link registers are x1/ra and x5/t0):

| Kind | Pattern | Shadow stack |
|---|---|---|
| Call | `jal`/`jalr` with rd = x1 or x5 | push |
| Return | `jalr` with rd = x0 and rs1 = x1 or x5 | pop + check |
| Coroutine swap | `jalr` with rd and rs1 both link registers, different | pop + check, then push |
| Indirect jump/call | `jalr` with rs1 not x1/x5/x7 | target must be an `lpad` (goal tier) |

**Modes** (SHIELD_CTRL and switch SW0): off · on/freeze (default) · count-only (never
stops, just counts) · trap (jump to a handler that prints a report) · landing pads.

## New on Oct 11: the lock bit (minimum system)

SHIELD_CTRL bit 4. Boot code turns protection on and sets the lock (one store is enough:
`SHIELD_CTRL = ENABLE | TRAP | LOCK`). From then on `shield_ctrl.v` ignores every write to
SHIELD_CTRL and SHIELD_HANDLER until reset, and SHIELD_STAT bit 30 reads 1. Without it, the
same memory-write bug that overwrites a return address could first store 0 to SHIELD_CTRL.
`shield_ctrl_tb.v` makes 1,001 writes after the lock and checks nothing changes;
`sw/attack/lock.c` is the demo (built twice: `lock` traps, `lock_off` is hijacked).
The lock shows up in the final timing diagram `diagrams/timing_diagram.svg` (program `sw/workloads/timing_final.S`, 12 cycles).

Also new: `sw/attack/attack_skip.c` (an overwrite that steps over a stack canary), a fault
viewer on the board after a trap (SW15..14 choose PC / expected / actual on the display),
and a `perf:` line after every program. SymbiYosys proofs are **planned** (commit G3-P40);
the tool is not installed yet.

## Software

ShieldV needs programs to protect and an attack to stop, so G3 also owns the bare-metal
software in `Priynk/sw/`: startup code, linker script, a tiny runtime that prints over
UART, six workloads, the attack programs and the golden models.

## Status

- Unit tests: detector (15 encodings), shadow stack, and a 9-scenario fake-pipeline test
  of the whole unit (flushed calls, stalled returns, freeze, count-only, trap,
  underflow, overflow, landing pads): all pass.
- Replay of fib's 8,439 calls: 0 false alarms; tampered 100th return caught. The Python
  model `shadow_model.py` gives exactly the same counts.
- Full system: attack hijacks with SW0 = 0, is blocked with SW0 = 1; trap mode prints the
  report; landing-pad violation trapped. 0 cycles overhead on all workloads.
- ShieldV costs 198 LUTs and 0 BRAM on the FPGA (goal: ≤ 500); the whole design grows by
  317 LUTs when it is added (docs/results/cost.md).
- **Not yet done:** the attack on the real board; Zicfiss instructions and spill (stretch).
