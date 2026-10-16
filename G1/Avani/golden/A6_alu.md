# A6 ALU

## What it does (2-3 sentences, my own words)

The ALU is the "calculator" of the CPU: it takes two 32-bit numbers `a` and `b` and a
4-bit code `op`, and gives back one 32-bit answer `y`. It has no clock and no memory, so
the answer changes the moment an input changes. Almost every instruction passes through
it: arithmetic, logic, shifts and compares, and also address calculation for loads and
stores (`rs1 + imm`), `auipc` (`pc + imm`) and `lui` (just pass `imm` through).

## Ports

| port | width | direction | meaning |
|------|-------|-----------|---------|
| `a`  | 32 | in  | first operand: `rs1` value, or `pc` for `auipc` |
| `b`  | 32 | in  | second operand: `rs2` value, or the immediate |
| `op` | 4  | in  | which operation, = `{funct7[5], funct3}` for R-type |
| `y`  | 32 | out | the result |

## op codes

The trick: `op` is just `{instr[30], funct3}`, so the decoder copies bits from the
instruction instead of having a big lookup table. Bit 30 is the only thing that tells
`add` from `sub` and `srl` from `sra`.

| op | operation | instructions |
|----|-----------|--------------|
| `0000` | `a + b` | add, addi, load/store address, auipc |
| `1000` | `a - b` | sub |
| `0001` | `a << b[4:0]` | sll, slli |
| `0010` | `1` if `a < b` as **signed**, else `0` | slt, slti |
| `0011` | `1` if `a < b` as **unsigned**, else `0` | sltu, sltiu |
| `0100` | `a ^ b` | xor, xori |
| `0101` | `a >> b[4:0]`, fill with 0 | srl, srli |
| `1101` | `a >> b[4:0]`, fill with the sign bit | sra, srai |
| `0110` | `a \| b` | or, ori |
| `0111` | `a & b` | and, andi |
| `1001` | `b` | lui |
| anything else | `0` | (not used; safe default) |

## Input -> expected output

| case | a | b | op | expected y | why |
|------|---|---|----|------------|-----|
| add | `5` | `3` | 0000 | `8` | plain addition |
| add wraps | `0xFFFF_FFFF` | `1` | 0000 | `0` | -1 + 1 = 0, the carry out of bit 31 is thrown away |
| signed overflow | `0x7FFF_FFFF` | `1` | 0000 | `0x8000_0000` | biggest positive + 1 becomes the most negative; RISC-V does **not** trap on overflow |
| sub | `3` | `5` | 1000 | `0xFFFF_FFFE` | 3 - 5 = -2 in two's complement |
| sub wraps | `0x8000_0000` | `1` | 1000 | `0x7FFF_FFFF` | most negative - 1 wraps to most positive |
| sub to zero | `0` | `0` | 1000 | `0` | sanity check |
| sll by 31 | `1` | `31` | 0001 | `0x8000_0000` | largest legal shift |
| sll by 32 | `1` | `32` | 0001 | `1` | only `b[4:0]` is used; 32 = `0b10_0000`, so the shift is 0 |
| sll by 4 | `0x1234_5678` | `4` | 0001 | `0x2345_6780` | one hex digit falls off the left |
| slt signed | `0xFFFF_FFFF` | `1` | 0010 | `1` | -1 < 1 |
| slt signed, reversed | `1` | `0xFFFF_FFFF` | 0010 | `0` | 1 is not < -1 |
| slt equal | `5` | `5` | 0010 | `0` | "less than", not "less or equal" |
| slt extremes | `0x8000_0000` | `0x7FFF_FFFF` | 0010 | `1` | most negative < most positive |
| sltu unsigned | `0xFFFF_FFFF` | `1` | 0011 | `0` | 4 294 967 295 is not < 1 |
| sltu 0 < 1 | `0` | `1` | 0011 | `1` | this is how `snez`/`seqz`-style tricks work |
| sltu extremes | `0x8000_0000` | `0x7FFF_FFFF` | 0011 | `0` | same bits as slt above, **opposite** answer |
| xor | `0xAAAA_AAAA` | `0xFFFF_FFFF` | 0100 | `0x5555_5555` | xor with all ones = invert (`not` is `xori rd, rs, -1`) |
| srl by 31 | `0x8000_0000` | `31` | 0101 | `1` | logical shift fills with 0 |
| srl by 4 | `0x8000_0000` | `4` | 0101 | `0x0800_0000` | zeros come in from the left |
| sra by 31 | `0x8000_0000` | `31` | 1101 | `0xFFFF_FFFF` | arithmetic shift copies the sign bit in |
| sra by 4 | `0x8000_0000` | `4` | 1101 | `0xF800_0000` | four copies of the sign bit (1) come in |
| sra positive | `0x7FFF_FFF0` | `4` | 1101 | `0x07FF_FFFF` | sign bit is 0, so sra behaves like srl |
| or | `0xF0F0_0000` | `0x0FF0_1234` | 0110 | `0xFFF0_1234` | bit-by-bit or |
| and | `0xF0F0_0000` | `0x0FF0_1234` | 0111 | `0x00F0_0000` | bit-by-bit and |
| lui pass | `0x1234_5678` | `0xABCD_E000` | 1001 | `0xABCD_E000` | `a` is ignored, `b` (the U-immediate) goes straight out |
| unused op | `0x1234_5678` | `0xABCD_E000` | 1010 | `0` | default branch of the `case`, so no latch |

## Expected waveform

Not needed: the ALU has no clock.

## Edge cases I worry about

- **Signed vs unsigned.** The same 32 bits mean -1 or 4 294 967 295. Only `slt` and `sra`
  must use `$signed(...)`; if I forget it on `sra` it silently becomes `srl`.
- **`>>>` needs a signed operand.** In Verilog, `a >>> n` on an *unsigned* `a` fills with
  zeros. That is why the RTL writes `$signed(a) >>> b[4:0]`.
- **Shift amount is 5 bits.** A shift by 32 or more must not give 0; it uses `b[4:0]`.
- **No latch.** `y = 0` is set before the `case`, so every path assigns `y`.
- **Overflow is not an error** in RISC-V. `0x7FFF_FFFF + 1` just wraps.
- **`sub` vs `addi` with bit 30 set.** For I-type `addi`, bit 30 is part of the immediate,
  not a "sub" flag. The decoder (A3) must only copy bit 30 into `op` for `srai`, otherwise
  `addi x1, x1, -1024` would turn into a subtract.
