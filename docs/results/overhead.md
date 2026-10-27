# Protection overhead, CPI and branch prediction (simulation, scripts/measure.py)

## Protection overhead, inorder core

| workload | result | instructions | cycles, protection off | cycles, protection on | overhead | CPI |
|---|---|---|---|---|---|---|
| fib(18) | PASS | 125416 | 146320 | 146320 | +0 | 1.17 |
| fact(12) | PASS | 164 | 212 | 212 | +0 | 1.29 |
| qsort | PASS | 5390 | 6276 | 6276 | +0 | 1.16 |
| bintree | PASS | 4182 | 5055 | 5055 | +0 | 1.21 |
| matmul | PASS | 4093 | 5630 | 5630 | +0 | 1.38 |
| primes<1000 | PASS | 36923 | 233711 | 233711 | +0 | 6.33 |

## Protection overhead, ooo core

| workload | result | instructions | cycles, protection off | cycles, protection on | overhead | CPI |
|---|---|---|---|---|---|---|
| fib(18) | PASS | 125416 | 129265 | 129265 | +0 | 1.03 |
| fact(12) | PASS | 164 | 206 | 206 | +0 | 1.26 |
| qsort | PASS | 5390 | 6947 | 6947 | +0 | 1.29 |
| bintree | PASS | 4182 | 5028 | 5028 | +0 | 1.20 |
| matmul | PASS | 4093 | 4238 | 4238 | +0 | 1.04 |
| primes<1000 | PASS | 36923 | 260062 | 260062 | +0 | 7.04 |

## In-order versus out-of-order (protection on)

| workload | CPI in-order | CPI out-of-order | speed-up (cycles in-order / cycles out-of-order) |
|---|---|---|---|
| fib(18) | 1.17 | 1.03 | 1.13x |
| fact(12) | 1.29 | 1.26 | 1.03x |
| qsort | 1.16 | 1.29 | 0.90x |
| bintree | 1.21 | 1.20 | 1.01x |
| matmul | 1.38 | 1.04 | 1.33x |
| primes<1000 | 6.33 | 7.04 | 0.90x |

Geometric-mean speed-up: **1.04x** (abstract target: >= 1.0x).

## Branch prediction (whole program, protection on)

Counted by the hardware counters BRANCHES (0x1000_0050) and MISPRED (0x1000_0054): every retired branch and jump, and those that had to redirect the front end. The in-order core has no predictor (it always fetches pc+4, so every taken branch or jump counts as a misprediction); the out-of-order core uses the tournament predictor, BTB and return-address stack.

| workload | core | branches + jumps | mispredicted | accuracy |
|---|---|---|---|---|
| fib(18) | inorder | 26714 | 22444 | 16.0 % |
| fib(18) | ooo | 26258 | 1124 | 95.7 % |
| fact(12) | inorder | 1676 | 1575 | 6.0 % |
| fact(12) | ooo | 1213 | 119 | 90.2 % |
| qsort | inorder | 3282 | 2568 | 21.8 % |
| qsort | ooo | 2840 | 448 | 84.2 % |
| bintree | inorder | 2958 | 2529 | 14.5 % |
| bintree | ooo | 2486 | 289 | 88.4 % |
| matmul | inorder | 2773 | 2399 | 13.5 % |
| matmul | ooo | 2310 | 141 | 93.9 % |
| primes<1000 | inorder | 25269 | 18065 | 28.5 % |
| primes<1000 | ooo | 22299 | 1287 | 94.2 % |

Cycles and instructions in the first tables are read by each program around its main computation (0x1000_0020 CYCLE, 0x1000_0024 INSTRET). The branch table covers the whole run, including printing.
