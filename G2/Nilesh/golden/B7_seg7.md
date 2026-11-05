# B7 7-segment display driver

## What it does

The Nexys A7 has 8 digits, but they all share the same 7 segment wires (CA..CG). The driver
switches on one digit at a time through its anode (AN0..AN7) and cycles through all 8 at
about 760 Hz per digit, fast enough that the eye sees a steady 8-digit hex number. On this
board **both segments and anodes are active low**: 0 means on.

```
     a
    ---
 f | g | b        seg[6:0] = {g, f, e, d, c, b, a}
    ---
 e |   | c
    ---
     d
```

## Ports

| port | width | dir | meaning |
|------|-------|-----|---------|
| `value` | 32 | in | 8 hex digits; digit 7 (the left one) = `value[31:28]` |
| `seg` | 7 | out | `{g,f,e,d,c,b,a}`, active low |
| `an` | 8 | out | which digit is on, active low |
| `dp` | 1 | out | decimal point, always 1 (off) |

## Digit -> segments

| hex | segments lit | lit bits `gfedcba` | **`seg` on the pins (active low)** |
|-----|--------------|--------------------|-------------------------------------|
| 0 | a b c d e f | `0111111` | `1000000` = `0x40` |
| 1 | b c | `0000110` | `1111001` = `0x79` |
| 2 | a b d e g | `1011011` | `0100100` = `0x24` |
| 3 | a b c d g | `1001111` | `0110000` = `0x30` |
| 4 | b c f g | `1100110` | `0011001` = `0x19` |
| 5 | a c d f g | `1101101` | `0010010` = `0x12` |
| 6 | a c d e f g | `1111101` | `0000010` = `0x02` |
| 7 | a b c | `0000111` | `1111000` = `0x78` |
| 8 | all | `1111111` | `0000000` = `0x00` |
| 9 | a b c d f g | `1101111` | `0010000` = `0x10` |
| A | a b c e f g | `1110111` | `0001000` = `0x08` |
| b | c d e f g | `1111100` | `0000011` = `0x03` |
| C | a d e f | `0111001` | `1000110` = `0x46` |
| d | b c d e g | `1011110` | `0100001` = `0x21` |
| E | a d e f g | `1111001` | `0000110` = `0x06` |
| F | a e f g | `1110001` | `0001110` = `0x0E` |

## Digit select (anode) -> expected output

`digit = cnt[18:16]` (REFRESH_BITS = 16), and `an = ~(1 << digit)`.

| digit | `an` | nibble shown | for `value = 0x0000_07B8` (ShieldV fault PC) |
|-------|------|--------------|----------------------------------------------|
| 0 (right) | `1111_1110` | `value[3:0]` | 8 → `0x00` |
| 1 | `1111_1101` | `value[7:4]` | B → `0x03` |
| 2 | `1111_1011` | `value[11:8]` | 7 → `0x78` |
| 3 | `1111_0111` | `value[15:12]` | 0 → `0x40` |
| 7 (left) | `0111_1111` | `value[31:28]` | 0 → `0x40` |

Exactly one bit of `an` is 0 at any time.

## Timing

- 50 MHz / 2¹⁶ = 763 Hz per digit, so the whole display refreshes at 763 / 8 ≈ 95 Hz. No flicker.
- In simulation, `seg7_driver_tb` uses a small `REFRESH_BITS` so that all 8 digits appear within a few hundred cycles.

## Edge cases I worry about

- The polarity: if the display shows the "inverse" of the digit, the inversion is missing or doubled.
- Digit order: digit 0 is the **right-most** digit, so `0x12345678` must read 1 2 3 4 5 6 7 8 from left to right.
- `b` and `d` are lower case, so they cannot be confused with 8 and 0.

Compare with `G2/Nilesh/tb/seg7_driver_tb.v`.

---
*Drafted with Claude (AI) from `rtl/seg7_driver.v` on 27 Oct 2026. Nilesh to check every row against the testbench (and the real board) before committing.
Checked by: Nilesh Das date: 27th October*
