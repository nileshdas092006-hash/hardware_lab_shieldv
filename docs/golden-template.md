# How to write a golden table

A golden table is **your prediction** of what a block should do, written by you
**before** you look at the simulation. When the testbench and your table disagree,
either the code or your understanding is wrong, and finding out which one is how you
learn the block well enough for the viva.

Put it in your own folder: `golden/<block id>_<block name>.md`, for example
`G1/Avani/golden/A6_alu.md`.

## Template

```markdown
# <id> <block name>

## What it does (2-3 sentences, your own words)

## Ports
| port | width | direction | meaning |
|------|-------|-----------|---------|

## Input -> expected output
| case | inputs | expected output | why |
|------|--------|-----------------|-----|

## Expected waveform (only for clocked blocks)
cycle:   0    1    2    3
start:   1    0    0    0
busy:    0    1    1    0
done:    0    0    0    1

## Edge cases I worry about
-
```

## Worked example: A6 ALU

| case | a | b | op | expected y | why |
|---|---|---|---|---|---|
| add | 5 | 3 | 0000 | 8 | plain addition |
| wrap | 0xFFFF_FFFF | 1 | 0000 | 0 | -1 + 1, the carry out is dropped |
| sub | 3 | 5 | 1000 | 0xFFFF_FFFE | 3 - 5 = -2 in two's complement |
| shift by 31 | 1 | 31 | 0001 | 0x8000_0000 | largest legal shift |
| shift amount uses 5 bits | 1 | 32 | 0001 | 1 | 32 = 0b100000, low 5 bits are 0 |
| slt signed | 0xFFFF_FFFF | 1 | 0010 | 1 | -1 < 1 |
| sltu unsigned | 0xFFFF_FFFF | 1 | 0011 | 0 | 4294967295 is not < 1 |
| sra keeps sign | 0x8000_0000 | 31 | 1101 | 0xFFFF_FFFF | arithmetic shift copies the sign bit |
| srl fills zeros | 0x8000_0000 | 31 | 0101 | 1 | logical shift fills with 0 |

Compare with the directed checks at the top of `G1/Avani/tb/alu_tb.v`: they are this
table turned into code.
