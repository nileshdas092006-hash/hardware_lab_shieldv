# diagrams/ · the two diagrams of the project

| File | What it is |
|---|---|
| `top_block_diagram.svg` / `.png` | the whole system in one picture, laid out like a datapath (left to right): next-PC logic, instruction memory, decoder and immediate generator, register file, hazard / forwarding / flush units, the IF/ID→EX register, forwarding and operand multiplexers, ALU, branch unit, M-unit handshake, load/store unit, the EX→MEM/WB register and the writeback multiplexer; ShieldV with all its sub-blocks on the right; the M-unit, bus decoder, data memory and every I/O register along the bottom, down to the board pins. The out-of-order core (the other build option) is a box with the same ports |
| `timing_diagram.svg` / `.png` | the whole project in **24 clock cycles** of one real simulation run (in-order core, SW0 = 1): the lock being set, the attacker's store to the locked SHIELD_CTRL being ignored and read back, a branch not taken, a call (push), a MUL stall, the return (pop), a taken branch, the stack overwrite, the bad return trapped (fault registers, violation count), and the security handler starting |

The `.png` files are 2x resolution, for slides and the report. Regenerate both with

```
python scripts/diagrams.py          # or: make diagrams
python scripts/diagrams.py block    # only the block diagram
python scripts/diagrams.py timing   # only the timing diagram (runs the simulation)
```

## Nothing on them is invented

**Block diagram** (`scripts/overview.py`). The layout is chosen by hand so it reads like a
textbook figure, but before anything is drawn the script checks it against the Verilog:

- every box must be a real instance: (parent module, instance name, module), e.g. `u_rob : rob`
  inside `core_ooo.v`. Dashed grey boxes are logic written directly inside a module (no
  instance), e.g. the commit logic in `core_ooo.v`; every signal they list must exist there;
- every wire label must be a real net of that module, and its width (e.g. `[31:0]`) is
  computed from the declaration.

If something is not in the RTL, the script stops with an error instead of drawing it.
Blue arrows are data (name and width), dashed red arrows are 1-bit control. `clk` and
`rst_n` go to every block and are not drawn.

**Timing diagram** (`scripts/diagrams.py timing`). It runs `G3/Priynk/sw/workloads/timing_final.S`
on the simulated SoC, dumps the waveform of the 24 cycles that start when the first store to
SHIELD_CTRL reaches EX, and cuts them with `scripts/vcd2wave.py`. Every value is the value the RTL
had in that clock cycle. The program is written in assembly, with all set-up done before the
window, so that every event of the project happens inside these 24 cycles.
(The diagram labels them 27 to 50, the cycle count since reset; below they are numbered 1 to 24.)

Two things to know when reading it: `branch` and `mispredict` come from the trace port, which is
registered, so they rise one cycle after the branch was in EX. `bus addr` is the ALU output, so it
only means an address in cycles where `bus we` or `bus re` is 1.

| Cycle | EX stage | What you see |
|---|---|---|
| 1 | `sw t3,48(t1)` | SHIELD_CTRL = 0x13 (enable + trap + lock); `locked` rises after this cycle |
| 2 | `sw zero,48(t1)` | the attacker's store of 0 to SHIELD_CTRL; it stays 0x13 (ignored) |
| 3 | `lw t4,48(t1)` | read SHIELD_CTRL back (`bus re`) |
| 4 | `bne t4,t3,fail` | `bus rdata` = 0x13 is forwarded into the branch: equal, so **not taken**, no flush, no stall |
| 5 | `jal ra, scale` | call: `push` (ss depth 1 → 2, ss top 0x764); `flush` of the next instruction; `branch` (cycle 5) for the bne, no `mispredict` |
| 6 | bubble | the flushed slot; `branch` + `mispredict` for the jal |
| 7–9 | `mul a0,a0,a1` | the MUL stays in EX for 3 cycles: `stall` in cycles 7–8, `m_busy` in cycle 8 |
| 10 | `ret` | normal return: `pop` (depth back to 1, ss top 0x38); `flush` |
| 11 | bubble | `branch` + `mispredict` for the ret |
| 12 | `beq a0,a2,1f` | 7 × 3 = 21, so **taken**: `flush` (the `j fail` behind it is thrown away) |
| 13 | bubble | `branch` + `mispredict` for the beq (static "not taken" was wrong) |
| 14 | `sw t2,12(sp)` | the overwrite (`bus we`): the address of `hacked` (0x780) replaces main's saved return address |
| 15 | `lw ra,12(sp)` | the tampered address is loaded (`bus re`, `bus rdata` = 0x780 next cycle) |
| 16 | `ret` | forwarded `ex_target` 0x780 ≠ ss top 0x38: `mismatch` and `trap`; the instruction behind is flushed; no `pop` |
| 17 | bubble | fault registers latched: `fault pc` = 0x774 (the ret), `fault actual` = 0x780; `violations` 0 → 1. IF/ID now holds 0x54, `shield_trap_entry`, not `hacked` |
| 18–19 | `auipc sp` / `addi sp` | the handler gives itself a clean stack (`la sp, __trap_stack_top`) |
| 20–21 | `auipc ra` / `jalr` | `call shield_trap_handler`: `push` (depth 1 → 2, ss top 0x64), `flush` |
| 22 | bubble | `branch` + `mispredict` for the jalr |
| 23–24 | `addi sp` / `sw ra` | the C handler `shield_trap_handler` starts (its prologue); it prints the fault and the program ends with code 3 |
