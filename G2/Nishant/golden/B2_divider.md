# B2 Divider — Golden Table (RV32M)

This table is the reference for `G2/Nishant/rtl/divider.v`. Values are 32-bit hexadecimal bit patterns. Signed operations interpret the same patterns as two's-complement values; unsigned operations interpret them as values from 0 through \(2^{32}-1\).

## Operation encoding

| `funct3` / M-unit `op` | Divider `op[1:0]` | Instruction | Result |
|---|---|---|---|
| `100` | `00` | `DIV` | Signed quotient, rounded toward zero |
| `101` | `01` | `DIVU` | Unsigned quotient |
| `110` | `10` | `REM` | Signed remainder; sign follows dividend |
| `111` | `11` | `REMU` | Unsigned remainder |

## Expected results

| Case | `a` (dividend) | `b` (divisor) | `DIV` (`00`) | `DIVU` (`01`) | `REM` (`10`) | `REMU` (`11`) | What it checks |
|---|---:|---:|---:|---:|---:|---:|---|
| Zero dividend | `0x00000000` | `0x00000003` | `0x00000000` | `0x00000000` | `0x00000000` | `0x00000000` | Zero divided by a nonzero divisor |
| 13 / 3 | `0x0000000D` | `0x00000003` | `0x00000004` | `0x00000004` | `0x00000001` | `0x00000001` | Classic restoring-division trace; quotient 4, remainder 1 |
| -7 / 2 | `0xFFFFFFF9` | `0x00000002` | `0xFFFFFFFD` | `0x7FFFFFFC` | `0xFFFFFFFF` | `0x00000001` | Signed quotient truncates toward zero; signed remainder follows dividend |
| -1 / 2 bit patterns | `0xFFFFFFFF` | `0x00000002` | `0x00000000` | `0x7FFFFFFF` | `0xFFFFFFFF` | `0x00000001` | Signed and unsigned quotient/remainder differ |
| 7 / -1 bit patterns | `0x00000007` | `0xFFFFFFFF` | `0xFFFFFFF9` | `0x00000000` | `0x00000000` | `0x00000007` | Unsigned divisor is large; signed divisor is -1 |
| INT_MIN / 1 | `0x80000000` | `0x00000001` | `0x80000000` | `0x80000000` | `0x00000000` | `0x00000000` | Signed minimum, normal divisor |
| INT_MIN / -1 | `0x80000000` | `0xFFFFFFFF` | `0x80000000` | `0x00000000` | `0x00000000` | `0x80000000` | Signed overflow corner case prescribed by RISC-V |
| INT_MIN / 0 | `0x80000000` | `0x00000000` | `0xFFFFFFFF` | `0xFFFFFFFF` | `0x80000000` | `0x80000000` | Divide-by-zero result is defined, not a trap |
| 0x12345678 / 0 | `0x12345678` | `0x00000000` | `0xFFFFFFFF` | `0xFFFFFFFF` | `0x12345678` | `0x12345678` | Remainder-by-zero returns the dividend bit pattern |
| INT_MAX / 3 | `0x7FFFFFFF` | `0x00000003` | `0x2AAAAAAA` | `0x2AAAAAAA` | `0x00000001` | `0x00000001` | Large positive operands |
| All ones / all ones | `0xFFFFFFFF` | `0xFFFFFFFF` | `0x00000001` | `0x00000001` | `0x00000000` | `0x00000000` | Signed -1/-1 and unsigned max/max both equal one |
| Unsigned high-bit dividend | `0x80000000` | `0x7FFFFFFF` | `0xFFFFFFFF` | `0x00000001` | `0xFFFFFFFF` | `0x00000001` | Distinguishes unsigned from signed interpretation |

## RISC-V-defined special cases

- For either quotient instruction, `x / 0` returns `0xFFFFFFFF`.
- For either remainder instruction, `x % 0` returns the original dividend bit pattern `x`.
- Signed `INT_MIN / -1` returns `INT_MIN` (`0x80000000`) and signed `INT_MIN % -1` returns zero.
- Signed quotient rounds toward zero. Thus `-7 / 2 = -3` and `-7 % 2 = -1`.
- These cases do not raise an arithmetic exception in the RISC-V M extension.

## Expected timing / interface

The divider accepts a one-cycle `start` request while idle. Ordinary operations perform 32 restoring iterations, then enter `FIN` where `done` pulses and `result` is updated. The RTL comments index this as start in cycle 0, 32 iteration cycles, and `done` in cycle 33. Divide-by-zero and signed overflow skip the iteration loop and go directly to `FIN`. The surrounding IF-1 contract allows up to 34 cycles.

## Algorithm notes

1. Signed operations first take the absolute values of the dividend and divisor (except the specified special cases).
2. Each `RUN` cycle shifts the next dividend bit into the partial remainder and tries subtracting the divisor.
3. If the subtraction is nonnegative, keep it and append quotient bit `1`; otherwise restore the shifted remainder and append `0`.
4. After 32 iterations, apply the quotient sign (`neg_q`) or remainder sign (`neg_r`) as needed.

## Verification reminder

This document is the expected-value reference, not a claim that a simulation has passed. Use `python scripts/run_tests.py divider` and review the full output before recording a pass in the commit history.
