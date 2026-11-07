# RV32M Multiply/Divide/Remainder Results on the Out-of-Order Core

**Commit-plan task:** G2-NS22  
**Run date:** 2026-11-06  
**Core configuration:** Out-of-order (`--core ooo`)  
**Command:** `python3 scripts/riscv_tests.py --core ooo`  
**Simulator:** Icarus Verilog

## Result

The official RISC-V test runner completed successfully: **48/48 tests passed**. This set contains 40 RV32I tests and all eight RV32M multiply/divide/remainder tests.

| Test | Operation | Result |
|---|---|---|
| `rv32um-div` | `DIV` — signed quotient | **PASS** |
| `rv32um-divu` | `DIVU` — unsigned quotient | **PASS** |
| `rv32um-mul` | `MUL` — low 32 bits of product | **PASS** |
| `rv32um-mulh` | `MULH` — signed × signed high word | **PASS** |
| `rv32um-mulhsu` | `MULHSU` — signed × unsigned high word | **PASS** |
| `rv32um-mulhu` | `MULHU` — unsigned × unsigned high word | **PASS** |
| `rv32um-rem` | `REM` — signed remainder | **PASS** |
| `rv32um-remu` | `REMU` — unsigned remainder | **PASS** |

## Scope and limitation

These results establish that the eight official RV32M tests pass through the OOO SoC test configuration. They do not establish that every long-running C workload completes correctly on the OOO core.

A separate workload differential run (`python3 scripts/random_diff.py --workloads --core ooo`) reported 4/8 matches:

| Workload | Expected instructions | OOO result |
|---|---:|---|
| `hello` | 231 | **PASS** |
| `fib` | 125,839 | **TIMEOUT** after 2,526,780 cycles; RTL stopped after 286 instructions, PC unknown |
| `fact` | 676 | **TIMEOUT** after 23,520 cycles; RTL stopped after 144 instructions, PC unknown |
| `qsort` | 7,418 | **TIMEOUT** after 158,360 cycles; RTL stopped after 1,892 instructions, PC unknown |
| `bintree` | 5,215 | **TIMEOUT** after 114,300 cycles; RTL stopped after 1,392 instructions, PC unknown |
| `matmul` | 6,448 | **PASS** |
| `primes` | 40,635 | **PASS** |
| `hazards` | 89 | **PASS** |

The official RV32M test result and the C-workload result are separate checks. The latter remains an open OOO integration issue and is not represented as passing here.

## Reproduction

```bash
python3 scripts/riscv_tests.py --core ooo
python3 scripts/random_diff.py --workloads --core ooo
```

The first command is the acceptance check for this report. The second command records the separate broader-workload limitation.
