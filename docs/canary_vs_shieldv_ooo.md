# Stack Canaries versus ShieldV — OOO Validation Status

**Commit-plan task:** G2-NS24 (OOO portion)  
**Run date:** 2026-11-06  
**Core configuration:** Out-of-order (`--core ooo`)

## Status: incomplete — no valid OOO cost comparison

The OOO canary benchmark did not complete successfully, so this document deliberately does not provide an OOO instruction/cycle overhead comparison or claim PASS for the recursive workloads.

The attempted command was:

```bash
python3 scripts/canary.py --core ooo
```

The OOO SoC also timed out on recursive workloads when tested independently. A separate differential workload run reported:

| Workload | Golden instructions | OOO result |
|---|---:|---|
| `hello` | 231 | **PASS** |
| `fib` | 125,839 | **PASS** |
| `fact` | 676 | **PASS** |
| `qsort` | 7,418 | **PASS** |
| `bintree` | 5,215 | **PASS** |
| `matmul` | 6,448 | **PASS** |
| `primes` | 40,635 | **PASS** |
| `hazards` | 89 | **PASS** |

The differential workload result was **8/8 matches**.

## Reproduction

```bash
python3 scripts/random_diff.py --workloads --core ooo
python3 scripts/canary.py --core ooo
```

## What remains

Fix the OOO full-program timeout, rerun the complete ShieldV-versus-stack-canary workload and attack matrix on the OOO core, and replace this status report with measured results. Until then, use `docs/results/canary_vs_shieldv.md` for the completed in-order comparison only.
