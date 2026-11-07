# Stack canaries versus ShieldV (inorder core, simulation, scripts/canary.py)

## Cost: the main computation of each workload

Canaries: built with `-fstack-protector-all`, ShieldV off (SW0 = 0). ShieldV: normal build, ShieldV on (SW0 = 1).

| workload | result (ShieldV / canary) | instructions, ShieldV | cycles, ShieldV | instructions, canaries | cycles, canaries | canary cycle overhead |
|---|---|---|---|---|---|---|
| fib(18) | PASS / PASS | 125416 | 146320 | 196483 | 217387 | +48.6 % |
| fact(12) | PASS / PASS | 164 | 212 | 302 | 350 | +65.1 % |
| qsort | PASS / PASS | 5390 | 6276 | 6724 | 7610 | +21.3 % |
| bintree | PASS / PASS | 4182 | 5055 | 6500 | 7373 | +45.9 % |
| matmul | PASS / PASS | 4093 | 5630 | 4107 | 5644 | +0.2 % |
| primes<1000 | PASS / PASS | 36923 | 233711 | 53059 | 250015 | +7.0 % |

ShieldV's own cycle overhead is 0 (see overhead.md): it checks in parallel with the pipeline and adds no instructions.

## Coverage: which attacks are stopped

| attack | program | SW0 | outcome |
|---|---|---|---|
| linear overflow, no defence | attack | 0 | **hijacked** |
| linear overflow, canaries only | attack_canary | 0 | stopped by the canary check (exit 4) |
| linear overflow, ShieldV only | attack | 1 | stopped by ShieldV before the hijacked return |
| skip-the-canary write, no defence | attack_skip | 0 | **hijacked** |
| skip-the-canary write, canaries only | attack_skip_canary | 0 | **hijacked** |
| skip-the-canary write, ShieldV only | attack_skip | 1 | stopped by ShieldV before the hijacked return |

The canary only notices an overwrite that passes through the canary word. A write that lands directly on the saved return address (out-of-range index) leaves the canary intact; ShieldV compares the return target itself, so the way the address was overwritten does not matter.
