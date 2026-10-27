# M-unit MUL/DIV Latency Measurements

## Objective

Record the measured simulation latency of the multiplier and divider
in the RV32M M-unit.

## Test environment

- Repository: hardware_lab_shieldv
- Simulator: Icarus Verilog
- Test command: `python3 scripts/run_tests.py multiplier divider munit`
- Latency unit: clock cycles reported by the testbench

## Results

| Testbench | Operation | Reported latency | Verification result |
|---|---|---:|---|
| `multiplier_tb` | Multiplication | 2 cycles | 10,269 checks passed |
| `divider_tb` | Division | 34 cycles | 10,417 checks passed |
| `munit_tb` | Handshake and integration | Not separately reported | 400 handshakes passed |

## Interpretation

The multiplier testbench reports a latency of 2 cycles, while the
divider testbench reports a latency of 34 cycles. The M-unit testbench
also reports 400 successful handshakes.

These are testbench-reported simulation cycle counts, not wall-clock
execution times or post-route FPGA timing measurements.

## Reproduction

Run the following command from the repository root:

```bash
python3 scripts/run_tests.py multiplier divider munit
