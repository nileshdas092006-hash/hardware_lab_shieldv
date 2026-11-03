# G2-NS19 · RV32M M-unit Viva Questions and Answers

**Owner:** Nishant  
**Area:** RV32M multiply/divide unit (M-unit)  
**Related RTL:** `G2/Nishant/rtl/multiplier.v`, `divider.v`, `munit.v`  
**Related testbenches:** `G2/Nishant/tb/multiplier_tb.v`, `divider_tb.v`, `munit_tb.v`

This document is written as first-person viva preparation. The measurements below are taken from the simulation, synthesis, and Nexys A7 UART outputs recorded during this project. Where a value is not available from those records, it is deliberately not guessed.

---

## A. RV32M and the M-unit architecture

### 1. What is the RV32M extension?

RV32I is the base 32-bit RISC-V integer instruction set. The M extension adds integer multiplication and division instructions. In this project, the M-unit implements eight instructions: `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, and `REMU`.

### 2. What is the purpose of the M-unit?

The M-unit provides the hardware operations needed by the RV32M instructions. It contains a multiplier and a divider behind one common interface. The processor sends an operation and its two operands, waits for completion, and then consumes the 32-bit result.

### 3. Why did we use a start/busy/done handshake?

Multiplication and division have different latencies. The multiplier takes 2 cycles, while the divider takes up to 34 cycles in our tests. The handshake lets the core use one interface without needing to assume that every operation finishes in the same number of cycles.

### 4. What are the handshake signals?

- `start`: the requester pulses this to submit an operation and its operands.
- `busy`: indicates that the M-unit is processing an operation.
- `done`: indicates that the result is ready.
- `result`: the 32-bit output value to consume when the operation completes.

The request protocol is to pulse `start`, wait for `done`, and then use `result`. The design is intended for one operation at a time; the requester should not issue another request while the unit is busy, except for the explicitly tested back-to-back handoff after completion.

### 5. How does `munit.v` choose between the multiplier and divider?

The top operation bit selects the subunit:

- `op[2] = 0`: select the multiplier.
- `op[2] = 1`: select the divider.

The lower two bits, `op[1:0]`, select the particular operation within that subunit. The wrapper gates `start` to the selected subunit, combines the two `busy` signals and the two `done` signals, and selects the divider result when `div_done` is asserted; otherwise it presents the multiplier result.

### 6. What is the complete M-unit operation encoding?

| `op[2:0]` | Instruction | Operation |
|---|---|---|
| `000` | `MUL` | Low 32 bits of the product |
| `001` | `MULH` | High 32 bits, signed × signed |
| `010` | `MULHSU` | High 32 bits, signed × unsigned |
| `011` | `MULHU` | High 32 bits, unsigned × unsigned |
| `100` | `DIV` | Signed quotient |
| `101` | `DIVU` | Unsigned quotient |
| `110` | `REM` | Signed remainder |
| `111` | `REMU` | Unsigned remainder |

### 7. What is the role of `rst_n`?

`rst_n` is an active-low reset. When it is low, the sequential state and registered values in the multiplier, divider, and M-unit submodules are reset to their initial values. Normal requests are issued after reset is released.

---

## B. Multiplier design

### 8. What is the difference between `MUL` and `MULH`?

`MUL` returns the lower 32 bits of the 64-bit product. `MULH` returns the upper 32 bits when both operands are interpreted as signed 32-bit integers. The high-half instructions are needed because a 32-bit × 32-bit multiplication can produce a 64-bit result.

### 9. What do `MULHSU` and `MULHU` mean?

- `MULHSU` treats operand A as signed and operand B as unsigned, then returns the upper 32 bits.
- `MULHU` treats both operands as unsigned, then returns the upper 32 bits.

The signedness matters for the upper half of the product. The low 32 bits from `MUL` are the same bit pattern whether the inputs are treated as signed or unsigned.

### 10. How does this multiplier support all four multiply instructions?

The RTL converts both 32-bit operands into 33-bit signed values before multiplication. For an operand that is meant to be signed, its sign bit is copied into bit 32. For an operand that is meant to be unsigned, bit 32 is set to zero. One signed 33 × 33 multiplication is then performed. The RTL selects `product[31:0]` for `MUL`, or `product[63:32]` for the three high-half operations.

### 11. Why is the multiplier described as a 33 × 33 multiplier?

The extra bit on each operand makes the signed and unsigned interpretations work through the same signed multiplication datapath. The product register in the RTL is 66 bits wide. The required RV32M result is selected from the appropriate 32-bit portion.

### 12. How is the multiplier implemented over time?

The multiplier is registered in stages:

1. On the request, it captures the operands with the appropriate signed/unsigned extension and captures the operation.
2. On the following clock, it calculates and registers the product.
3. The `done` indication is generated with the registered product available.

The testbench measures a maximum latency of **2 cycles** for the multiplier.

### 13. Why use FPGA DSP blocks for multiplication?

FPGA DSP slices are dedicated arithmetic resources designed to implement multiply and multiply-accumulate operations efficiently. Using DSP resources avoids building the entire multiplication function from general-purpose LUT logic. In the standalone M-unit synthesis on the target Artix-7 part, Vivado reported **4 DSP48E1 cells**.

---

## C. Divider design

### 14. What algorithm does the divider use?

The divider uses a 32-step restoring division algorithm. It processes one quotient bit per iteration. For each step, it shifts the partial remainder left and brings down the next dividend bit, tries to subtract the divisor, and decides whether to keep the subtraction or restore the previous shifted remainder.

### 15. Why is it called restoring division?

If the trial subtraction would make the partial remainder negative, the algorithm does not keep that subtraction. It restores the previous shifted remainder and sets the current quotient bit to zero. If the subtraction is non-negative, it keeps the subtraction and sets the quotient bit to one.

### 16. Why is the partial remainder 33 bits wide?

The partial remainder needs one extra bit so the trial subtraction can show whether it went negative. The RTL uses a 33-bit `rem` and 33-bit trial subtraction to determine whether the divisor fits at each iteration.

### 17. How are signed division and signed remainder handled?

For signed operations, the divider records the signs of the operands, converts negative inputs to their magnitudes, and performs the unsigned restoring-division iterations. At the end:

- The quotient is negated if exactly one input was negative.
- The remainder is negated if the original dividend was negative.

This gives truncation toward zero for signed division, and the remainder has the sign of the dividend.

### 18. What is the difference between `DIV`, `DIVU`, `REM`, and `REMU`?

| Instruction | Inputs interpreted as | Result |
|---|---|---|
| `DIV` | Signed | Quotient |
| `DIVU` | Unsigned | Quotient |
| `REM` | Signed | Remainder |
| `REMU` | Unsigned | Remainder |

The divider uses the same 32-step datapath for the normal signed and unsigned cases, with sign handling for signed operations and a selector for quotient versus remainder.

### 19. What happens when the divisor is zero?

The RISC-V M-extension defines the result; the processor does not raise a divide-by-zero exception for these integer operations:

- `DIV` and `DIVU`: quotient is `0xFFFF_FFFF` (all ones, or −1 when read as signed).
- `REM` and `REMU`: remainder is the original dividend.

The RTL detects a zero divisor and returns the specified special result without running all 32 restoring iterations.

### 20. What happens for `INT_MIN / -1`?

For 32-bit signed arithmetic, `INT_MIN` is `0x8000_0000`. The mathematical positive quotient is not representable in signed 32-bit format. RISC-V specifies:

- `DIV(INT_MIN, -1)` returns `INT_MIN` (`0x8000_0000`).
- `REM(INT_MIN, -1)` returns zero.

The RTL detects this special case and returns those specified values directly.

### 21. Why does division take 34 cycles if the algorithm has 32 steps?

The restoring loop performs 32 quotient-bit iterations, but the complete request-to-result path also includes control/setup and completion sequencing. The divider testbench measures the maximum request-to-done latency as **34 cycles**. The reported 34-cycle value is the measured interface latency, not just the number of arithmetic iterations.

### 22. What states are used by the divider FSM?

The divider has three states:

- `IDLE`: waits for `start` and captures the operation and operands.
- `RUN`: performs the restoring-division iterations and updates the quotient and partial remainder.
- `FIN`: produces the final quotient or remainder, asserts `done`, and returns to `IDLE`.

---

## D. Verification and measured results

### 23. How did you verify the multiplier?

The multiplier testbench uses a reference model based on simulator 64-bit multiplication, with separate signedness rules for `MUL`, `MULH`, `MULHSU`, and `MULHU`. It checks every pair from an eight-value edge set for all four operations, adds the NS13 directed edge cases, and runs 10,000 random cases. The recorded result after the extra edge cases was **10,269 checks passed**, with a maximum latency of **2 cycles**.

### 24. Which multiplier edge cases are important?

Important values include zero, one, all ones (`0xFFFF_FFFF`), `INT_MIN` (`0x8000_0000`), `INT_MAX` (`0x7FFF_FFFF`), and values with mixed upper/lower bits. The additional directed cases exercise signed/unsigned combinations and products near the 32-bit boundaries. They help catch mistakes in sign extension and high-half selection.

### 25. How did you verify the divider?

The divider testbench has a reference model for all four operations, tests every pair from a ten-value edge set for each operation, adds the NS14 directed edge cases, and runs 10,000 random cases. It also checks that `busy` rises during an operation and returns low after completion. The recorded result was **10,417 checks passed**, with a maximum latency of **34 cycles**.

### 26. Which divider edge cases are important?

Important cases include a zero divisor, zero dividend, positive and negative operands, `INT_MIN`, `INT_MAX`, −1, and `INT_MIN / -1`. Both quotient and remainder behavior need to be checked for signed and unsigned operations.

### 27. What does the M-unit testbench verify?

The M-unit testbench exercises all eight operation encodings across 400 handshakes. It compares the real M-unit result against the behavioural M-unit stub, checks the latency limits (2 cycles for multiply and 34 for divide), and includes a back-to-back multiply followed by divide. The recorded output was **400 handshakes passed**.

### 28. What were the combined M-unit simulation results?

The recorded command was:

```bash
python3 scripts/run_tests.py multiplier divider munit
```

The output was:

```text
PASS  Nishant    divider_tb   TEST PASSED (10417 checks, latency 34)
PASS  Nishant    multiplier_tb TEST PASSED (10269 checks, latency 2)
PASS  Nishant    munit_tb     TEST PASSED (400 handshakes)

3/3 testbenches passed
```

### 29. What were the official RV32M test results?

The command was:

```bash
python3 scripts/riscv_tests.py mul div rem
```

All eight RV32M programs passed: `rv32um-div`, `rv32um-divu`, `rv32um-mul`, `rv32um-mulh`, `rv32um-mulhsu`, `rv32um-mulhu`, `rv32um-rem`, and `rv32um-remu`. The recorded result was **8/8 tests passed**. A broader selected subset (`add sub beq jal mul div rem`) also reported **14/14 tests passed**.

### 30. What is the difference between a testbench result and an FPGA board result?

A testbench simulates the RTL and checks its behavior against expected values. On the FPGA board, the compiled processor and peripherals execute in hardware. The UART output from the board is evidence of the running software workload and its reported results; it is not the output of a Verilog testbench running on the FPGA.

---

## E. FPGA synthesis, SoC integration, and board demonstration

### 31. What FPGA part was used for the standalone M-unit synthesis?

The Vivado synthesis log identifies the part as `xc7a100tcsg324-1`, which is the Nexys A7-100T's Artix-7 device. The standalone M-unit was synthesized in out-of-context mode.

### 32. What were the standalone M-unit resource results?

The successful Vivado synthesis reported:

| Resource / result | Measured value |
|---|---:|
| LUT cells | 462 |
| Flip-flops | 214 |
| Latches | 0 |
| DSP48E1 | 4 |
| CARRY4 | 53 |
| Total reported cells | 733 |
| Synthesis errors | 0 |
| Critical warnings | 0 |
| Warnings | 62 |

These are standalone M-unit out-of-context synthesis figures. They are not the resource usage of the complete SoC. The log also reports no constraint files for that block run, so these figures alone should not be presented as proof of full-system timing closure.

### 33. How does the M-unit connect to the rest of the SoC?

The SoC top joins the processor, M-unit, ShieldV, data memory, and memory-mapped I/O devices. The M-unit connects to the core through the start/busy/done interface. This keeps the arithmetic-unit interface separate from the board-specific pins and peripherals.

### 34. What clock frequency is used for the board system?

The project documentation describes a 100 MHz board oscillator being conditioned/divided by the clock/reset block to provide a **50 MHz system clock**. The planned board demonstration is based on the 50 MHz system clock.

### 35. How does UART output reach the laptop?

The UART transmitter is memory-mapped in the SoC. The project interface map lists the UART at address `0x1000_0010`. When software writes a character to the UART data register, the transmitter sends the serial bits to the board's USB-UART bridge. The laptop sees the bridge as a virtual COM port, and a serial terminal displays the received characters.

### 36. What UART settings were used for the Nexys A7 demo?

The recorded terminal configuration was:

- COM port: `COM10` on the demo laptop.
- Baud rate: `115200`.
- Data bits: `8`.
- Parity: none.
- Stop bits: `1`.
- Flow control: none.

This is commonly written as **115200 baud, 8-N-1**. The serial terminal must be open before resetting the processor so that it can capture the program's output.

### 37. What does the seven-segment display show?

The project guide describes the eight-digit seven-segment display as showing the program result in hexadecimal. For example, Fibonacci result 2584 decimal is `0x00000A18`. The UART gives the readable text and performance information, while the display provides a board-level visual result.

### 38. What did you demonstrate on the real board?

The recorded Nexys A7 UART output included:

| Workload | Result | Workload line cycles | Instructions retired | CPI |
|---|---:|---:|---:|---:|
| `fib(18)` | 2584 (`0x00000A18`) | 146,320 | 125,416 | 1.16 |
| Matrix multiplication | 2,088,526,336 (`0x7C7C6200`) | 5,630 | 4,093 | 1.37 |
| Primes below 1000 | 168 | 233,711 | 36,923 | 6.32 |

The primes workload also printed PASS checks for GCD, signed division/remainder, divide-by-zero, and `INT_MIN / -1` behavior. The board UART session also printed a separate `perf:` line with core-level performance counters. I should quote those values directly from the captured output rather than mix them with the per-workload line above.

### 39. What does CPI mean?

CPI means cycles per instruction. It is calculated as the number of cycles divided by the number of retired instructions for the measurement interval. A CPI of 1.16 means the measured interval used about 1.16 cycles per retired instruction on average. The value is an average; it does not mean every instruction takes exactly 1.16 cycles.

### 40. If the TA asks you to change the Fibonacci input, what would you do?

I would change the argument in the Fibonacci C workload, rebuild the software memory images, rebuild the FPGA bitstream, program that bitstream, open the UART terminal, and reset the processor. For example, `fib(17)` should produce 1597 decimal, which is `0x0000063D`. I should prepare the alternate bitstream before the live demo because building it during the presentation would take too long.

---

## F. Short answers to likely follow-up questions

### 41. Can the multiplier and divider execute two independent requests simultaneously?

The wrapper exposes one shared M-unit request interface, and the core-side protocol is one operation at a time. The design does not provide a queue for multiple outstanding M-unit requests.

### 42. Why is division slower than multiplication?

The multiplier performs a registered multiplication and finishes in 2 cycles. The divider is iterative: it computes one quotient bit per restoring step over 32 iterations, with control and completion cycles, so the measured latency is 34 cycles.

### 43. Why does `MUL` not need signedness correction for the low half?

The low 32 bits of a product are the same modulo-2^32 bit pattern whether the 32-bit operands are interpreted as signed or unsigned. Signedness changes the high half, which is why `MULH`, `MULHSU`, and `MULHU` need different operand interpretations.

### 44. Does divide by zero stop the processor?

No. For these RISC-V integer division instructions, divide-by-zero has defined result values. The divider returns all ones for the quotient and the dividend for the remainder. It does not raise a divide-by-zero exception for these cases.

### 45. What is the main design benefit of the shared handshake?

It hides the different internal latencies from the requester. The core uses the same request/wait/result protocol for both multiplier and divider, rather than having separate fixed-latency interfaces.

### 46. What would you improve or verify next?

I would continue testing reset and request timing around completion, confirm the core's handling of a busy M-unit, review synthesis warnings, and measure full-system timing with the complete constraints and implementation flow. I would also verify the board's displayed result alongside the UART log for every workload.

---

## Quick revision sheet

| Topic | Remember |
|---|---|
| Multiply operations | `MUL`, `MULH`, `MULHSU`, `MULHU` |
| Divide/remainder operations | `DIV`, `DIVU`, `REM`, `REMU` |
| Multiplier datapath | One signed 33 × 33 multiply; 66-bit product register |
| Multiplier latency | 2 cycles measured |
| Divider algorithm | 32-step restoring division |
| Divider partial remainder | 33 bits |
| Divider latency | 34 cycles measured |
| Signed quotient sign | Negative if exactly one operand is negative |
| Signed remainder sign | Same sign as dividend |
| Divide by zero | Quotient all ones; remainder equals dividend |
| `INT_MIN / -1` | Quotient `INT_MIN`; remainder 0 |
| M-unit handshake | `start`, `busy`, `done`, `result` |
| M-unit simulation | 10,269 multiplier checks; 10,417 divider checks; 400 handshakes |
| Official RV32M tests | 8/8 passed |
| Standalone M-unit synthesis | 462 LUTs, 214 FFs, 4 DSP48E1, 53 CARRY4 |
| Board UART | COM10, 115200 baud, 8-N-1 |
| Board workloads recorded | Fibonacci, matrix multiplication, primes |

## Commands to remember

Run from the repository root:

```bash
# M-unit unit tests
python3 scripts/run_tests.py multiplier divider munit

# Official RV32M tests
python3 scripts/riscv_tests.py mul div rem

# Rebuild software workloads
python3 scripts/build_sw.py fib matmul primes
```

---

*Prepared for G2-NS19. The measured counts and board outputs in this document are based on the project logs and UART results recorded during development. If a later run produces different results, use the newer measured output and update this document before presenting it as the latest result.*
