# C2 + C3 Shadow stack and return compare

## What it does

The shadow stack (C2) is a 32-entry stack of return addresses held in LUTRAM inside
ShieldV. **Nothing on the data bus is connected to it**, so no load or store can change it,
including an attacker's overflowing store. That is the security argument. A call pushes
`pc + 4`. A return pops the top, and the return compare (C3) checks, in the same cycle, that
the address the program is jumping to equals the top. `top` is read without a clock
(asynchronous LUTRAM), so the check costs **zero extra cycles**.

## Ports

| block | port | dir | meaning |
|-------|------|-----|---------|
| C2 | `push`, `pop`, `push_data` | in | from `commit_ctrl` (only valid, unblocked instructions) |
| C2 | `top` | out | the expected return address |
| C2 | `empty`, `full`, `depth` | out | `depth` = number of entries, 0..32 |
| C3 | `is_call`, `is_ret`, `actual` (jump target) | in | from the detector and EX |
| C3 | `mismatch`, `underflow`, `overflow` | out | the three ways a check can fail |

C3 rules: `mismatch = is_ret & ~empty & (actual != top)`, `underflow = is_ret & empty`,
and `overflow = is_call & ~is_ret & full`.

## Golden push / pop sequence

`main` at 0x100 calls `f` at 0x200 (the `jal` sits at 0x10C), and `f` calls `g` (the `jal` sits at 0x214).

| step | instruction in EX | push / pop | expected depth after | expected top after | C3 result | why |
|------|-------------------|------------|----------------------|--------------------|-----------|-----|
| 0 | (reset) | - | 0 | 0 | - | empty |
| 1 | `jal ra, f` at 0x10C | push 0x110 | 1 | 0x110 | ok | return address = pc + 4 |
| 2 | `jal ra, g` at 0x214 | push 0x218 | 2 | 0x218 | ok | |
| 3 | `ret` in g, target 0x218 | pop | 1 | 0x110 | ok: 0x218 = top | normal return |
| 4 | `ret` in f, target 0x110 | pop | 0 | 0 | ok | back in main |
| 5 | **attack:** `ret` at 0x7B8 in `victim`, target 0x718 (`hacked`), top = 0x8BC | none (blocked) | unchanged | unchanged | **mismatch** | freeze in the same cycle; `hacked()` is never fetched |
| 6 | `ret` with the stack empty | none | 0 | 0 | **underflow** | a return with no matching call |
| 7 | `jalr ra, 0(t0)` (swap), top = A, target A, link B | pop + push B | unchanged | B | ok | coroutine swap replaces the top |
| 8 | 32 nested calls | 32 pushes | 32, `full` = 1 | the 32nd address | ok | exactly full is legal (`deep` program) |
| 9 | a 33rd call | none (dropped) | 32 | unchanged | **overflow** | treated as a violation: fail-safe (`deep_over` program, BLOCKED) |

## Expected waveform: attack caught

```
cycle:        n-1        n (ret at 0x7B8 in EX)   n+1
ex_is_ret:    0          1                        1     (EX holds: frozen)
top:          0x8BC      0x8BC                    0x8BC (the real return point in main)
ex_target:    -          0x718                    0x718 (hacked)
mismatch:     0          1                        1
sh_freeze:    0          1                        1     (until reset)
PC:           0x7BC      0x7BC                    0x7BC (0x718 is never fetched)
```

From `run_prog.py attack --sw 1` (27 Oct build): `SHIELDV ALARM ... fault_pc=000007b8 expected=000008bc actual=00000718 cause=1`, `frozen pc=000007bc`. Addresses move if the code changes, so check them against `build/sw/attack/attack.dis`.

## Edge cases I worry about

- A flushed call must not push (no double push). `commit_ctrl` only lets `ex_valid & ~block` through.
- A frozen return must not pop twice while EX holds. `block` stops it.
- Depth 32 is the limit. Deeper legal code is stopped as overflow (a known limitation, listed in the risk table).
- A pop on an empty stack must not wrap the pointer to 63.

Compare with `G3/Priyank/tb/shadow_stack_tb.v`, `shieldv_tb.v` (10 scenarios) and `shieldv_replay_tb.v`.

---
*Drafted with Claude (AI) from `rtl/shadow_stack.v`, `ret_compare.v` and `commit_ctrl.v` on 27 Oct 2026. Rows 8-9 were checked with the `deep` / `deep_over` programs. Priyank to check every row against the testbenches before committing.
Checked by: Priyank date: 27th October*
