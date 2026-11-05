# A12 Load/store unit (LSU)

## What it does

Memory is read and written one 32-bit word at a time, but RISC-V also has byte
(`sb`, `lb`, `lbu`) and half-word (`sh`, `lh`, `lhu`) accesses. The LSU does the byte
shuffling. On a **store**, it copies the byte or half into the right lane of `wdata` and
sets `wstrb` so that only those bytes are written. On a **load**, it shifts the addressed
byte or half down to bit 0 and then sign-extends or zero-extends it. It has no clock.

## Ports

| port | width | direction | meaning |
|------|-------|-----------|---------|
| `st_funct3` | 3 | in | store width: `000` sb, `001` sh, `010` sw |
| `st_offset` | 2 | in | `addr[1:0]` of the store |
| `st_data` | 32 | in | the `rs2` value to store |
| `st_en` | 1 | in | 1 only for a valid store |
| `wstrb` | 4 | out | byte-write enables, bit *i* = byte lane *i* |
| `wdata` | 32 | out | data for the bus, the byte/half copied into every lane |
| `ld_funct3` | 3 | in | `000` lb, `001` lh, `010` lw, `100` lbu, `101` lhu |
| `ld_offset` | 2 | in | `addr[1:0]` of the load |
| `rdata` | 32 | in | the whole word the RAM returned |
| `load_data` | 32 | out | the value written to `rd` |

## Store side: input -> expected output (`st_data = 0x1122_3344`)

| case | st_funct3 | offset | expected wstrb | expected wdata | why |
|------|-----------|--------|----------------|----------------|-----|
| sb lane 0 | 000 | 0 | `0001` | `0x4444_4444` | byte `0x44` copied to all 4 lanes, only lane 0 enabled |
| sb lane 1 | 000 | 1 | `0010` | `0x4444_4444` | same data, the strobe picks the lane |
| sb lane 2 | 000 | 2 | `0100` | `0x4444_4444` | `0001 << 2` |
| sb lane 3 | 000 | 3 | `1000` | `0x4444_4444` | `0001 << 3` |
| sh low half | 001 | 0 | `0011` | `0x3344_3344` | half `0x3344` copied to both halves |
| sh high half | 001 | 2 | `1100` | `0x3344_3344` | `offset[1] = 1` picks the upper half |
| sw | 010 | 0 | `1111` | `0x1122_3344` | whole word, no shuffling |
| not a store | any | any | `0000` | `0x0000_0000` | `st_en = 0`: nothing is written |

## Load side: input -> expected output (`rdata = 0x80FF_7F01`)

Byte lanes of `rdata`: lane 3 = `0x80`, lane 2 = `0xFF`, lane 1 = `0x7F`, lane 0 = `0x01`.

| case | ld_funct3 | offset | expected load_data | why |
|------|-----------|--------|--------------------|-----|
| lb lane 0 | 000 | 0 | `0x0000_0001` | `0x01` is positive, top bits are 0 |
| lb lane 1 | 000 | 1 | `0x0000_007F` | `0x7F` = +127, still positive |
| lb lane 2 | 000 | 2 | `0xFFFF_FFFF` | `0xFF` = -1, the sign bit is copied up |
| lb lane 3 | 000 | 3 | `0xFFFF_FF80` | `0x80` = -128 |
| lbu lane 2 | 100 | 2 | `0x0000_00FF` | same byte, zero-extended = 255 |
| lbu lane 3 | 100 | 3 | `0x0000_0080` | 128, no sign |
| lh low half | 001 | 0 | `0x0000_7F01` | `0x7F01`, bit 15 = 0 |
| lh high half | 001 | 2 | `0xFFFF_80FF` | `0x80FF`, bit 15 = 1, so the result is negative |
| lhu high half | 101 | 2 | `0x0000_80FF` | same half, zero-extended |
| lw | 010 | 0 | `0x80FF_7F01` | the whole word, unchanged |

## Edge cases I worry about

- `lb` and `lbu` read the same byte. Only bits 31..8 of the result differ.
- `sb` puts the byte in **every** lane of `wdata`. That is safe, because only the lane whose `wstrb` bit is 1 gets written.
- Misaligned `lw`/`sw` (for example `lw` at an address ending in `...2`) are not supported. The C compiler never produces them for our programs.
- Bubbles must never write memory. The core only drives `st_en = 1` for a valid store in EX.

Compare with the checks in `G1/Laxmidhar/tb/lsu_tb.v`.

---
*Drafted with Claude (AI) from `rtl/lsu.v` on 27 Oct 2026. Laxmidhar to check every row against `lsu_tb.v` before committing.
Checked by: Laxmidhar date: 27th October*
