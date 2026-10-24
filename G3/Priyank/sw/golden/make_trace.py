#!/usr/bin/env python3
"""make_trace.py - turn a commit log into a call/return trace for ShieldV (block S6)
Owner: Priyank (G3)

A commit log lists every instruction the CPU finished, in order:
    core   0: 3 0x00000044 (0x0d0000ef) x1 0x00000048
For every jal/jalr we know where it went: the PC of the NEXT committed
instruction. The trace keeps just those control-flow instructions:
    <instr> <pc> <target>
shieldv_replay_tb.v feeds this trace to ShieldV (without any CPU) and
shadow_model.py replays it in Python. Both must agree: zero violations for
an honest program.

Commit logs come from our own simulation (run_prog.py --log) or from Spike
(spike --log-commits); the format is the same.
"""
import re
import sys

LINE = re.compile(r"core\s+\d+:\s+\d+\s+0x([0-9a-fA-F]+)\s+\(0x([0-9a-fA-F]+)\)")


def read_commits(path):
    out = []
    with open(path) as f:
        for line in f:
            m = LINE.search(line)
            if m:
                out.append((int(m.group(1), 16), int(m.group(2), 16)))
    return out


def is_jump(instr):
    return (instr & 0x7F) in (0x6F, 0x67)          # jal, jalr


def make_trace(commits):
    trace = []
    for (pc, instr), nxt in zip(commits, commits[1:]):
        if is_jump(instr):
            trace.append((instr, pc, nxt[0]))
    return trace


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: make_trace.py <commit.log> <trace.txt>")
    trace = make_trace(read_commits(sys.argv[1]))
    with open(sys.argv[2], "w", newline="\n") as f:
        for instr, pc, target in trace:
            f.write("%08x %08x %08x\n" % (instr, pc, target))
    print(f"{len(trace)} control-flow instructions -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
