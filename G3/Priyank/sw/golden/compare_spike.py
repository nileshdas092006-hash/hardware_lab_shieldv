#!/usr/bin/env python3
"""compare_spike.py - find the first instruction where two commit logs disagree (block S6)
Owner: Priyank (G3)

    python compare_spike.py spike.log rtl.log

Each log line looks like Spike's --log-commits output:
    core   0: 3 0x00000044 (0x0d0000ef) x1 0x00000048
(PC, instruction bits, and the register written with its new value).
Our soc_tb.v writes the same format with  run_prog.py <prog> --log.

How to make the Spike log for one of our programs (code at 0x0, data RAM at
0x10000, I/O page at 0x10000000 treated as plain memory):
    spike --isa=rv32im -m0x0:0x20000,0x10000000:0x1000 --pc=0x0 \\
          --log-commits -l build/sw/fib/fib.elf 2> spike.log
Build the program with  build_sw.py <prog> --spike  first: that version
never reads the cycle counters and never polls the UART, so both logs run
the same instructions. Any remaining load from the I/O page (0x1000_xxxx,
e.g. the switches) is skipped instead of failing.
"""
import re
import sys

LINE = re.compile(r"core\s+\d+:\s+\d+\s+0x([0-9a-f]+)\s+\(0x([0-9a-f]+)\)"
                  r"(?:\s+x\s*(\d+)\s+0x([0-9a-f]+))?(?:.*?mem\s+0x([0-9a-f]+))?", re.IGNORECASE)


def parse(path):
    out = []
    with open(path) as f:
        for line in f:
            m = LINE.search(line)
            if m:
                pc, instr = int(m.group(1), 16), int(m.group(2), 16)
                rd = int(m.group(3)) if m.group(3) else None
                val = int(m.group(4), 16) if m.group(4) else None
                mem = int(m.group(5), 16) if m.group(5) else None
                if rd == 0:
                    rd = val = None
                out.append((pc, instr, rd, val, mem))
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    a, b = parse(sys.argv[1]), parse(sys.argv[2])
    io_regs = set()
    n = min(len(a), len(b))
    for i in range(n):
        pa, ia, ra, va, ma = a[i]
        pb, ib, rb, vb, mb = b[i]
        if (pa, ia) != (pb, ib):
            print(f"DIVERGE at instruction {i}: {sys.argv[1]} pc={pa:08x} ({ia:08x})  "
                  f"{sys.argv[2]} pc={pb:08x} ({ib:08x})")
            sys.exit(1)
        if ra != rb or va != vb:
            # a load from the I/O page (switches, counters) may differ legitimately
            addr = ma if ma is not None else mb
            if (ia & 0x7F) == 0x03 and addr is not None and (addr >> 12) == 0x10000:
                io_regs.add(ra)
                continue
            print(f"DIVERGE at instruction {i}, pc={pa:08x} ({ia:08x}): "
                  f"x{ra}={va if va is None else hex(va)} vs x{rb}={vb if vb is None else hex(vb)}")
            sys.exit(1)
    print(f"MATCH: {n} instructions identical"
          + (f" (I/O loads skipped)" if io_regs else "")
          + ("" if len(a) == len(b) else f"; lengths differ ({len(a)} vs {len(b)})"))


if __name__ == "__main__":
    main()
