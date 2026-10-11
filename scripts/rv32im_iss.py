#!/usr/bin/env python3
"""rv32im_iss.py - golden model: a tiny RV32IM instruction-set simulator (Laxmidhar, G1).

    python scripts/rv32im_iss.py build/sw_spike/fib/imem.hex build/sw_spike/fib/dmem.hex out.log

Runs a program image exactly as the ShieldV memory map describes it
(docs/interfaces.md) and writes a commit log in the same format as soc_tb.v
(and Spike):  core   0: 3 0x<pc> (0x<instr>) x<rd> 0x<value> [mem 0x<addr>]

It knows nothing about pipelines, so it is the reference that both cores'
commit logs are compared against (scripts/random_diff.py). Every instruction
is written straight from the RISC-V specification, one line each, so it can
be checked by reading.

Memory: instruction RAM 0x0000_0000 (16 KB, not on the data bus: loads from
it return 0, like bus_decoder.v), data RAM 0x0001_0000 (16 KB), I/O page
0x1000_0000: writes ignored except SIM_EXIT (0x1000_00FC), which stops the
run; I/O loads return 0, except SWITCH (0x1000_0008), which returns 1 (SW0 up).
"""
import sys

MASK = 0xFFFFFFFF


def sx(v, bits):
    """sign-extend the low `bits` bits of v"""
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def s32(v):
    return sx(v, 32)


def div_trunc(n, d):
    """signed division rounding toward zero, as RISC-V (and C) define it"""
    q = abs(n) // abs(d)
    return -q if (n < 0) != (d < 0) else q


def load_hex(path, words=4096):
    mem = [0] * words
    with open(path) as f:
        for i, line in enumerate(l for l in f if l.strip()):
            mem[i] = int(line, 16)
    return mem


class ISS:
    def __init__(self, imem, dmem, switches=1):
        self.imem = imem
        self.dmem = dmem
        self.switches = switches          # what the program reads at 0x1000_0008 (SW0 = 1: protection on)
        self.x = [0] * 32
        self.pc = 0
        self.exit_code = None

    # ---- data bus ----
    def read(self, addr):
        if 0x0001_0000 <= addr < 0x0001_4000:
            return self.dmem[(addr >> 2) & 0xFFF]
        if addr == 0x1000_0008:
            return self.switches
        return 0

    def write(self, addr, value, strb):
        if 0x0001_0000 <= addr < 0x0001_4000:
            i = (addr >> 2) & 0xFFF
            w = self.dmem[i]
            for b in range(4):
                if strb >> b & 1:
                    w = (w & ~(0xFF << 8 * b)) | (value & (0xFF << 8 * b))
            self.dmem[i] = w & MASK
        elif addr == 0x1000_00FC:
            self.exit_code = value

    # ---- one instruction; returns the log line ----
    def step(self):
        pc = self.pc
        ins = self.imem[(pc >> 2) & 0xFFF]
        op, rd, f3 = ins & 0x7F, (ins >> 7) & 31, (ins >> 12) & 7
        rs1, rs2, f7 = (ins >> 15) & 31, (ins >> 20) & 31, ins >> 25
        a, b = self.x[rs1], self.x[rs2]
        imm_i = sx(ins >> 20, 12)
        imm_s = sx(((ins >> 25) << 5) | ((ins >> 7) & 31), 12)
        imm_b = sx(((ins >> 31) << 12) | (((ins >> 7) & 1) << 11) | (((ins >> 25) & 63) << 5) | (((ins >> 8) & 15) << 1), 13)
        imm_u = ins & 0xFFFFF000
        imm_j = sx(((ins >> 31) << 20) | (((ins >> 12) & 255) << 12) | (((ins >> 20) & 1) << 11) | (((ins >> 21) & 1023) << 1), 21)
        npc = (pc + 4) & MASK
        wr = None                    # value written to rd
        mem = None                   # load address, for the log

        if op == 0x37:   wr = imm_u                                         # lui
        elif op == 0x17: wr = (pc + imm_u) & MASK                           # auipc
        elif op == 0x6F: wr, npc = (pc + 4) & MASK, (pc + imm_j) & MASK     # jal
        elif op == 0x67 and f3 == 0:                                        # jalr
            wr, npc = (pc + 4) & MASK, (a + imm_i) & MASK & ~1
        elif op == 0x63:                                                    # branches
            take = {0: a == b, 1: a != b, 4: s32(a) < s32(b), 5: s32(a) >= s32(b),
                    6: a < b, 7: a >= b}.get(f3, False)
            if take:
                npc = (pc + imm_b) & MASK
        elif op == 0x03:                                                    # loads
            addr = (a + imm_i) & MASK
            w = self.read(addr & ~3) >> (8 * (addr & 3))
            wr = {0: sx(w, 8) & MASK, 1: sx(w, 16) & MASK, 2: w & MASK, 4: w & 0xFF, 5: w & 0xFFFF}.get(f3)
            mem = addr
        elif op == 0x23:                                                    # stores
            addr = (a + imm_s) & MASK
            off = addr & 3
            if f3 == 0:   self.write(addr & ~3, (b & 0xFF) * 0x01010101, 1 << off)
            elif f3 == 1: self.write(addr & ~3, (b & 0xFFFF) * 0x00010001, 3 << (off & 2))
            elif f3 == 2: self.write(addr & ~3, b, 0xF)
        elif op == 0x13:                                                    # ALU immediate
            sh = imm_i & 31
            wr = {0: a + imm_i, 2: int(s32(a) < imm_i), 3: int(a < (imm_i & MASK)),
                  4: a ^ imm_i, 6: a | imm_i, 7: a & imm_i, 1: a << sh,
                  5: (s32(a) >> sh) if (ins >> 30) & 1 else (a >> sh)}[f3] & MASK
        elif op == 0x33 and f7 == 1:                                        # RV32M
            if f3 == 0:   wr = (a * b) & MASK
            elif f3 == 1: wr = ((s32(a) * s32(b)) >> 32) & MASK
            elif f3 == 2: wr = ((s32(a) * b) >> 32) & MASK
            elif f3 == 3: wr = ((a * b) >> 32) & MASK
            elif f3 == 4:                                                   # div
                if b == 0: wr = MASK
                elif a == 0x80000000 and b == MASK: wr = a
                else: wr = div_trunc(s32(a), s32(b)) & MASK
            elif f3 == 5: wr = MASK if b == 0 else a // b                   # divu
            elif f3 == 6:                                                   # rem
                if b == 0: wr = a
                elif a == 0x80000000 and b == MASK: wr = 0
                else: wr = (s32(a) - s32(b) * div_trunc(s32(a), s32(b))) & MASK
            else:         wr = a if b == 0 else a % b                       # remu
        elif op == 0x33:                                                    # ALU register
            sh = b & 31
            alt = (ins >> 30) & 1
            wr = {0: (a - b) if alt else (a + b), 1: a << sh, 2: int(s32(a) < s32(b)), 3: int(a < b),
                  4: a ^ b, 5: (s32(a) >> sh) if alt else (a >> sh), 6: a | b, 7: a & b}[f3] & MASK
        # fence, ecall, ebreak, csr: no-ops on this bare-metal system

        line = f"core   0: 3 0x{pc:08x} (0x{ins:08x})"
        if wr is not None and rd != 0:
            self.x[rd] = wr & MASK
            line += f" x{rd} 0x{wr & MASK:08x}"
            if mem is not None:
                line += f" mem 0x{mem:08x}"
        self.pc = npc
        return line

    def run(self, max_steps=2_000_000):
        lines = []
        for _ in range(max_steps):
            lines.append(self.step())
            if self.exit_code is not None:
                break
        return lines


def run_files(imem_hex, dmem_hex, log_path, max_steps=2_000_000):
    iss = ISS(load_hex(imem_hex), load_hex(dmem_hex))
    lines = iss.run(max_steps)
    with open(log_path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return iss.exit_code, len(lines)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    code, n = run_files(*sys.argv[1:4])
    print(f"exit code {code} after {n} instructions")
