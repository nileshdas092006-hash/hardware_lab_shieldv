#!/usr/bin/env python3
"""build_sw.py - compile one C program into memory images for the CPU (block S2).

    python scripts/build_sw.py fib          ->  build/sw/fib/{fib.elf, fib.dis, imem.hex, dmem.hex}

Steps (what `make sw PROG=fib` runs):
  1. riscv-none-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib: compile crt0.S,
     the runtime and the program, link with link.ld
  2. objcopy: cut the .text section (code) and the .data section (constants
     and globals) into raw binary files
  3. turn each binary into a hex file with one 32-bit word per line, the
     format Verilog's $readmemh loads into imem.v / dmem.v
  4. objdump: a readable listing (.dis) to look up addresses, e.g. where
     hacked() is or where victim() saves ra
"""
import argparse
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SW = os.path.join(ROOT, "G3", "Priyank", "sw")

# program name -> source files (relative to sw/)
PROGRAMS = {
    "hello":       ["workloads/hello.c"],
    "fib":         ["workloads/fib.c"],
    "fact":        ["workloads/fact.c"],
    "qsort":       ["workloads/qsort.c"],
    "bintree":     ["workloads/bintree.c"],
    "matmul":      ["workloads/matmul.c"],
    "primes":      ["workloads/primes.c"],
    "fnptr":       ["workloads/fnptr.c", "workloads/fnptr_targets.S"],
    "timing1":     ["workloads/timing1.c"],
    "deep":        ["workloads/deep.c"],      # 32 return addresses: shadow stack exactly full
    "deep_over":   ["workloads/deep.c"],      # 33: one more than the shadow stack holds
    "timing_final": ["workloads/timing_final.S"],     # the final timing diagram (scripts/diagrams.py)
    "attack":      ["attack/attack.c"],
    "attack_trap": ["attack/attack_trap.c"],
    "lock":        ["attack/lock.c"],
    "lock_off":    ["attack/lock.c"],             # same source, built with -DNO_LOCK
    "attack_canary":      ["attack/attack.c"],    # stack canaries instead of / with ShieldV
    "attack_skip":        ["attack/attack_skip.c"],
    "attack_skip_canary": ["attack/attack_skip.c"],
    # Laxmidhar's directed pipeline test (assembly, lives with his testbenches)
    "hazards":     ["../../../G1/Laxmidhar/tb/asm/hazards.S"],
}

# extra compiler flags for programs that share a source file
CANARY = ["-fstack-protector-all"]
PROG_CFLAGS = {"lock_off": ["-DNO_LOCK"], "deep_over": ["-DNEST=32"], "attack_canary": CANARY, "attack_skip_canary": CANARY}

CFLAGS = ["-march=rv32im", "-mabi=ilp32", "-O1", "-g", "-Wall",
          "-ffreestanding", "-nostdlib", "-nostartfiles",
          "-fno-builtin", "-fno-inline-functions", "-mno-relax",
          "-fno-jump-tables", "-fno-tree-loop-distribute-patterns"]


def find_tool(name):
    path = shutil.which(name)
    if path:
        return path
    # Linux distributions ship the same compiler as riscv64-unknown-elf-*
    alt = shutil.which(name.replace("riscv-none-elf-", "riscv64-unknown-elf-"))
    if alt:
        return alt
    # default xPack install location on Windows (installed with xpm)
    base = os.path.expandvars(r"%APPDATA%\xPacks\@xpack-dev-tools\riscv-none-elf-gcc")
    if os.path.isdir(base):
        for ver in sorted(os.listdir(base), reverse=True):
            cand = os.path.join(base, ver, ".content", "bin", name + ".exe")
            if os.path.isfile(cand):
                return cand
    sys.exit(f"cannot find {name}; install the xPack riscv-none-elf-gcc toolchain")


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        sys.stderr.write(" ".join(cmd) + "\n" + r.stdout + r.stderr)
        sys.exit(r.returncode)
    return r.stdout


def bin_to_hex(bin_path, hex_path, words=4096):
    data = open(bin_path, "rb").read() if os.path.exists(bin_path) else b""
    if len(data) > words * 4:
        sys.exit(f"{bin_path}: {len(data)} bytes does not fit in {words * 4} bytes")
    data += b"\x00" * (-len(data) % 4)
    with open(hex_path, "w", newline="\n") as f:
        for i in range(0, len(data), 4):
            f.write("%08x\n" % int.from_bytes(data[i:i + 4], "little"))


def symbols(nm_out):
    syms = {}
    for line in nm_out.splitlines():
        parts = line.split()
        if len(parts) == 3:
            syms[parts[2]] = int(parts[0], 16)
    return syms


def build(prog, out_root, extra_cflags=()):
    if prog not in PROGRAMS:
        sys.exit(f"unknown program {prog}; choose from: {', '.join(PROGRAMS)}")
    gcc = find_tool("riscv-none-elf-gcc")
    objcopy = find_tool("riscv-none-elf-objcopy")
    objdump = find_tool("riscv-none-elf-objdump")
    nm = find_tool("riscv-none-elf-nm")

    out = os.path.join(out_root, prog)
    os.makedirs(out, exist_ok=True)
    elf = os.path.join(out, prog + ".elf")

    srcs = [os.path.join(SW, "crt0.S"), os.path.join(SW, "lib", "rt.c")]
    srcs += [os.path.join(SW, s) for s in PROGRAMS[prog]]
    run([gcc, *CFLAGS, *PROG_CFLAGS.get(prog, []), *extra_cflags, "-T", os.path.join(SW, "link.ld"),
         "-o", elf, *srcs])

    text_bin = os.path.join(out, "text.bin")
    data_bin = os.path.join(out, "data.bin")
    run([objcopy, "-O", "binary", "-j", ".text", elf, text_bin])
    run([objcopy, "-O", "binary", "-j", ".data", elf, data_bin])
    bin_to_hex(text_bin, os.path.join(out, "imem.hex"))
    bin_to_hex(data_bin, os.path.join(out, "dmem.hex"))

    with open(os.path.join(out, prog + ".dis"), "w", newline="\n") as f:
        f.write(run([objdump, "-d", "-S", "--no-show-raw-insn", elf]))

    syms = symbols(run([nm, elf]))
    with open(os.path.join(out, "symbols.txt"), "w", newline="\n") as f:
        for name, addr in sorted(syms.items(), key=lambda kv: kv[1]):
            f.write("%08x %s\n" % (addr, name))
    return out, syms


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("prog", nargs="*", help="program(s) to build (default: all)")
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "sw"))
    ap.add_argument("--spike", action="store_true",
                    help="build for comparison with Spike (no counters, no UART polling)")
    args = ap.parse_args()
    out_root = args.out + ("_spike" if args.spike else "")
    for p in args.prog or PROGRAMS:
        out, syms = build(p, out_root, ["-DSPIKE_COMPARE"] if args.spike else [])
        size = os.path.getsize(os.path.join(out, "text.bin"))
        print(f"{p:12s} -> {os.path.relpath(out, ROOT)}  ({size} bytes of code)")


if __name__ == "__main__":
    main()
