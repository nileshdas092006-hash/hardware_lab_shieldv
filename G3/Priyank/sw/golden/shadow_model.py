#!/usr/bin/env python3
"""shadow_model.py - a Python model of ShieldV's shadow stack (block S6)
Owner: Priyank (G3)

Replays a trace from make_trace.py using the same rules as the hardware
(callret_detect.v, shadow_stack.v, ret_compare.v) and reports what ShieldV
should see. Because it is written separately from the Verilog, it is an
independent "right answer" to compare the hardware against.

    python shadow_model.py trace.txt               # expect 0 violations
    python shadow_model.py trace.txt --inject 5    # corrupt the 5th return
"""
import argparse

DEPTH = 32
LINK = (1, 5)


def classify(instr):
    opcode, rd, rs1 = instr & 0x7F, (instr >> 7) & 0x1F, (instr >> 15) & 0x1F
    if opcode == 0x6F:                                   # jal
        return rd in LINK, False
    if opcode == 0x67 and ((instr >> 12) & 7) == 0:      # jalr
        call = rd in LINK
        ret = rs1 in LINK and (rd not in LINK or rd != rs1)
        return call, ret
    return False, False


def replay(trace, inject=None):
    stack, violations, calls, rets, max_depth, n_ret = [], [], 0, 0, 0, 0
    for instr, pc, target in trace:
        call, ret = classify(instr)
        if ret:
            n_ret += 1
            if inject is not None and n_ret == inject:
                target ^= 0x4                             # simulate a tampered return address
            if not stack:
                violations.append((pc, "underflow", 0, target))
            elif stack[-1] != target:
                violations.append((pc, "mismatch", stack[-1], target))
                break                                    # the hardware freezes here
            else:
                stack.pop()
            rets += 1
        if call:
            if len(stack) == DEPTH:
                violations.append((pc, "overflow", pc + 4, target))
                break
            stack.append(pc + 4)
            calls += 1
            max_depth = max(max_depth, len(stack))
    return dict(calls=calls, rets=rets, max_depth=max_depth, violations=violations)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("trace")
    ap.add_argument("--inject", type=int, default=None, help="corrupt the N-th return")
    args = ap.parse_args()
    trace = []
    with open(args.trace) as f:
        for line in f:
            if line.strip():
                trace.append(tuple(int(x, 16) for x in line.split()))
    r = replay(trace, args.inject)
    print(f"calls={r['calls']} returns={r['rets']} max_depth={r['max_depth']} "
          f"violations={len(r['violations'])}")
    for pc, kind, exp, act in r["violations"]:
        print(f"  {kind} at pc={pc:08x} expected={exp:08x} actual={act:08x}")


if __name__ == "__main__":
    main()
