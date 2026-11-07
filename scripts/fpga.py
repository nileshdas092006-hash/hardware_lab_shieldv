#!/usr/bin/env python3
"""fpga.py - build a bitstream or program the board with Vivado (make fpga / make program).

    python scripts/fpga.py build attack          # compile 'attack', run Vivado, write the bitstream
    python scripts/fpga.py build attack --ila    # same, with the on-chip logic analyzer
    python scripts/fpga.py build attack --ooo    # the out-of-order core instead of the in-order one
    python scripts/fpga.py build fib --no-shield # without ShieldV, to measure what ShieldV costs
    python scripts/fpga.py build --top exerciser_top   # I/O bring-up design, no CPU
    python scripts/fpga.py program               # load the in-order bitstream onto the board
    python scripts/fpga.py program --ooo         # load the out-of-order bitstream onto the board
    python scripts/fpga.py program calc --ooo    # load another program's bitstream
    python scripts/fpga.py list                  # every bitstream built so far: core, program, timing
    python scripts/fpga.py block shieldv         # size of one module on its own (LUTs, FFs, latches)
    python scripts/fpga.py project attack        # create a clickable Vivado project and open it
    python scripts/fpga.py project attack --ooo  # same, with the out-of-order core (separate folder)

Finds Vivado on the PATH or in the usual install folders, so it works from a
plain PowerShell window without running Vivado's settings script first.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import time

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


def build_tag(args):
    """the folder build.tcl wrote to: build/fpga/<tag>/"""
    tag = args.top + ("_ooo" if args.ooo else "") + ("_noshield" if args.no_shield else "")
    return tag + ("_" + args.prog if args.top == "fpga_top" and args.prog != "attack" else "")


def list_bitstreams():
    """Say what each bitstream holds and whether the RTL has changed since it was built."""
    root = os.path.join(sim.BUILD, "fpga")
    found = sorted(glob.glob(os.path.join(root, "*", "*.bit")))
    if not found:
        print("no bitstreams yet: run  python scripts/fpga.py build attack --ooo")
        return
    newest = max(os.path.getmtime(f) for f in glob.glob(os.path.join(sim.ROOT, "G*", "*", "rtl", "*.v")))
    for bit in found:
        info = {}
        note = os.path.join(os.path.dirname(bit), "build_info.txt")
        if os.path.isfile(note):
            with open(note) as f:
                info = dict(line.split(None, 1) for line in f.read().splitlines() if " " in line)
        stale = "  RTL CHANGED SINCE THIS BUILD: rebuild it" if os.path.getmtime(bit) < newest else ""
        print(f"{os.path.relpath(bit, sim.ROOT)}\n    core: {info.get('core', 'unknown')}, "
              f"ShieldV: {info.get('shieldv', 'unknown')}, program: {info.get('program', 'unknown')}, "
              f"WNS: {info.get('wns_ns', 'unknown')} ns, built "
              f"{time.strftime('%Y-%m-%d %H:%M', time.localtime(os.path.getmtime(bit)))}{stale}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("action", choices=["build", "program", "block", "project", "list"])
    ap.add_argument("prog", nargs="?", default="attack")
    ap.add_argument("--top", default="fpga_top")
    ap.add_argument("--ila", action="store_true")
    ap.add_argument("--ooo", action="store_true", help="build, program, project: the out-of-order core")
    ap.add_argument("--no-shield", action="store_true", help="build, program: ShieldV replaced by its stub")
    ap.add_argument("--no-gui", action="store_true", help="project: create it but do not open Vivado")
    args = ap.parse_args()

    if args.action == "list":
        list_bitstreams()
        return

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
        tcl, targs = os.path.join(tcl_dir, "create_project.tcl"), [args.prog] + (["ooo"] if args.ooo else [])
    elif args.action == "block":
        tcl, targs = os.path.join(tcl_dir, "synth_block.tcl"), [args.prog]
    else:
        tcl, targs = os.path.join(tcl_dir, "program.tcl"), [args.top, build_tag(args)]
        print("loading build/fpga/%s/%s.bit" % (build_tag(args), args.top))

    cmd = [find_vivado(), "-mode", "batch", "-nojournal", "-log", os.path.join(sim.BUILD, f"vivado_{args.action}.log"),
           "-source", tcl, "-tclargs", *targs]
    print("running:", " ".join(cmd))
    if cmd[0].lower().endswith(".bat"):
        r = subprocess.run(" ".join('"%s"' % c for c in cmd), shell=True)
    else:
        r = subprocess.run(cmd)
    if r.returncode == 0 and args.action == "project" and not args.no_gui:
        xpr = os.path.join(sim.BUILD, "vivado_project_ooo" if args.ooo else "vivado_project", "shieldv.xpr")
        print("opening", xpr)
        gui = [find_vivado(), xpr]
        if gui[0].lower().endswith(".bat"):
            subprocess.Popen(" ".join('"%s"' % c for c in gui), shell=True, cwd=sim.BUILD)
        else:
            subprocess.Popen(gui, cwd=sim.BUILD)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
