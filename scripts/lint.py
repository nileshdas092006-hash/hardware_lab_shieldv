#!/usr/bin/env python3
"""lint.py - check all Verilog for common mistakes (what `make lint` runs).

Uses Verilator --lint-only if it is installed (catches latches, width
mismatches, unused signals), otherwise falls back to compiling everything
with Icarus Verilog or Vivado's xvlog, which at least catches syntax and
port-connection errors.
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim  # noqa: E402

# warnings that are fine in this code base (documented choices)
VERILATOR_OFF = ["-Wno-DECLFILENAME", "-Wno-UNUSEDSIGNAL", "-Wno-UNUSEDPARAM", "-Wno-PINCONNECTEMPTY"]


def main():
    files = sim.rtl_files()
    if shutil.which("verilator"):
        tops = ["soc_top", "core_single"]
        bad = 0
        for top in tops:
            # -Wno-fatal: real errors (such as a missing module) fail; warnings are only printed
            cmd = ["verilator", "--lint-only", "-Wall", "-Wno-fatal", *VERILATOR_OFF, "--top-module", top, *files]
            r = subprocess.run(cmd, capture_output=True, text=True)
            warned = "%Warning" in r.stderr
            print(f"verilator lint {top}: {'ISSUES' if r.returncode else 'warnings' if warned else 'clean'}")
            if r.returncode or warned:
                print(r.stderr)
            if r.returncode:
                bad += 1
        sys.exit(1 if bad else 0)
    simulator = sim.default_sim()
    try:
        sim.compile_tb("soc_top", files, simulator, name="lint")
        print(f"{simulator}: all {len(files)} RTL files compile and elaborate (install Verilator for deeper checks)")
    except RuntimeError as e:
        print(e)
        sys.exit(1)


if __name__ == "__main__":
    main()
