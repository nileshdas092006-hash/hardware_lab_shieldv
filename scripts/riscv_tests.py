#!/usr/bin/env python3
"""riscv_tests.py - run the official riscv-tests rv32ui + rv32um on the simulated SoC.

    python scripts/riscv_tests.py                # all tests
    python scripts/riscv_tests.py add div        # only these
    python scripts/riscv_tests.py --core ooo     # on the out-of-order core

Steps:
  1. clone github.com/riscv-software-src/riscv-tests into build/riscv-tests (once)
  2. compile each test with our environment (G1/Avani/tb/riscv_tests/riscv_test.h)
     and the same link.ld as the C programs
  3. run it on soc_tb (the full SoC: pipeline + M-unit + ShieldV on)
  4. the test writes 0 to 0x1000_00FC on success, (case << 1) | 1 on failure

Skipped on purpose:
  fence_i  - rewrites its own code; our instruction RAM is read-only
  ma_data  - misaligned loads/stores, which our load/store unit does not support
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_sw  # noqa: E402
import run_prog  # noqa: E402
import sim       # noqa: E402

REPO = "https://github.com/riscv-software-src/riscv-tests.git"
SKIP = {"fence_i", "ma_data"}


def main():
    argv = sys.argv[1:]
    core = "inorder"
    if "--core" in argv:
        core = argv[argv.index("--core") + 1]
        del argv[argv.index("--core"):argv.index("--core") + 2]
    filters = [a for a in argv if not a.startswith("--")]
    simulator = os.environ.get("SIM") or sim.default_sim()
    src = os.path.join(sim.BUILD, "riscv-tests")
    if not os.path.isdir(src):
        subprocess.run(["git", "clone", "--depth", "1", REPO, src], check=True)

    gcc = build_sw.find_tool("riscv-none-elf-gcc")
    objcopy = build_sw.find_tool("riscv-none-elf-objcopy")
    env = os.path.join(sim.ROOT, "G1", "Avani", "tb", "riscv_tests")
    link = os.path.join(build_sw.SW, "link.ld")
    out_root = os.path.join(sim.BUILD, "rvtests")
    handle = run_prog.soc_handle(simulator, core)

    tests = []
    for suite in ("rv32ui", "rv32um"):
        for f in sorted(os.listdir(os.path.join(src, "isa", suite))):
            name = f[:-2]
            if f.endswith(".S") and name not in SKIP and (not filters or any(x in name for x in filters)):
                tests.append((suite, name))

    fails = []
    for suite, name in tests:
        out = os.path.join(out_root, f"{suite}-{name}")
        os.makedirs(out, exist_ok=True)
        elf = os.path.join(out, "test.elf")
        build_sw.run([gcc, "-march=rv32im", "-mabi=ilp32", "-nostdlib", "-nostartfiles", "-mno-relax",
                      "-I", env, "-I", os.path.join(src, "isa", "macros", "scalar"),
                      "-T", link, "-o", elf, os.path.join(src, "isa", suite, name + ".S")])
        build_sw.run([objcopy, "-O", "binary", "-j", ".text", elf, os.path.join(out, "text.bin")])
        build_sw.run([objcopy, "-O", "binary", "-j", ".data", elf, os.path.join(out, "data.bin")])
        build_sw.bin_to_hex(os.path.join(out, "text.bin"), os.path.join(out, "imem.hex"))
        build_sw.bin_to_hex(os.path.join(out, "data.bin"), os.path.join(out, "dmem.hex"))
        text = sim.run(handle, [f"imem={out}/imem.hex".replace("\\", "/"),
                                f"dmem={out}/dmem.hex".replace("\\", "/"), "max_cycles=200000"])
        result = next((l for l in text.splitlines() if l.startswith("RESULT:")), "RESULT: none")
        ok = result.strip() == "RESULT: EXIT 0"
        if not ok:
            code = result.split()[-1]
            detail = f" (failed case {int(code) >> 1})" if code.isdigit() else ""
            fails.append(f"{suite}-{name}")
            print(f"FAIL  {suite}-{name:8s} {result}{detail}")
        else:
            print(f"PASS  {suite}-{name}")
    print(f"\n{len(tests) - len(fails)}/{len(tests)} riscv-tests passed")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
