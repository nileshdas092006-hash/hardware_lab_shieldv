#!/usr/bin/env python3
"""canary.py - stack canaries versus ShieldV (Nishant, G2; goal tier).

    python scripts/canary.py                 # in-order core
    python scripts/canary.py --core ooo      # out-of-order core

Two defences against return-address overwrites, compared on the same core:
  * compiler stack canaries: every function is built with -fstack-protector-all
    (an extra word on the stack, stored at entry, checked before return);
    ShieldV switched off (SW0 = 0)
  * ShieldV: normal build, hardware check on (SW0 = 1)

Part 1 - cost: each workload prints the cycles and instructions of its main
computation (hardware counters). Canaries add instructions to every call;
ShieldV adds none.
Part 2 - coverage: which attacks each defence stops
  attack.c       linear overflow (overwrites the canary on the way to ra)
  attack_skip.c  out-of-range index writes that step over the canary
Writes docs/results/canary_vs_shieldv.md.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_sw  # noqa: E402
import run_prog  # noqa: E402
import sim       # noqa: E402

WORKLOADS = ["fib", "fact", "qsort", "bintree", "matmul", "primes"]
LINE = re.compile(r"(PASS|FAIL) (\S+) result=\d+.*?cycles=(\d+) instret=(\d+)")

ATTACKS = [
    # (label, program, switches, what a defence must produce)
    ("linear overflow, no defence",        "attack",             0),
    ("linear overflow, canaries only",     "attack_canary",      0),
    ("linear overflow, ShieldV only",      "attack",             1),
    ("skip-the-canary write, no defence",  "attack_skip",        0),
    ("skip-the-canary write, canaries only", "attack_skip_canary", 0),
    ("skip-the-canary write, ShieldV only", "attack_skip",       1),
]


def first(text):
    m = LINE.search(text)
    return (m.group(1), m.group(2), int(m.group(3)), int(m.group(4))) if m else None


def verdict(result):
    if result.startswith("RESULT: EXIT 4"):
        return "stopped by the canary check (exit 4)"
    if result.startswith(("RESULT: BLOCKED", "RESULT: EXIT 3")):
        return "stopped by ShieldV before the hijacked return"
    if result.startswith("RESULT: HIJACKED"):
        return "**hijacked**"
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--core", default="inorder", choices=sorted(sim.CORES))
    args = ap.parse_args()
    simulator = os.environ.get("SIM") or sim.default_sim()

    rows = []
    for prog in WORKLOADS:
        _, sv = run_prog.run_one(prog, 1, simulator, quiet=True, core=args.core)
        _, ca = run_prog.run_one(prog, 0, simulator, quiet=True, core=args.core,
                                 cflags=build_sw.CANARY, variant="canary")
        a, b = first(sv), first(ca)
        if not a or not b:
            print(f"{prog}: could not read results")
            continue
        rows.append((a[1], a[0], b[0], a[3], a[2], b[3], b[2]))
        print(f"{a[1]:14s} ShieldV: {a[3]:7d} instr {a[2]:7d} cycles | canaries: {b[3]:7d} instr "
              f"{b[2]:7d} cycles ({100.0 * (b[2] - a[2]) / a[2]:+.1f} %)")

    attacks = []
    for label, prog, sw in ATTACKS:
        result, _ = run_prog.run_one(prog, sw, simulator, quiet=True, core=args.core)
        attacks.append((label, prog, sw, verdict(result)))
        print(f"{label:40s} {verdict(result)}")

    out = os.path.join(sim.ROOT, "docs", "results")
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "canary_vs_shieldv.md" if args.core == "inorder" else f"canary_vs_shieldv_{args.core}.md")
    with open(path, "w", newline="\n") as f:
        f.write(f"# Stack canaries versus ShieldV ({args.core} core, simulation, scripts/canary.py)\n\n")
        f.write("## Cost: the main computation of each workload\n\n")
        f.write("Canaries: built with `-fstack-protector-all`, ShieldV off (SW0 = 0). "
                "ShieldV: normal build, ShieldV on (SW0 = 1).\n\n")
        f.write("| workload | result (ShieldV / canary) | instructions, ShieldV | cycles, ShieldV | "
                "instructions, canaries | cycles, canaries | canary cycle overhead |\n|---|---|---|---|---|---|---|\n")
        for r in rows:
            f.write(f"| {r[0]} | {r[1]} / {r[2]} | {r[3]} | {r[4]} | {r[5]} | {r[6]} | "
                    f"{100.0 * (r[6] - r[4]) / r[4]:+.1f} % |\n")
        f.write("\nShieldV's own cycle overhead is 0 (see overhead.md): it checks in parallel with "
                "the pipeline and adds no instructions.\n\n")
        f.write("## Coverage: which attacks are stopped\n\n| attack | program | SW0 | outcome |\n|---|---|---|---|\n")
        for a in attacks:
            f.write(f"| {a[0]} | {a[1]} | {a[2]} | {a[3]} |\n")
        f.write("\nThe canary only notices an overwrite that passes through the canary word. "
                "A write that lands directly on the saved return address (out-of-range index) "
                "leaves the canary intact; ShieldV compares the return target itself, so the way the "
                "address was overwritten does not matter.\n")
    print(f"\nwrote {os.path.relpath(path, sim.ROOT)}")


if __name__ == "__main__":
    main()
