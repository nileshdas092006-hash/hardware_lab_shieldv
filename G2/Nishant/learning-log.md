# Nishant Learning Log — G2 RV32M M-unit

**Owner:** Nishant  
**Area:** RV32M multiply/divide unit and its integration with the RV32IM SoC  
**Updated:** 2026-11-03

This log records the implementation work, engineering points to explain in a viva, and verification evidence captured during the G2 work. Measurements below are taken from the reported test and Vivado outputs; they are not estimates. The date headings for early work follow the commit-plan schedule; where an exact execution date was not present in the captured terminal output, the heading is a planned work window rather than a claim about the precise day the command was run.

## 1. Work log

### 2026-10-05 — M-unit interface and behavioural stub

- Started from the core-facing IF-1 handshake: assert `start` with the operation and operands, wait while `busy` is asserted, and consume `result` when `done` is asserted.
- Kept the core independent of the implementation latency. The core does not need separate multiply and divide control protocols.
- Used `op[2]` to route an operation to the multiplier (`0`) or divider (`1`); `op[1:0]` selects the instruction within that unit.

**Learning:** A stable handshake boundary lets the processor integrate an early behavioural stub and later replace it with the real multi-cycle hardware without changing the core-facing contract.

### 2026-10-05 to 2026-10-07 — Multiplier (B1)

- Studied the four RV32M multiply instructions: `MUL`, `MULH`, `MULHSU`, and `MULHU`.
- Worked through a signed-by-unsigned (`MULHSU`) example and added directed test cases for signedness and boundary operands.
- Implemented one signed 33-by-33-bit multiplication path. Each 32-bit operand is extended to 33 bits: a signed input receives its sign bit in bit 32, while an unsigned input receives zero.
- Selected the low 32 product bits for `MUL`; selected the high 32 bits for `MULH`, `MULHSU`, and `MULHU`.
- The testbench checks directed edge cases and random operands. A later recorded run reported **10,269 checks passed** and a **2-cycle** multiplier latency.

**Learning:** The instruction variants can share one arithmetic datapath when the operand extension is chosen correctly. The signedness of each operand matters independently; `MULHSU` is not the same as signed-by-signed or unsigned-by-unsigned multiplication.

### 2026-10-08 to 2026-10-10 — Divider (B2)

- Studied the four divide/remainder operations: `DIV`, `DIVU`, `REM`, and `REMU`.
- Added golden cases for divide-by-zero and the signed overflow case `INT_MIN / -1`, and traced `13 / 3` by hand using restoring division.
- Implemented a 32-step restoring divider. Each iteration shifts the partial remainder, brings down the next dividend bit, tries a divisor subtraction, and either keeps or restores the partial remainder while producing one quotient bit.
- For signed operations, the implementation divides magnitudes and fixes the quotient and remainder signs at the end. The quotient sign is the XOR of operand signs; the remainder follows the dividend sign.
- Implemented the RISC-V special results without a trap: division by zero returns an all-ones quotient and the original dividend as remainder; `INT_MIN / -1` returns `INT_MIN` and remainder zero.
- A recorded divider testbench run reported **10,417 checks passed** and a **34-cycle** latency.

**Learning:** Restoring division is a sequential algorithm: one quotient bit is resolved per iteration. Signed division is easier to reason about when magnitude division and sign correction are separate. RISC-V defines results for divide-by-zero and signed overflow, so these cases must be tested explicitly rather than treated as processor exceptions.

### 2026-10-11 — M-unit wrapper (B3)

- Connected the multiplier and divider behind the common `start/busy/done` interface.
- Gated the multiplier's start with `start & ~op[2]` and the divider's start with `start & op[2]`.
- Combined the two `busy` signals with OR, and combined the two `done` signals with OR. Selected the divider result when `div_done` is asserted; otherwise the result comes from the multiplier.
- Tested the wrapper against the behavioural stub, including completion pulse length and a multiply followed immediately by a divide.
- The recorded wrapper test reported **400 successful handshakes**.

**Learning:** The wrapper hides the different internal latencies from the core. It also makes it important to test the cycle-level protocol—not only the arithmetic answer—including one-cycle `done` behavior and back-to-back operations.

### 2026-10-14 to 2026-10-15 — Additional edge-case tests

- Added further directed multiplier test cases and reran the multiplier suite.
- Added further directed divider test cases covering signed quotient/remainder combinations, unsigned operations, negative operands, and boundary values.
- The divider run after the additional tests reported **10,417 checks passed**, with **1/1 testbench passed**.

**Learning:** Random testing is useful for breadth, but directed cases are still needed for boundaries and architectural corner cases whose expected behavior is defined by the ISA.

### 2026-10-16 — Standalone M-unit synthesis

- Ran the M-unit out-of-context synthesis for the Nexys A7 device `xc7a100tcsg324-1` using Vivado 2025.2.
- The successful synthesis log reported **462 LUT cells**, **214 flip-flops**, **0 latches**, **4 DSP48E1 cells**, and **53 CARRY4 cells**. The cell-usage table totalled 733 reported cells.
- Vivado reported **0 errors**, **0 critical warnings**, and **62 warnings**. The log also reported that no constraint files were found for this out-of-context run.

**Learning:** RTL-level arithmetic operators can be mapped into FPGA-specific resources; the synthesis report provides evidence of DSP inference. An out-of-context resource report is not, by itself, proof that the complete SoC meets timing on the board. The warnings and the absence of constraints need to be considered when interpreting the report.

### Late October — RV32UM tests with the real core

- Ran `python3 scripts/riscv_tests.py mul div rem` after making the RISC-V compiler and the required local SoC dependencies available.
- All eight reported programs passed: `rv32um-div`, `rv32um-divu`, `rv32um-mul`, `rv32um-mulh`, `rv32um-mulhsu`, `rv32um-mulhu`, `rv32um-rem`, and `rv32um-remu`.

**Learning:** Unit testbenches validate individual blocks and their handshake, while the assembled ISA tests check that the instructions also work through the processor and system integration path. A successful run must be distinguished from an elaboration/build failure; missing RTL or linker inputs must be resolved before interpreting test results.

### 2026-10-27 — Nexys A7 demonstration

- Connected the Nexys A7 through its USB-JTAG/UART connection and viewed serial output in PuTTY on `COM10` at `115200` baud, 8 data bits, no parity, 1 stop bit, and no flow control.
- Observed the Fibonacci workload report `PASS fib(18) result=2584`, with `cycles=146320`, `instret=125416`, and `cpi=1.16`.
- Observed the matrix-multiply workload report `PASS matmul result=2088526336`, with `cycles=5630`, `instret=4093`, and `cpi=1.37`.
- Observed the primes workload report `PASS primes<1000 result=168`, with `cycles=233711`, `instret=36923`, and `cpi=6.32`. The UART output also reported passing GCD and arithmetic corner-case checks.
- Performance-counter lines were printed by the workload/runtime as part of the UART output.

**Learning:** The board demonstration closes the path from compiled C and memory images to execution on the processor and serial output on the host. The UART terminal must be open before resetting the CPU so the program's output is captured. The UART configuration and the displayed results should be verified on the physical board, not inferred from simulation alone.

## 2. Consolidated verification evidence

| Area | Recorded evidence | Result |
|---|---|---|
| Multiplier | `multiplier_tb` | 10,269 checks; 2-cycle latency; passed |
| Divider | `divider_tb` | 10,417 checks; 34-cycle latency; passed |
| M-unit wrapper | `munit_tb` | 400 handshakes; passed |
| RV32UM integration subset | `riscv_tests.py mul div rem` | 8/8 programs passed |
| Broader selected ISA subset | `riscv_tests.py add sub beq jal mul div rem` | 14/14 programs passed |
| Standalone M-unit synthesis | Vivado 2025.2, `xc7a100tcsg324-1` | 462 LUTs, 214 flip-flops, 0 latches, 4 DSP48E1; 0 errors |
| Physical board UART | Fibonacci, matrix multiplication, primes | PASS outputs observed over COM10 at 115200 baud |

## 3. Reproducibility commands

Run these from the repository root (the Python 3 executable is `python3` in the WSL environment):

```bash
python3 scripts/run_tests.py multiplier divider munit
python3 scripts/riscv_tests.py mul div rem
python3 scripts/riscv_tests.py add sub beq jal mul div rem
```

The standalone M-unit synthesis was run with the project's `synth_block.tcl` for top `munit` in Vivado 2025.2. On this machine, the working Vivado batch launcher was the Windows `vivado.bat` invoked from Windows Command Prompt; the WSL Linux launcher was not available.

For the physical UART demonstration, the recorded terminal settings were `COM10`, `115200`, `8-N-1`, and no flow control.

## 4. Remaining cautions

- The reported **2-cycle multiplier** and **34-cycle divider** figures are the testbench-reported operation latencies; they are not whole-program execution times.
- The standalone M-unit synthesis results are out-of-context resource measurements. The log reported 62 warnings and no constraint files; do not use that report alone to claim full-SoC timing closure.
- The successful RV32UM run proves the eight listed programs passed in that run. Any separate board milestone or workload should be marked complete only when it has been demonstrated on the physical board.
- The project checkout used for local tests required recovered dependencies from the extracted project. Keep owner-specific RTL and software files with their respective owners and avoid including them in Nishant's M-unit commits.
