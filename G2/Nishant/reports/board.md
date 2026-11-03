# FPGA Board Demo — M-unit Lab Notes

**Commit-plan item:** G2-NS18  
**Demo date:** 27 October 2026  
**Board:** Digilent Nexys A7-100T  
**Core clock target:** 50 MHz (as specified by the demo plan)  
**UART terminal:** COM10, 115200 baud, 8 data bits, no parity, 1 stop bit, no flow control

## Purpose

Record the RV32IM workload results observed through the UART terminal during the FPGA mini-demo. The program images were loaded as separate bitstreams; the processor was reset after programming each workload.

## Fibonacci

UART result:

```text
PASS fib(18) result=2584 cycles=146320 instret=125416 cpi=1.16
perf: core=0 cycles=420298 instret=331014 branches=93478 mispredicts=89208 calls=8531 returns=8545 violations=0
```

Expected result: `fib(18) = 2584` decimal (`0x00000A18`).

## Matrix multiplication

UART result:

```text
PASS matmul result=2088526336 cycles=5630 instret=4093 cpi=1.37
perf: core=0 cycles=286105 instret=214787 branches=70588 mispredicts=70214 calls=172 returns=185 violations=0
```

Expected result: `2088526336` decimal (`0x7C7C6200`).

## Primes and arithmetic corner cases

UART results:

```text
PASS primes<1000 result=168 cycles=233711 instret=36923 cpi=6.32
PASS gcd(1071,462) result=21 cycles=0 instret=0
PASS -7/2 result=4294967293 cycles=0 instret=0
PASS -7%2 result=4294967295 cycles=0 instret=0
PASS x/0 result=4294967295 cycles=0 instret=0
PASS x%0 result=4294967289 cycles=0 instret=0
PASS INT_MIN/-1 result=2147483648 cycles=0 instret=0
PASS INT_MIN%-1 result=0 cycles=0 instret=0
perf: core=0 cycles=1985806 instret=1351674 branches=452280 mispredicts=445076 calls=1586 returns=1600 violations=0
```

Expected prime count: `168` primes below 1000. The signed results are printed as 32-bit unsigned decimal representations where applicable; for example, `4294967293` represents `-3` and `4294967295` represents `-1` in 32-bit two's complement.

## Notes

- The UART terminal displayed `PASS` results for Fibonacci, matrix multiplication, and the primes workload.
- Performance counters are the values printed by the running workload. The workload-specific `cycles`, `instret`, and `cpi` fields are reported separately from the aggregate `perf:` line.
- This report records the UART output captured during the demo. Record separate visual confirmation of the seven-segment display and LEDs only if they were observed during the board demonstration.
- The earlier M-unit unit-test results were `multiplier_tb`: 10,269 checks, latency 2 cycles; `divider_tb`: 10,417 checks, latency 34 cycles; and `munit_tb`: 400 handshakes. These are simulation/testbench results, not the workload cycle counts above.
