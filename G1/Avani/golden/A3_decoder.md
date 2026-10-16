# A3 Decoder

## What it does (2-3 sentences, my own words)

The decoder reads one 32-bit instruction and turns it into the "control word": a set of
small on/off signals that tell every other block what to do (which ALU operation, whether
to use the immediate, whether to write a register, whether this is a load, a branch, …).
It is the only place where the CPU decides what an instruction **means**, so a mistake
here quietly turns one instruction into another. Unknown instructions are marked
`illegal` and made harmless.

## Ports

| port | width | direction | meaning |
|------|-------|-----------|---------|
| `instr` | 32 | in | the instruction |
| `rs1`, `rs2`, `rd` | 5 each | out | register numbers, copied from `[19:15]`, `[24:20]`, `[11:7]` |
| `funct3` | 3 | out | `instr[14:12]`, passed on to the branch unit, LSU and M-unit |
| `alu_op` | 4 | out | ALU operation (see `A6_alu.md`) |
| `alu_src_a_pc` | 1 | out | 1: ALU input `a` = `pc` (only `auipc`) |
| `alu_src_b_imm` | 1 | out | 1: ALU input `b` = immediate |
| `reg_write` | 1 | out | 1: write `rd` at the end |
| `wb_sel` | 2 | out | what to write: `00` ALU, `01` load data, `10` pc+4 (link), `11` M-unit |
| `is_load`, `is_store` | 1 each | out | memory access |
| `is_branch`, `is_jal`, `is_jalr` | 1 each | out | control flow, used by the branch unit |
| `is_mop` | 1 | out | RV32M multiply / divide |
| `illegal` | 1 | out | the instruction is not one we support |

## Control-word table for RV32IM

Column order is the same as the 16-bit word in `tb/decoder_tb.v`:
`{alu_op, a_pc, b_imm, reg_write, wb_sel, load, store, branch, jal, jalr, mop, illegal}`.
"–" means the signal stays at its default 0.

| instruction(s) | opcode | alu_op | a_pc | b_imm | reg_write | wb_sel | load | store | branch | jal | jalr | mop | illegal if… |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| add | `0110011` (f7=0000000) | 0000 | – | – | 1 | 00 | – | – | – | – | – | – | |
| sub | `0110011` (f7=0100000) | 1000 | – | – | 1 | 00 | – | – | – | – | – | – | |
| sll | `0110011` f3=001 | 0001 | – | – | 1 | 00 | – | – | – | – | – | – | |
| slt / sltu | `0110011` f3=010 / 011 | 0010 / 0011 | – | – | 1 | 00 | – | – | – | – | – | – | |
| xor / or / and | `0110011` f3=100 / 110 / 111 | 0100 / 0110 / 0111 | – | – | 1 | 00 | – | – | – | – | – | – | |
| srl / sra | `0110011` f3=101, f7=0000000 / 0100000 | 0101 / 1101 | – | – | 1 | 00 | – | – | – | – | – | – | |
| (R-type, bad funct7) | `0110011` | – | – | – | – | – | – | – | – | – | – | – | f7 is not 0000000, 0000001, or 0100000 with f3 = 000/101 |
| mul, mulh, mulhsu, mulhu | `0110011` f7=0000001, f3=000…011 | 0000 | – | – | 1 | 11 | – | – | – | – | – | 1 | |
| div, divu, rem, remu | `0110011` f7=0000001, f3=100…111 | 0000 | – | – | 1 | 11 | – | – | – | – | – | 1 | |
| addi | `0010011` f3=000 | 0000 | – | 1 | 1 | 00 | – | – | – | – | – | – | |
| slti / sltiu | `0010011` f3=010 / 011 | 0010 / 0011 | – | 1 | 1 | 00 | – | – | – | – | – | – | |
| xori / ori / andi | `0010011` f3=100 / 110 / 111 | 0100 / 0110 / 0111 | – | 1 | 1 | 00 | – | – | – | – | – | – | |
| slli | `0010011` f3=001 | 0001 | – | 1 | 1 | 00 | – | – | – | – | – | – | |
| srli / srai | `0010011` f3=101, bit30 = 0 / 1 | 0101 / 1101 | – | 1 | 1 | 00 | – | – | – | – | – | – | |
| lui | `0110111` | 1001 | – | 1 | 1 | 00 | – | – | – | – | – | – | |
| auipc | `0010111` | 0000 | 1 | 1 | 1 | 00 | – | – | – | – | – | – | |
| lb, lh, lw, lbu, lhu | `0000011` f3=000,001,010,100,101 | 0000 | – | 1 | 1 | 01 | 1 | – | – | – | – | – | f3 = 011, 110, 111 |
| sb, sh, sw | `0100011` f3=000…010 | 0000 | – | 1 | 0 | 00 | – | 1 | – | – | – | – | f3 > 010 |
| beq, bne, blt, bge, bltu, bgeu | `1100011` | 0000 | – | 0 | 0 | 00 | – | – | 1 | – | – | – | f3 = 010 or 011 |
| jal | `1101111` | 0000 | – | 0 | 1 | 10 | – | – | – | 1 | – | – | |
| jalr | `1100111` | 0000 | – | 0 | 1 | 10 | – | – | – | – | 1 | – | f3 ≠ 000 |
| fence, ecall, ebreak, csr* | `0001111`, `1110011` | 0000 | – | – | 0 | 00 | – | – | – | – | – | – | (never: treated as nop) |
| anything else | – | 0000 | – | – | 0 | 00 | – | – | – | – | – | – | **always** |

When `illegal = 1`, the decoder forces `reg_write`, `is_load`, `is_store`, `is_branch`,
`is_jal`, `is_jalr` and `is_mop` back to 0, so the instruction cannot change any state.

## Input -> expected output (the testbench cases)

| case | encoding | expected word `alu a b w wb ld st br jl jr m il` | why |
|------|----------|---------------------------------------------------|-----|
| `add x1,x1,x2` | `0x0020_80B3` | `0000 0 0 1 00 0 0 0 0 0 0 0` | R-type, ALU result |
| `sub x1,x1,x2` | `0x4020_80B3` | `1000 0 0 1 00 0 0 0 0 0 0 0` | bit 30 → sub |
| `sra x1,x1,x2` | `0x4020_D0B3` | `1101 0 0 1 00 0 0 0 0 0 0 0` | bit 30 + f3=101 |
| `and x1,x1,x2` | `0x0020_F0B3` | `0111 0 0 1 00 0 0 0 0 0 0 0` | |
| `addi x1,x1,-1` | `0xFFF0_8093` | `0000 0 1 1 00 0 0 0 0 0 0 0` | bit 30 is 1 here but it is part of the immediate |
| `srai x1,x1,3` | `0x4030_D093` | `1101 0 1 1 00 0 0 0 0 0 0 0` | only f3=101 copies bit 30 |
| `srli x1,x1,3` | `0x0030_D093` | `0101 0 1 1 00 0 0 0 0 0 0 0` | |
| addi with bit 30 set | `0x4030_8093` | `0000 0 1 1 00 0 0 0 0 0 0 0` | still add, **not** sub |
| `lui` | `0x1234_50B7` | `1001 0 1 1 00 0 0 0 0 0 0 0` | ALU passes `b` |
| `auipc` | `0x0000_1097` | `0000 1 1 1 00 0 0 0 0 0 0 0` | `a = pc` |
| `lw` | `0xFFC1_2083` | `0000 0 1 1 01 1 0 0 0 0 0 0` | address = rs1 + imm, write load data |
| `sw` | `0x0011_2223` | `0000 0 1 0 00 0 1 0 0 0 0 0` | no register write |
| `beq` | `0x0020_8463` | `0000 0 0 0 00 0 0 1 0 0 0 0` | branch unit compares rs1, rs2 |
| `jal x1` | `0x0080_00EF` | `0000 0 0 1 10 0 0 0 1 0 0 0` | rd = pc + 4 |
| `ret` (`jalr x0`) | `0x0000_8067` | `0000 0 0 1 10 0 0 0 0 1 0 0` | reg_write is 1 but rd = x0, so regfile ignores it |
| `mul` | `0x0220_80B3` | `0000 0 0 1 11 0 0 0 0 0 1 0` | f7 = 0000001 |
| `div` | `0x0220_C0B3` | `0000 0 0 1 11 0 0 0 0 0 1 0` | |
| `ecall` | `0x0000_0073` | `0000 0 0 0 00 0 0 0 0 0 0 0` | nop on this core |
| `fence` | `0x0FF0_000F` | `0000 0 0 0 00 0 0 0 0 0 0 0` | nop on this core |
| all ones | `0xFFFF_FFFF` | `0000 0 0 0 00 0 0 0 0 0 0 1` | unknown opcode |
| `ld` (RV64 only) | `0x0000_3083` | `0000 0 1 0 01 0 0 0 0 0 0 1` | load f3=011 is illegal; note `b_imm` and `wb_sel` are **not** cleared, but nothing writes, so they do no harm |

Register fields: `add x10, x11, x12` = `0x00C5_8533` → `rd = 10`, `rs1 = 11`, `rs2 = 12`, `funct3 = 0`.

## Expected waveform

Not needed: no clock.

## Edge cases I worry about

- **Bit 30 on I-type.** For `addi`, `andi`, … bit 30 belongs to the immediate. Only `srai`
  uses it as an operation bit. If the decoder copied it for every I-type, a negative
  `addi` would subtract.
- **jal and jalr do not use the ALU.** Their target comes from the branch unit and their
  `rd` gets `pc + 4` through `wb_sel = 10`. That is why `alu_src_b_imm = 0` for them.
- **`ret` has `reg_write = 1`.** The decoder does not check `rd = x0`; the register file
  throws the write away. Fine, but a pipeline hazard check must not think x0 is "busy".
- **Things this decoder does not catch** (things to ask about in the viva):
  `slli`/`srli`/`srai` with a wrong `funct7` (for example `0x0200_9093`) are not flagged
  illegal, and `ecall`/`ebreak`/CSR instructions are silent nops instead of traps.
- **Illegal must be harmless.** Every "do something" signal is cleared at the end, so an
  unknown instruction can never write a register or memory.
- **M-extension shares the R-type opcode.** Only `funct7 = 0000001` separates `mul` from
  `add`, so the M check happens before the normal ALU path.
