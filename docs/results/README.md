# Results so far (simulation + Vivado builds, updated 2026-10-11)

Everything below was produced by the scripts in this repository on the team lead's laptop
(Vivado 2025.2 simulator and synthesis). **Nothing has run on the real board yet**: the board
results (UART text, LEDs, ILA captures) still have to be collected in the lab.

## Design goals from the new abstract

| Goal | Target | Measured (both cores unless said) | How |
|---|---|---|---|
| Correctness | 100 % rv32ui + rv32um on both cores; workloads match a reference | **48 / 48 on each core**; 50 / 50 random programs and 8 / 8 workloads match our golden model instruction by instruction on both cores. Spike: **not run** (not installed) | `riscv_tests.py [--core ooo]`, `random_diff.py` |
| Detection | trapped before the redirect, 0 attacker instructions | caught in the same cycle the return is in EX (in-order) or at the ROB head (out-of-order); `hacked()` never executes | `run_prog.py attack --sw 1`, timing T2, T6 |
| Lock integrity | 0 changes after the lock | **0 changes** in 1,001 directed writes; attacker's store of 0 to SHIELD_CTRL ignored on the full system. Formal proof: **planned** | `shield_ctrl_tb`, `run_prog.py lock`, timing T3 |
| Protection overhead | 0 cycles per call / return; clock and LUT cost reported | **0 cycles** on all 6 workloads, both cores; +317 LUTs, +253 FFs, 1.02 ns less slack | [overhead.md](overhead.md), [cost.md](cost.md) |
| MUL / DIV latency | ≤ 2 / ≤ 34 cycles | **2 / 34 cycles** | `multiplier_tb`, `divider_tb` |
| Clock | ≥ 50 MHz in-order; out-of-order as measured | in-order **50 MHz met** (WNS +0.461 ns); out-of-order **50 MHz met** (WNS +0.159 ns); 100 MHz not tried | [cost.md](cost.md) |
| Out-of-order speed | ≥ 1.0x geometric mean | **1.04x** (per workload 0.90x to 1.33x) | [overhead.md](overhead.md) |
| Branch prediction | ≥ 85 % | out-of-order core **84.2 % to 95.7 %**: qsort is below target, the other five workloads above | [overhead.md](overhead.md) |
| Resources | ShieldV ≤ 500 LUTs, 0 BRAM; SoC ≤ 25 % LUTs | ShieldV **198 LUTs, 0 BRAM**; SoC **3.3 %** (in-order) and **15.5 %** (out-of-order) | [cost.md](cost.md) |
| Security correctness | 0 false alarms, 100 % injected caught, canary comparison | 0 false alarms on all workloads and 50 random programs (ShieldV on); injected return caught in the replay test; canary table done | `run_prog.py all`, `shieldv_replay_tb`, [canary_vs_shieldv.md](canary_vs_shieldv.md) |

## Test summary

| Suite | In-order core | Out-of-order core |
|---|---|---|
| Unit testbenches (`make test`, 37 testbenches incl. 11 new) | 37 / 37 pass | (included) |
| Programs, attack, lock and canary scenarios (`run_prog.py all`) | 18 / 18 as expected | 18 / 18 as expected |
| riscv-tests rv32ui + rv32um | 48 / 48 | 48 / 48 |
| Random programs vs golden model (`random_diff.py -n 50`) | 50 / 50 | 50 / 50 |
| Workloads vs golden model (`random_diff.py --workloads`) | 8 / 8 | 8 / 8 |

Skipped riscv-tests: `fence_i` rewrites its own code (our instruction RAM is read-only) and
`ma_data` uses misaligned loads/stores (not supported; C compilers never generate them).

The 18 program runs: hello, fib, fact, qsort, bintree, matmul, primes (SW0 = 1); fib (SW0 = 0);
attack (SW0 = 0 → HIJACKED, SW0 = 1 → BLOCKED); attack_trap and fnptr (trap, exit 3);
lock (trap, exit 3) and lock_off (HIJACKED); attack_canary (canary catches it, exit 4);
attack_skip (BLOCKED); attack_skip_canary (SW0 = 0 → HIJACKED, SW0 = 1 → BLOCKED).

## Canaries versus ShieldV (in-order core; the out-of-order table is the same in shape)

Canaries cost **+0.2 % to +65 %** cycles on the workloads; ShieldV costs 0. Canaries stop the
linear overflow but not the write that skips the canary; ShieldV stops both.
Full tables: [canary_vs_shieldv.md](canary_vs_shieldv.md), [canary_vs_shieldv_ooo.md](canary_vs_shieldv_ooo.md).

## Notes on the numbers

- The branch counts in overhead.md cover the whole program, including printing; the UART
  polling loops depend on timing, so the two cores retire slightly different numbers of branches.
- The in-order core has no predictor (it always fetches pc + 4), so its "accuracy" column only
  shows how often a branch or jump was taken.
- The out-of-order core is slower than the in-order one on qsort (loads wait for older stores,
  no store-to-load forwarding) and primes (DIV-bound, one M-unit operation at a time).
- `soc_tb.v` used to release reset exactly on a clock edge; that race logged the in-order core's
  first instruction twice. It now releases reset between edges; the hardware was never affected.

## Not done yet

- Everything on the real board: UART output, LEDs, the switch demo, ILA captures.
- SymbiYosys proofs of the three ShieldV properties (planned, tool not installed).
- Spike reference runs (tool not installed; our own golden model is used instead).
- Stretch goals: two-wide dispatch, Zicfiss instructions with spill, privilege modes.

## Diagrams

[../../diagrams/top_block_diagram.png](../../diagrams/top_block_diagram.png) and the final timing diagram
[../../diagrams/timing_diagram.png](../../diagrams/timing_diagram.png) (from simulation).
