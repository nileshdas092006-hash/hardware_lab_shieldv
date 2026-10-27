# B1 Worked Example — `MULHSU` by Hand

**Instruction:** `MULHSU rd, rs1, rs2` (RV32M, `funct3 = 010`)

`MULHSU` interprets `rs1` as a signed 32-bit two's-complement value and `rs2` as an unsigned 32-bit value. It returns bits `[63:32]` of their 64-bit product.

## Example operands

| Item | Value | Interpretation |
|---|---:|---|
| `a` / `rs1` | `0xFFFFFFFD` | signed `-3` |
| `b` / `rs2` | `0x80000001` | unsigned `2,147,483,649` |
| Operation | `MULHSU` | signed × unsigned |

## Step 1 — extend each operand correctly

The 33-bit signed multiplier input for `a` copies the sign bit into bit 32. For `b`, bit 32 must be zero because the operand is unsigned.

```text
a = 0xFFFFFFFD, signed value -3
sign-extended a = 33'h1FFFFFFFD   (signed 33-bit value -3)

b = 0x80000001, unsigned value 2,147,483,649
zero-extended b = 33'h080000001  (positive signed 33-bit value)
```

This is the key distinction from `MULH`: for `MULHSU`, **do not sign-extend `b`** even though `b[31] = 1`.

## Step 2 — multiply the mathematical values

```text
product = (-3) × 2,147,483,649
        = -(3 × 2,147,483,649)
        = -6,442,450,947
```

The positive magnitude is:

```text
3 × 0x80000001 = 0x180000003
```

Taking the two's-complement representation modulo \(2^{64}\):

```text
0x0000000000000000 - 0x0000000180000003
  = 0xFFFFFFFE7FFFFFFD
```

## Step 3 — select the high word

```text
64-bit product = 0xFFFFFFFE_7FFFFFFD
                         ^^^^^^^^ ^^^^^^^^
                         [63:32] [31:0]

MULHSU result = product[63:32] = 0xFFFFFFFE
```

**Expected answer: `0xFFFFFFFE`.**

## Sanity check: why signedness matters

If both operands were incorrectly treated as signed (`MULH`), `b` would be interpreted as `-2,147,483,647`. The product would then be positive:

```text
(-3) × (-2,147,483,647) = 6,442,450,941
64-bit product           = 0x000000017FFFFFFD
MULH high word           = 0x00000001
```

So this test distinguishes the instructions: `MULHSU` must return `0xFFFFFFFE`, whereas `MULH` would return `0x00000001` for the same operand bit patterns.

## Connection to the RTL

In `G2/Nishant/rtl/multiplier.v`, `op = 2'b10` makes `a_signed = 1` and `b_signed = 0`. The RTL therefore forms `{a[31], a}` for `a_r` and `{1'b0, b}` for `b_r`; the selected result is `prod[63:32]`.
