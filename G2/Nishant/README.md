# Nishant · G2 RV32M unit

You own the hardware for the eight multiply and divide instructions, wrapped so the core
sees one simple handshake, plus the MUL/DIV test suites.

## Your files

| Block | RTL (`rtl/`) | Testbench (`tb/`) | What it does |
|---|---|---|---|
| B1 Multiplier | `multiplier.v` | `multiplier_tb.v` (10,256 checks) | MUL, MULH, MULHSU, MULHU in 2 cycles on DSP blocks |
| B2 Divider | `divider.v` | `divider_tb.v` (10,400 checks) | DIV, DIVU, REM, REMU, 32-step restoring division, 34 cycles |
| B3 Handshake | `munit.v` | `munit_tb.v` | start/busy/done wrapper (IF-1), routes to mul or div |
| Stub | `munit_stub.v` | used by `munit_tb.v` as a reference | behavioural stand-in for early integration |

Run them: `python scripts/run_tests.py multiplier divider munit`.

## The tricks, in plain words

**One multiplier for four instructions.** MULH, MULHSU and MULHU differ only in whether
each input is signed. Extend each input to 33 bits (copy the sign bit for a signed input,
a 0 for an unsigned one) and a single signed 33 × 33 multiply gives the right answer for
all of them. Vivado maps it onto 4 DSP48E1 blocks.

**Restoring division** is long division on paper, in binary, one bit per clock:
shift the remainder left and bring down the next dividend bit, try subtracting the
divisor, keep the result and write a 1 if it did not go negative, otherwise "restore"
and write a 0. After 32 steps you have quotient and remainder. Signed division divides
the absolute values and fixes the signs at the end.

**The spec's fixed answers** (RISC-V never traps on division):

| Case | Quotient | Remainder |
|---|---|---|
| x / 0 | −1 (0xFFFF_FFFF) | x |
| INT_MIN / −1 (signed) | INT_MIN | 0 |
| −7 / 2 | −3 (rounds toward zero) | −1 (sign of the dividend) |

These finish in 2 cycles instead of 34.

**A Verilog trap we hit while building this.** In
`cond ? 32'hFFFF_FFFF : $signed(a) / $signed(b)` the unsigned constant makes the whole
expression unsigned, so Verilog silently does an *unsigned* division. The reference
models compute the signed quotient in its own `signed` variable first. Ask yourself why
the real `divider.v` does not have this problem (hint: it divides absolute values).

## New on Oct 11

- `munit.v` is unchanged and also runs inside the out-of-order core: rv32um passes there
  too (`python scripts/riscv_tests.py --core ooo mul div rem`).
- Your new study: `python scripts/canary.py` (and `--core ooo`). It builds every workload
  with `-fstack-protector-all` and compares cycles with ShieldV, then runs two attacks: a
  linear overflow (the canary catches it) and an out-of-range write that skips the canary
  (only ShieldV catches it). Output: `docs/results/canary_vs_shieldv.md`.

## Why your unit matters for ShieldV

Matrix multiply and primes/GCD use it, and the 34-cycle divide stall appears in timing
Scenario 1. ShieldV must stay correct while the pipeline waits for you: a return held in
EX for many cycles must pop the shadow stack exactly once.

Your commits: rows **G2-NS01 … G2-NS21** in [../COMMIT_PLAN.md](../COMMIT_PLAN.md).
