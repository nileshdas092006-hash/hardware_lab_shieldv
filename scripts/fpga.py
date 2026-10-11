#!/usr/bin/env python3
"""fpga.py - build a bitstream or program the board with Vivado (make fpga / make program).

    python scripts/fpga.py build attack          # compile 'attack', run Vivado, write the bitstream
    python scripts/fpga.py build attack --ila    # same, with the on-chip logic analyzer
    python scripts/fpga.py build attack --ooo    # the out-of-order core instead of the in-order one
    python scripts/fpga.py build fib --no-shield # without ShieldV, to measure what ShieldV costs
    python scripts/fpga.py build --top exerciser_top   # I/O bring-up design, no CPU
    python scripts/fpga.py program               # load build/fpga/fpga_top/fpga_top.bit onto the board
    python scripts/fpga.py block shieldv         # size of one module on its own (LUTs, FFs, latches)
    python scripts/fpga.py project attack        # create a clickable Vivado project and open it

Finds Vivado on the PATH or in the usual install folders, so it works from a
plain PowerShell window without running Vivado's settings script first.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_sw  # noqa: E402
import sim       # noqa: E402


def find_vivado():
    for name in ("vivado", "vivado.bat"):
        p = shutil.which(name)
        if p:
            return p
    for g in sim.VIVADO_GUESSES:
        for d in sorted(glob.glob(g), reverse=True):
            for name in ("vivado.bat", "vivado"):
                cand = os.path.join(d, name)
                if os.path.isfile(cand):
                    return cand
    sys.exit("Vivado not found: install Vivado ML Standard or add it to PATH")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("action", choices=["build", "program", "block", "project"])
    ap.add_argument("prog", nargs="?", default="attack")
    ap.add_argument("--top", default="fpga_top")
    ap.add_argument("--ila", action="store_true")
    ap.add_argument("--ooo", action="store_true", help="build: use the out-of-order core")
    ap.add_argument("--no-shield", action="store_true", help="build: replace ShieldV by its stub")
    ap.add_argument("--no-gui", action="store_true", help="project: create it but do not open Vivado")
    args = ap.parse_args()

    os.makedirs(sim.BUILD, exist_ok=True)
    tcl_dir = os.path.join(sim.ROOT, "G2", "Nilesh", "fpga")
    if args.action == "build":
        if args.top == "fpga_top":
            build_sw.build(args.prog, os.path.join(sim.BUILD, "sw"))
        tcl = os.path.join(tcl_dir, "build.tcl")
        targs = [args.top, args.prog] + (["ila"] if args.ila else []) + (["ooo"] if args.ooo else []) \
            + (["noshield"] if args.no_shield else [])
    elif args.action == "project":
        build_sw.build(args.prog, os.path.join(sim.BUILD, "sw"))
        tcl, targs = os.path.join(tcl_dir, "create_project.tcl"), [args.prog]
    elif args.action == "block":
        tcl, targs = os.path.join(tcl_dir, "synth_block.tcl"), [args.prog]
    else:
        tcl, targs = os.path.join(tcl_dir, "program.tcl"), [args.top]

    cmd = [find_vivado(), "-mode", "batch", "-nojournal", "-log", os.path.join(sim.BUILD, f"vivado_{args.action}.log"),
           "-source", tcl, "-tclargs", *targs]
    print("running:", " ".join(cmd))
    if cmd[0].lower().endswith(".bat"):
        r = subprocess.run(" ".join('"%s"' % c for c in cmd), shell=True)
    else:
        r = subprocess.run(cmd)
    if r.returncode == 0 and args.action == "project" and not args.no_gui:
        xpr = os.path.join(sim.BUILD, "vivado_project", "shieldv.xpr")
        print("opening", xpr)
        gui = [find_vivado(), xpr]
        if gui[0].lower().endswith(".bat"):
            subprocess.Popen(" ".join('"%s"' % c for c in gui), shell=True, cwd=sim.BUILD)
        else:
            subprocess.Popen(gui, cwd=sim.BUILD)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
