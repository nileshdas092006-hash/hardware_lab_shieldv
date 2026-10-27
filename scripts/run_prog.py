#!/usr/bin/env python3
"""run_prog.py - run a C program on the simulated ShieldV SoC.

    python scripts/run_prog.py fib                 # protection on (SW0 = 1)
    python scripts/run_prog.py attack --sw 0       # protection off: expect HACKED
    python scripts/run_prog.py attack --sw 1       # protection on:  expect BLOCKED
    python scripts/run_prog.py all                 # every program, with expectations
    python scripts/run_prog.py fib --vcd           # also dump build/<sim>/soc_tb/fib.vcd
    python scripts/run_prog.py fib --log           # write a Spike-style commit log
    python scripts/run_prog.py fib --log --spike   # same, built to match Spike exactly
    python scripts/run_prog.py all --core ooo      # same programs on the out-of-order core

Prints what the program sent over the UART and checks the outcome.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_sw  # noqa: E402
import sim       # noqa: E402

# program, switches, expected RESULT line prefix
EXPECT = [
    ("hello",       1, "RESULT: EXIT 0"),
    ("fib",         1, "RESULT: EXIT 0"),
    ("fact",        1, "RESULT: EXIT 0"),
    ("qsort",       1, "RESULT: EXIT 0"),
    ("bintree",     1, "RESULT: EXIT 0"),
    ("matmul",      1, "RESULT: EXIT 0"),
    ("primes",      1, "RESULT: EXIT 0"),
    ("deep",        1, "RESULT: EXIT 0"),      # 32 deep: shadow stack full, no false alarm
    ("deep_over",   1, "RESULT: BLOCKED"),     # 33 deep: overflow stops the core (known limit)
    ("fib",         0, "RESULT: EXIT 0"),      # same answer with protection off
    ("attack",      0, "RESULT: HIJACKED"),    # protection off: the attack works
    ("attack",      1, "RESULT: BLOCKED"),     # protection on: frozen at the ret
    ("attack_trap", 1, "RESULT: EXIT 3"),      # trap mode: handler report, exit 3
    ("fnptr",       1, "RESULT: EXIT 3"),      # landing pad violation trapped
    ("lock",        1, "RESULT: EXIT 3"),      # lock set: attacker's CTRL write ignored, trapped
    ("lock_off",    1, "RESULT: HIJACKED"),    # no lock: attacker switches ShieldV off first
    ("attack_canary",      0, "RESULT: EXIT 4"),   # canaries alone catch the linear overflow
    ("attack_skip",        1, "RESULT: BLOCKED"),  # non-linear overwrite: ShieldV catches it
    ("attack_skip_canary", 0, "RESULT: HIJACKED"), # ... canaries alone do not (canary skipped)
    ("attack_skip_canary", 1, "RESULT: BLOCKED"),  # canaries + ShieldV: ShieldV catches it
]

_handle = {}


def soc_handle(simulator, core="inorder"):
    key = (simulator, core)
    if key not in _handle:
        src = sim.rtl_files() + [os.path.join(sim.ROOT, "G2", "Nilesh", "tb", "soc_tb.v")]
        name = "soc_tb" if core == "inorder" else "soc_tb_" + core
        _handle[key] = sim.compile_tb("soc_tb", src, simulator, name=name, defines=sim.CORES[core])
    return _handle[key]


def run_one(prog, sw, simulator, vcd=False, log=False, max_cycles=3_000_000, quiet=False, extra=(), spike=False,
            core="inorder", cflags=(), variant=""):
    """cflags/variant: extra compiler flags, built into build/sw_<variant> (e.g. canaries)"""
    if spike:   # same instructions as Spike: no counters, no UART polling
        out, syms = build_sw.build(prog, os.path.join(sim.BUILD, "sw_spike"), ["-DSPIKE_COMPARE"])
    else:
        out, syms = build_sw.build(prog, os.path.join(sim.BUILD, "sw" + ("_" + variant if variant else "")),
                                   list(cflags))
    plus = [f"imem={os.path.join(out, 'imem.hex')}", f"dmem={os.path.join(out, 'dmem.hex')}",
            f"sw={sw:x}", f"max_cycles={max_cycles}"]
    if "hacked" in syms:
        plus.append(f"hacked={syms['hacked']:x}")
    tag = f"{prog}_sw{sw}" + ("" if core == "inorder" else "_" + core)
    if vcd:
        plus.append(f"vcd={os.path.join(sim.BUILD, simulator, 'soc_tb', tag + '.vcd')}")
    if log:
        plus.append(f"commitlog={os.path.join(out, tag + '.commit.log')}")
    plus += list(extra)
    text = sim.run(soc_handle(simulator, core), [p.replace("\\", "/") for p in plus])
    lines = [l for l in text.splitlines()
             if not l.lstrip().startswith(("INFO:", "Time resolution", "****", "** Copyright", "$finish",
                                           "source ", "#", "run -all", "exit", "quit"))
             and "xsim" not in l and l.strip() not in ("", "$finish called at time")]
    if not quiet:
        print("\n".join(lines))
    result = next((l for l in lines if l.startswith("RESULT:")), "RESULT: none")
    return result, text


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("prog", help="program name, or 'all'")
    ap.add_argument("--sw", type=lambda s: int(s, 0), default=1, help="switch value (bit 0 = protection)")
    ap.add_argument("--sim", default=None, help="iverilog or xsim")
    ap.add_argument("--vcd", action="store_true")
    ap.add_argument("--log", action="store_true")
    ap.add_argument("--max-cycles", type=int, default=3_000_000)
    ap.add_argument("--spike", action="store_true", help="use the Spike-comparison build (see compare_spike.py)")
    ap.add_argument("--core", default="inorder", choices=sorted(sim.CORES), help="which core the SoC uses")
    args = ap.parse_args()
    simulator = args.sim or sim.default_sim()

    if args.prog != "all":
        result, _ = run_one(args.prog, args.sw, simulator, args.vcd, args.log, args.max_cycles, spike=args.spike,
                            core=args.core)
        sys.exit(0 if result.startswith(("RESULT: EXIT 0", "RESULT: BLOCKED")) else 1)

    fails = 0
    for prog, sw, expect in EXPECT:
        result, text = run_one(prog, sw, simulator, quiet=True, log=args.log, core=args.core)
        ok = result.startswith(expect)
        fails += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {prog:12s} SW0={sw}  {result}")
        if not ok:
            print(text)
    print(f"\n{len(EXPECT) - fails}/{len(EXPECT)} program runs as expected")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
