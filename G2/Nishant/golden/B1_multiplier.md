# B1 Multiplier — Golden Table (RV32M)

## What it does

The B1 multiplier implements the four RV32M multiply instructions. `MUL` returns the low 32 bits of the product; `MULH`, `MULHSU`, and `MULHU` return the high 32 bits when the operands are interpreted as signed × signed, signed × unsigned, and unsigned × unsigned respectively. All values below are 32-bit hexadecimal bit patterns unless a signed interpretation is explicitly stated.

## Operation encoding

The standalone `multiplier` block accepts `op[1:0]`, corresponding to the low two bits of the instruction's `funct3` for these four operations.

| `funct3` | `op[1:0]` | Instruction | Operand interpretation | Expected result |
|---|---|---|---|---|
| `000` | `00` | `MUL` | Either × either | Product bits `[31:0]` |
| `001` | `01` | `MULH` | Signed × signed | Product bits `[63:32]` |
| `010` | `10` | `MULHSU` | Signed × unsigned | Product bits `[63:32]` |
| `011` | `11` | `MULHU` | Unsigned × unsigned | Product bits `[63:32]` |

For `MUL`, the low 32 bits are the same whether the input bit patterns are viewed as signed or unsigned. The high-word operations differ because their operand interpretations differ.

## Ports

| Port | Width | Direction | Meaning |
|---|---:|---|---|
| `clk` | 1 | Input | Clock |
| `rst_n` | 1 | Input | Synchronous, active-low reset (`0` resets the block) |
| `start` | 1 | Input | One-cycle request to begin a multiply |
| `op` | 2 | Input | Operation code from the table above |
| `a` | 32 | Input | First operand bit pattern |
| `b` | 32 | Input | Second operand bit pattern |
| `busy` | 1 | Output | Indicates the multiply is in flight |
| `done` | 1 | Output | Pulses high when `result` is valid |
| `result` | 32 | Output | Selected low or high product word |

## Input → expected output

The expected values are calculated from the RV32M operation definitions. Each row is one input pair; the four result columns give the expected result for each operation using the same `a` and `b` bit patterns.

| Case | `a` | `b` | `MUL` (`00`) | `MULH` (`01`) | `MULHSU` (`10`) | `MULHU` (`11`) | Why this case matters |
|---|---|---|---|---|---|---|---|
| Both zero | `0x00000000` | `0x00000000` | `0x00000000` | `0x00000000` | `0x00000000` | `0x00000000` | Zero product |
| One × two | `0x00000001` | `0x00000002` | `0x00000002` | `0x00000000` | `0x00000000` | `0x00000000` | Small positive product |
| −1 × 2 | `0xFFFFFFFF` | `0x00000002` | `0xFFFFFFFE` | `0xFFFFFFFF` | `0xFFFFFFFF` | `0x00000001` | Signed and unsigned high words differ |
| `INT_MIN` × 2 | `0x80000000` | `0x00000002` | `0x00000000` | `0xFFFFFFFF` | `0xFFFFFFFF` | `0x00000001` | Signed minimum and low-word wraparound |
| `INT_MAX` × 2 | `0x7FFFFFFF` | `0x00000002` | `0xFFFFFFFE` | `0x00000000` | `0x00000000` | `0x00000000` | Largest positive signed input |
| −1 × −1 bit pattern | `0xFFFFFFFF` | `0xFFFFFFFF` | `0x00000001` | `0x00000000` | `0xFFFFFFFF` | `0xFFFFFFFE` | All four operations expose signedness differences |
| Mixed bit patterns | `0x12345678` | `0x9ABCDEF0` | `0x242D2080` | `0xF8CC93D6` | `0x0B00EA4E` | `0x0B00EA4E` | `b` is negative when interpreted as signed, but unsigned for `MULHSU`/`MULHU` |
| `INT_MIN` × −1 | `0x80000000` | `0xFFFFFFFF` | `0x80000000` | `0x00000000` | `0x80000000` | `0x7FFFFFFF` | Signed overflow boundary; low word wraps modulo 2³² |
| `INT_MAX` squared | `0x7FFFFFFF` | `0x7FFFFFFF` | `0x00000001` | `0x3FFFFFFF` | `0x3FFFFFFF` | `0x3FFFFFFF` | Large positive product with nonzero high word |
| −1 × `0x80000000` | `0xFFFFFFFF` | `0x80000000` | `0x80000000` | `0x00000000` | `0xFFFFFFFF` | `0x7FFFFFFF` | Distinguishes signed second operand from unsigned second operand |
| `0xFFFF0000` × `0x0000FFFF` | `0xFFFF0000` | `0x0000FFFF` | `0x00010000` | `0xFFFFFFFF` | `0xFFFFFFFF` | `0x0000FFFE` | Negative first operand and nontrivial high word |
| All ones × zero | `0xFFFFFFFF` | `0x00000000` | `0x00000000` | `0x00000000` | `0x00000000` | `0x00000000` | Zero result with a set sign bit in `a` |

## Expected handshake timing

After reset is released, pulse `start` for one clock edge with `op`, `a`, and `b` valid. The block captures the inputs, computes the product in the next stage, and asserts `done` when the result is valid. The intended latency is two clock cycles. Sample/compare `result` when `done` is high rather than relying on its value during an operation.

## Edge cases to check

- `0x00000000` and `0xFFFFFFFF` inputs.
- `0x80000000` (`INT_MIN`) and `0x7FFFFFFF` (`INT_MAX`).
- `0xFFFFFFFF` (−1 as signed, 4,294,967,295 as unsigned).
- `MULHSU` must treat `a` as signed and `b` as unsigned; do not sign-extend `b` for this operation.
- High-word results must use bits `[63:32]` of the 64-bit product defined by the selected signedness rules.
- `MUL` must return only bits `[31:0]`, dropping any carry/high word.

## Reference formulas

Let `u32(x)` be the unsigned value of a 32-bit bit pattern and `s32(x)` its two's-complement signed value. Then:

- `MUL(a,b)`: low 32 bits of `u32(a) × u32(b)`.
- `MULH(a,b)`: high 32 bits of `s32(a) × s32(b)` represented as a 64-bit two's-complement product.
- `MULHSU(a,b)`: high 32 bits of `s32(a) × u32(b)` represented modulo 2⁶⁴.
- `MULHU(a,b)`: high 32 bits of `u32(a) × u32(b)`.

The formulas above define expected outputs independently of the implementation details used to build the hardware.
