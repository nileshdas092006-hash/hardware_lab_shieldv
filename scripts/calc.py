#!/usr/bin/env python3
"""calc.py - any function, any value: switch positions and a check in simulation.

    python scripts/calc.py fib 18              # switches to set, then simulate on out-of-order
    python scripts/calc.py fact 10 --core inorder
    python scripts/calc.py fib 18 --off        # with ShieldV off (SW0 down)
    python scripts/calc.py fib 18 --no-sim     # only print the switches
    python scripts/calc.py --list              # the functions and their limits

Functions: fib fact qsort bintree matmul primes nest custom.
The program is G3/Priyank/sw/workloads/calc.c. Each answer is checked against a
separate Python copy of the function below, except custom, which you can change.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_prog  # noqa: E402
import sim       # noqa: E402

M = 0xFFFFFFFF
# name: (number on SW15..SW13, largest value, what the answer means). Limits match calc.c.
FUNCS = {
    "fib":     (0, 47,   "the n-th Fibonacci number, recursive"),
    "fact":    (1, 12,   "n factorial, recursive"),
    "qsort":   (2, 256,  "quicksort n numbers; answer is a checksum of the sorted list"),
    "bintree": (3, 256,  "search tree of n keys; answer is a checksum of the in-order walk"),
    "matmul":  (4, 12,   "multiply two n x n matrices; answer is a checksum of the product"),
    "primes":  (5, 4095, "how many primes are below n"),
    "nest":    (6, 400,  "nest n calls, to show the shadow stack's limit of 32"),
    "custom":  (7, 4095, "your own function, in workloads/calc_custom.c"),
}
SHADOW_ROOM = 31       # shadow stack holds 32; crt0's call to main uses one


def fib(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, (a + b) & M
    return a


def fact(n):
    r = 1
    for i in range(2, n + 1):
        r = r * i & M
    return r


def lcg(x):
    return (x * 1103515245 + 12345) & M


def qsort_sum(n):
    x, a = 12345, []
    for _ in range(n):
        x = lcg(x)
        a.append((x >> 16) & 0x7FFF)
    return sum(v * (k + 1) for k, v in enumerate(sorted(a))) & M


def bintree_sum(n):
    x, keys = 777, set()
    while len(keys) < n:
        x = lcg(x)
        keys.add((x >> 16) & 0x3FF)
    s = 0
    for k in sorted(keys):
        s = (s * 33 + k) & M
    return s


def matmul_sum(n):
    A = [[(i * 3 + j * 5 + 1) & 0xFF for j in range(n)] for i in range(n)]
    B = [[(i * 7 + j * 2 + 3) & 0xFF for j in range(n)] for i in range(n)]
    s = 0
    for i in range(n):
        for j in range(n):
            s = (s * 31 + sum(A[i][k] * B[k][j] for k in range(n))) & M
    return s


def primes_below(n):
    return sum(1 for v in range(2, n) if all(v % d for d in range(2, int(v ** 0.5) + 1)))


EXPECT = {"fib": fib, "fact": fact, "qsort": qsort_sum, "bintree": bintree_sum, "matmul": matmul_sum,
          "primes": primes_below, "nest": lambda n: n}


def switches(name, n, on=True):
    return (FUNCS[name][0] << 13) | (n << 1) | (1 if on else 0)


def show_switches(sw):
    print("\nSet the switches (1 = up), then press CPU_RESET:\n")
    print("  SW  " + " ".join(f"{i:2d}" for i in range(15, -1, -1)))
    print("      " + " ".join(f"{(sw >> i) & 1:2d}" for i in range(15, -1, -1)))
    print("      |function| |------------- value ------------| |ShieldV\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("func", nargs="?", choices=sorted(FUNCS))
    ap.add_argument("n", nargs="?", type=int)
    ap.add_argument("--core", default="ooo", choices=sorted(sim.CORES))
    ap.add_argument("--off", action="store_true", help="ShieldV off (SW0 down)")
    ap.add_argument("--no-sim", action="store_true", help="only print the switch positions")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--max-cycles", type=int, default=30_000_000)
    args = ap.parse_args()

    if args.list or args.func is None or args.n is None:
        for name, (num, top, what) in FUNCS.items():
            print(f"  {num}  {name:8s} n up to {top:<5d} {what}")
        return
    top = FUNCS[args.func][1]
    if not 0 <= args.n <= top:
        sys.exit(f"{args.func}: n must be from 0 to {top}")

    sw = switches(args.func, args.n, not args.off)
    show_switches(sw)
    expect = EXPECT[args.func](args.n) if args.func in EXPECT else None
    if expect is not None:
        print(f"Expected answer: {expect}  (display {expect:08X})")
    if args.no_sim:
        return

    print(f"Simulating on the {args.core} core:\n")
    result, text = run_prog.run_one("calc", sw, sim.default_sim(), core=args.core, max_cycles=args.max_cycles)
    m = re.search(r"answer = (\d+)", text)
    if m:
        got = int(m.group(1))
        ok = expect is None or got == expect
        print(f"\n[{'AS EXPECTED' if ok else 'NOT AS EXPECTED'}] answer {got}"
              + ("" if expect is None else f", Python says {expect}"))
        sys.exit(0 if ok else 1)
    if "BLOCKED" in result:
        print("\n[STOPPED BY SHIELDV] Too many calls nested for the 32-entry shadow stack, so the core "
              "stopped safely.\nThe limit is about 31 nested calls. Try --off to run it unprotected.")
    else:
        print(f"\n[NO ANSWER] {result}. If this says TIMEOUT, raise --max-cycles: the board is much faster.")
    sys.exit(1)


if __name__ == "__main__":
    main()
