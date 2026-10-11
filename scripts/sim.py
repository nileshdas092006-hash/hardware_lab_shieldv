#!/usr/bin/env python3
"""sim.py - one small wrapper around the two simulators the team can use.

  * Icarus Verilog (iverilog + vvp): free, fast to start, used by CI on GitHub
  * Vivado xsim (xvlog + xelab + xsim): comes with Vivado, works on Windows

Pick one with the SIM environment variable or --sim (default: iverilog if it
is installed, otherwise xsim).
"""
import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")

# RTL that only makes sense on the FPGA (Xilinx primitives / board pins)
FPGA_ONLY = {"clk_rst.v", "fpga_top.v", "exerciser_top.v"}

VIVADO_GUESSES = [r"C:\AMDDesignTools\*\Vivado\bin", r"C:\Xilinx\Vivado\*\bin",
                  "/tools/Xilinx/Vivado/*/bin", "/opt/Xilinx/Vivado/*/bin"]


def rtl_files():
    files = sorted(glob.glob(os.path.join(ROOT, "G*", "*", "rtl", "*.v")))
    return [f for f in files if os.path.basename(f) not in FPGA_ONLY]


def testbenches():
    return sorted(glob.glob(os.path.join(ROOT, "G*", "*", "tb", "*_tb.v")))


def _which(tool):
    p = shutil.which(tool)
    if p:
        return p
    if tool.startswith("x"):
        for g in VIVADO_GUESSES:
            for d in sorted(glob.glob(g), reverse=True):
                for ext in (".bat", ""):
                    cand = os.path.join(d, tool + ext)
                    if os.path.isfile(cand):
                        return cand
    return None


def default_sim():
    if os.environ.get("SIM"):
        return os.environ["SIM"]
    if _which("iverilog"):
        return "iverilog"
    if _which("xvlog"):
        return "xsim"
    sys.exit("no simulator found: install Icarus Verilog or Vivado")


def _shell(cmd):
    """Vivado's tools are .bat files on Windows. cmd.exe splits batch-file
    arguments at '=' and ',', so every argument is quoted."""
    if os.name == "nt" and cmd[0].lower().endswith(".bat"):
        return " ".join('"%s"' % c for c in cmd), True
    return cmd, False


def _run(cmd, cwd, check=True):
    cmd_, shell = _shell(cmd)
    r = subprocess.run(cmd_, cwd=cwd, capture_output=True, text=True, errors="replace", shell=shell)
    if check and r.returncode != 0:
        sys.stderr.write(f"$ {' '.join(cmd)}\n{r.stdout}{r.stderr}")
        raise RuntimeError(f"{os.path.basename(cmd[0])} failed")
    return r


def compile_tb(top, sources, sim, name=None, defines=()):
    """Compile and elaborate; returns a handle used by run().
    defines: Verilog macros, e.g. ["SHIELDV_OOO"] to build the SoC with the out-of-order core."""
    name = name or top
    work = os.path.join(BUILD, sim, name)
    os.makedirs(work, exist_ok=True)
    if sim == "iverilog":
        out = os.path.join(work, name + ".vvp")
        _run([_which("iverilog"), "-g2005", "-Wall", "-Wno-timescale", *["-D" + d for d in defines],
              "-s", top, "-o", out, *sources], work)
        return (sim, work, out)
    xvlog, xelab = _which("xvlog"), _which("xelab")
    dflags = [x for d in defines for x in ("-d", d)]
    _run([xvlog, "--relax", *dflags, *sources], work)
    _run([xelab, top, "-s", name + "_snap", "-debug", "typical", "--relax"], work)
    return (sim, work, name + "_snap")


# which core the SoC is built with: name -> Verilog defines
CORES = {"inorder": [], "ooo": ["SHIELDV_OOO"]}


def run(handle, plusargs=(), timeout=3600):
    sim, work, target = handle
    if sim == "iverilog":
        cmd = [_which("vvp"), "-n", target, *["+" + p for p in plusargs]]
    else:
        cmd = [_which("xsim"), target, "-R"]
        for p in plusargs:
            cmd += ["-testplusarg", p]
    cmd_, shell = _shell(cmd)
    r = subprocess.run(cmd_, cwd=work, capture_output=True, text=True, errors="replace",
                       timeout=timeout, shell=shell)
    return r.stdout + r.stderr
