# A4 Immediate generator

## What it does (2-3 sentences, my own words)

Many instructions carry a small constant (the "immediate") inside their 32 bits, but the
bits of that constant are scattered in a different pattern for each instruction format.
This block looks at the opcode, collects the scattered bits back into the right order and
sign-extends them to 32 bits. It has no clock, it only rewires bits.

## Ports

| port | width | direction | meaning |
|------|-------|-----------|---------|
| `instr` | 32 | in | the whole instruction |
| `imm`   | 32 | out | the rebuilt, sign-extended immediate (0 for R-type and unknown opcodes) |

## The five formats

Two rules RISC-V keeps everywhere: the **sign bit is always `instr[31]`**, and the register
fields (`rd` `[11:7]`, `rs1` `[19:15]`, `rs2` `[24:20]`) never move. The scrambling is the
price of those two rules.

| format | opcode(s) | used by | immediate bits, high to low | range |
|--------|-----------|---------|------------------------------|-------|
| I | `0010011`, `0000011`, `1100111` | addi…, loads, jalr | `inst[31:20]` | -2048 … 2047 |
| S | `0100011` | stores | `inst[31:25]`, `inst[11:7]` | -2048 … 2047 |
| B | `1100011` | branches | `inst[31]`, `inst[7]`, `inst[30:25]`, `inst[11:8]`, `0` | -4096 … 4094, always even |
| U | `0110111`, `0010111` | lui, auipc | `inst[31:12]`, twelve `0`s | upper 20 bits |
| J | `1101111` | jal | `inst[31]`, `inst[19:12]`, `inst[20]`, `inst[30:21]`, `0` | ±1 MiB, always even |

Pictures of where each immediate bit lives (`i[n]` = bit n of the immediate):

```
bit:     31 30..25 24..21 20 19..15 14..12 11..8  7   6..0
I:     [ i[11:0]               ][ rs1 ][ f3 ][   rd    ][ op ]
S:     [ i[11:5]  ][  rs2      ][ rs1 ][ f3 ][ i[4:0]  ][ op ]
B:     [i12][i10:5][  rs2      ][ rs1 ][ f3 ][i4:1][i11][ op ]
U:     [ i[31:12]                            ][   rd    ][ op ]
J:     [i20][ i[10:1]    ][i11][ i[19:12]    ][   rd    ][ op ]
```

## Input -> expected output

Each encoding is what the assembler produced (same list as `tb/imm_gen_tb.v`).

| case | instruction | encoding | format | expected imm | why |
|------|-------------|----------|--------|--------------|-----|
| small positive | `addi x1, x0, 1` | `0x0010_0093` | I | `0x0000_0001` | `inst[31:20] = 0x001` |
| -1 | `addi x1, x0, -1` | `0xFFF0_0093` | I | `0xFFFF_FFFF` | `0xFFF` sign-extended |
| most negative I | `addi x1, x0, -2048` | `0x8000_0093` | I | `0xFFFF_F800` | `0x800` = -2048 |
| most positive I | `addi x1, x0, 2047` | `0x7FF0_0093` | I | `0x0000_07FF` | sign bit 0, no extension |
| load offset | `lw x1, -4(x2)` | `0xFFC1_2083` | I | `0xFFFF_FFFC` | loads use I-format |
| store +4 | `sw x1, 4(x2)` | `0x0011_2223` | S | `0x0000_0004` | low 5 bits come from `inst[11:7]` = `00100` |
| store -4 | `sw x1, -4(x2)` | `0xFE11_2E23` | S | `0xFFFF_FFFC` | `inst[31:25]=1111111`, `inst[11:7]=11100` |
| branch +8 | `beq x1, x2, +8` | `0x0020_8463` | B | `0x0000_0008` | `inst[11:8] = 0100` → bits 4:1 → 8 |
| branch -4 | `beq x1, x2, -4` | `0xFE20_8EE3` | B | `0xFFFF_FFFC` | worked out below |
| branch most negative | `beq x0, x0, -4096` | `0x8000_0063` | B | `0xFFFF_F000` | only the sign bit set |
| lui | `lui x1, 0x12345` | `0x1234_50B7` | U | `0x1234_5000` | top 20 bits, bottom 12 are zero |
| auipc | `auipc x1, 0xfffff` | `0xFFFF_F097` | U | `0xFFFF_F000` | U is **not** sign-extended, it already fills bit 31 |
| jal +8 | `jal x1, +8` | `0x0080_00EF` | J | `0x0000_0008` | `inst[30:21]` = `0000000100` → bits 10:1 |
| jal -4 | `jal x1, -4` | `0xFFDF_F0EF` | J | `0xFFFF_FFFC` | worked out below |
| jal most negative | `jal x0, -1 MiB` | `0x8000_006F` | J | `0xFFF0_0000` | only the sign bit set: -2^20 |
| jalr | `jalr x1, 4(x1)` | `0x0040_80E7` | I | `0x0000_0004` | jalr is I-format, **not** J |
| ret | `ret` = `jalr x0, 0(x1)` | `0x0000_8067` | I | `0x0000_0000` | offset 0 |
| R-type | `add x1, x1, x2` | `0x0020_80B3` | – | `0x0000_0000` | no immediate; `default` gives 0 |

### Worked by hand: `beq x1, x2, -4` = `0xFE20_8EE3`

```
binary:  1 111111 00010 00001 000 1110 1 1100011
         |   |                     |   |
       i[12] i[10:5]=111111   i[4:1]=1110  i[11]=1
imm = i12 i11 i10..5 i4..1 0 = 1 1 111111 1110 0  (13 bits) = -4
```

### Worked by hand: `jal x1, -4` = `0xFFDF_F0EF`

```
binary:  1 1111111110 1 11111111 00001 1101111
         |     |      |    |
       i[20] i[10:1] i[11] i[19:12]
imm = 1 11111111 1 1111111110 0  (21 bits) = -4
```

## Expected waveform

Not needed: no clock.

## Edge cases I worry about

- **B and J have a hidden 0 at the bottom.** Branch and jump targets are always even, so
  bit 0 is not stored. If I forget the `1'b0`, every branch goes to half the distance.
- **Bit 11 moves.** In B it sits in `inst[7]`, in J it sits in `inst[20]`. Mixing these up
  only breaks offsets ≥ 2048, which small test programs might never hit; that is why the
  testbench has the `-4096` and `-1 MiB` cases.
- **U is not sign-extended**, it is shifted. `lui x1, 0xfffff` gives `0xFFFF_F000`
  because bit 31 is already part of the immediate.
- **jalr is I-format**, even though it is a jump. Using J for opcode `1100111` would give
  a nonsense offset for every `ret`.
- **Sign-extension width.** I and S fill 20 copies of `inst[31]`, B fills 19 (plus the 13
  real bits), J fills 11 (plus the 21 real bits). Count to 32 every time.
