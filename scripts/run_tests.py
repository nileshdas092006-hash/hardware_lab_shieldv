#!/usr/bin/env python3
"""run_tests.py - run every unit testbench and report PASS/FAIL (what `make test` runs).

    python scripts/run_tests.py                 # all testbenches
    python scripts/run_tests.py alu divider     # only names containing these words
    python scripts/run_tests.py --sim xsim      # force Vivado's simulator

Every testbench lives in G*/<member>/tb/<name>_tb.v and prints exactly one of
    TEST PASSED ...
    TEST FAILED ...
before calling $finish. A testbench that prints neither counts as failed.
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim       # noqa: E402

# testbenches that need a compiled program: tb name -> program
NEEDS_PROGRAM = {"core_single_tb": "fib", "core_pipe_tb": "hazards", "core_ooo_tb": "hazards"}
# testbenches compiled with Verilog defines: core_ooo_tb needs soc_top built with the out-of-order core
DEFINES = {"core_ooo_tb": ["SHIELDV_OOO"]}
# system testbench driven by run_prog.py instead
SKIP = {"soc_tb"}


def replay_trace(simulator):
    """Run fib on the full SoC with a commit log, then cut the call/return trace."""
    import run_prog
    sys.path.insert(0, os.path.join(sim.ROOT, "G3", "Priynk", "sw", "golden"))
    import make_trace
    run_prog.run_one("fib", 1, simulator, log=True, quiet=True)
    out = os.path.join(sim.BUILD, "sw", "fib")
    trace = os.path.join(out, "fib.trace")
    t = make_trace.make_trace(make_trace.read_commits(os.path.join(out, "fib_sw1.commit.log")))
    with open(trace, "w", newline="\n") as f:
        for instr, pc, target in t:
            f.write("%08x %08x %08x\n" % (instr, pc, target))
    return trace


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filters", nargs="*")
    ap.add_argument("--sim", default=None)
    args = ap.parse_args()
    simulator = args.sim or sim.default_sim()

    rtl = sim.rtl_files()
    tbs = [t for t in sim.testbenches() if os.path.basename(t)[:-2] not in SKIP]
    if args.filters:
        tbs = [t for t in tbs if any(f in os.path.basename(t) for f in args.filters)]

    print(f"simulator: {simulator}, {len(tbs)} testbenches\n")
    results = []
    for tb in tbs:
        name = os.path.basename(tb)[:-2]
        owner = os.path.relpath(tb, sim.ROOT).split(os.sep)[1]
        start = time.time()
        try:
            handle = sim.compile_tb(name, rtl + [tb], simulator, defines=DEFINES.get(name, ()))
            plus = []
            if name in NEEDS_PROGRAM:
                import build_sw
                out, _ = build_sw.build(NEEDS_PROGRAM[name], os.path.join(sim.BUILD, "sw"))
                plus = [f"imem={os.path.join(out, 'imem.hex')}".replace("\\", "/"),
                        f"dmem={os.path.join(out, 'dmem.hex')}".replace("\\", "/")]
            if name == "shieldv_replay_tb":
                plus = ["trace=" + replay_trace(simulator).replace("\\", "/")]
            text = sim.run(handle, plus, timeout=600)
        except Exception as e:                       # compile error etc.
            text = f"TEST FAILED: {e}"
        line = next((l.strip() for l in text.splitlines() if "TEST PASSED" in l or "TEST FAILED" in l),
                    "TEST FAILED: no result printed")
        ok = "TEST PASSED" in line
        results.append(ok)
        print(f"{'PASS' if ok else 'FAIL'}  {owner:10s} {name:22s} {time.time() - start:5.1f}s  {line}")
        if not ok:
            for l in text.splitlines():
                if "FAIL" in l or "ERROR" in l or "Error" in l:
                    print("      " + l.strip())

    passed = sum(results)
    print(f"\n{passed}/{len(results)} testbenches passed")
    sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
    main()
