#!/usr/bin/env python3
"""measure.py - protection overhead, CPI of both cores, branch prediction (make measure).

Runs each workload on the simulated SoC:
  * in-order core, protection on (SW0 = 1) and off (SW0 = 0)
  * out-of-order core, protection on and off
reads the cycle and instruction counts each program prints for its main
computation, and the whole-program counters that crt0 prints at the end
("perf: ... branches=... mispredicts=..."), and writes the tables to
docs/results/overhead.md.

Design goals checked here (from the abstract):
  * protection overhead exactly 0 cycles (the return check runs in parallel)
  * out-of-order CPI: geometric mean speed-up >= 1.0x over in-order
  * branch prediction >= 85 % correct (out-of-order core)

    python scripts/measure.py              # both cores
    python scripts/measure.py --core inorder
"""
import argparse
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_prog  # noqa: E402
import sim       # noqa: E402

WORKLOADS = ["fib", "fact", "qsort", "bintree", "matmul", "primes"]
LINE = re.compile(r"(PASS|FAIL) (\S+) result=\d+.*?cycles=(\d+) instret=(\d+)")
PERF = re.compile(r"perf: core=(\d+) cycles=(\d+) instret=(\d+) branches=(\d+) mispredicts=(\d+)")


def first_result(text):
    m = LINE.search(text)
    return (m.group(1), m.group(2), int(m.group(3)), int(m.group(4))) if m else None


def perf(text):
    m = PERF.search(text)
    return tuple(int(g) for g in m.groups()) if m else None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--core", default="both", choices=["both"] + sorted(sim.CORES))
    args = ap.parse_args()
    simulator = os.environ.get("SIM") or sim.default_sim()
    cores = ["inorder", "ooo"] if args.core == "both" else [args.core]

    res = {}         # (core, prog) -> dict
    for core in cores:
        for prog in WORKLOADS:
            _, on = run_prog.run_one(prog, 1, simulator, quiet=True, core=core)
            _, off = run_prog.run_one(prog, 0, simulator, quiet=True, core=core)
            r_on, r_off, p = first_result(on), first_result(off), perf(on)
            if not r_on or not r_off or not p:
                print(f"{core} {prog}: could not read results")
                continue
            res[(core, prog)] = dict(name=r_on[1], status=r_on[0], c_on=r_on[2], i_on=r_on[3],
                                     c_off=r_off[2], branches=p[3], mispred=p[4])
            d = res[(core, prog)]
            print(f"{core:8s} {d['name']:14s} {d['status']} instr={d['i_on']:7d} cycles off={d['c_off']:7d} "
                  f"on={d['c_on']:7d} overhead={d['c_on'] - d['c_off']:+d} CPI={d['c_on'] / d['i_on']:.2f} "
                  f"branches={d['branches']} mispredicted={d['mispred']}")

    out = os.path.join(sim.ROOT, "docs", "results")
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "overhead.md"), "w", newline="\n") as f:
        f.write("# Protection overhead, CPI and branch prediction (simulation, scripts/measure.py)\n\n")
        for core in cores:
            f.write(f"## Protection overhead, {core} core\n\n")
            f.write("| workload | result | instructions | cycles, protection off | cycles, protection on | overhead | CPI |\n")
            f.write("|---|---|---|---|---|---|---|\n")
            for prog in WORKLOADS:
                d = res.get((core, prog))
                if d:
                    f.write(f"| {d['name']} | {d['status']} | {d['i_on']} | {d['c_off']} | {d['c_on']} | "
                            f"{d['c_on'] - d['c_off']:+d} | {d['c_on'] / d['i_on']:.2f} |\n")
            f.write("\n")
        if len(cores) == 2:
            f.write("## In-order versus out-of-order (protection on)\n\n")
            f.write("| workload | CPI in-order | CPI out-of-order | speed-up (cycles in-order / cycles out-of-order) |\n")
            f.write("|---|---|---|---|\n")
            logs = []
            for prog in WORKLOADS:
                a, b = res.get(("inorder", prog)), res.get(("ooo", prog))
                if a and b:
                    s = a["c_on"] / b["c_on"]
                    logs.append(math.log(s))
                    f.write(f"| {a['name']} | {a['c_on'] / a['i_on']:.2f} | {b['c_on'] / b['i_on']:.2f} | {s:.2f}x |\n")
            if logs:
                gm = math.exp(sum(logs) / len(logs))
                f.write(f"\nGeometric-mean speed-up: **{gm:.2f}x** (abstract target: >= 1.0x).\n\n")
                print(f"geometric-mean speed-up out-of-order vs in-order: {gm:.2f}x")
        f.write("## Branch prediction (whole program, protection on)\n\n")
        f.write("Counted by the hardware counters BRANCHES (0x1000_0050) and MISPRED (0x1000_0054): every "
                "retired branch and jump, and those that had to redirect the front end. The in-order core "
                "has no predictor (it always fetches pc+4, so every taken branch or jump counts as a "
                "misprediction); the out-of-order core uses the tournament predictor, BTB and "
                "return-address stack.\n\n")
        f.write("| workload | core | branches + jumps | mispredicted | accuracy |\n|---|---|---|---|---|\n")
        for prog in WORKLOADS:
            for core in cores:
                d = res.get((core, prog))
                if d and d["branches"]:
                    acc = 100.0 * (1 - d["mispred"] / d["branches"])
                    f.write(f"| {d['name']} | {core} | {d['branches']} | {d['mispred']} | {acc:.1f} % |\n")
        f.write("\nCycles and instructions in the first tables are read by each program around its main "
                "computation (0x1000_0020 CYCLE, 0x1000_0024 INSTRET). The branch table covers the whole "
                "run, including printing.\n")
    print(f"\nwrote {os.path.relpath(os.path.join(out, 'overhead.md'), sim.ROOT)}")


if __name__ == "__main__":
    main()
