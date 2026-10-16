# A5 Register file

## What it does (2-3 sentences, my own words)

The register file is the CPU's 32 tiny "notebook pages" (x0 to x31), each holding one
32-bit number. Every cycle it can **read two** registers at once (for `rs1` and `rs2`) and
**write one** (for `rd`). Reading is instant (no clock), writing happens on the rising
clock edge; x0 is hard-wired to 0, and with `WRITE_THROUGH = 1` a register being written
this cycle is read back with its **new** value.

## Ports

| port | width | direction | meaning |
|------|-------|-----------|---------|
| `clk` | 1 | in | clock; writes happen on its rising edge |
| `ra1` | 5 | in | read address 1 (`rs1`) |
| `ra2` | 5 | in | read address 2 (`rs2`) |
| `rd1` | 32 | out | value of register `ra1` (asynchronous) |
| `rd2` | 32 | out | value of register `ra2` (asynchronous) |
| `we`  | 1 | in | write enable |
| `wa`  | 5 | in | write address (`rd`) |
| `wd`  | 32 | in | data to write |
| parameter `WRITE_THROUGH` | – | – | 1 = forward `wd` to a same-cycle reader (pipeline); 0 = off (single-cycle core) |

No reset port: the array becomes LUTRAM, which has no reset, and RISC-V does not promise
any register value after reset (crt0 sets `sp` itself). In simulation the `initial` block
fills everything with 0 so the waveforms are clean.

## Input -> expected output

| case | inputs | expected output | why |
|------|--------|-----------------|-----|
| read x0 | `ra1 = 0` | `rd1 = 0` | x0 is always zero |
| write x0 | `we=1, wa=0, wd=0xDEAD_BEEF`, clock edge, then `ra1=0` | `rd1 = 0` | the write is ignored (`wa != 0` check) |
| x0 during the write | same cycle as above, `ra1 = 0` | `rd1 = 0`, **not** `0xDEAD_BEEF` | the `ra1 == 0` check comes **before** the write-through check |
| normal write | `we=1, wa=5, wd=0x1234`, clock edge, then `ra1=5` | `rd1 = 0x1234` | stored on the edge |
| write disabled | `we=0, wa=5, wd=0xFFFF`, clock edge, then `ra1=5` | `rd1 = 0x1234` (old) | `we = 0` means nothing changes |
| both ports, different regs | `ra1 = 3, ra2 = 28` | `rd1 = x3`, `rd2 = x28` | two independent read ports |
| both ports, same reg | `ra1 = ra2 = 7` | `rd1 = rd2 = x7` | reading the same register twice is fine |
| write-through (WT=1) | x9 holds `0xAAAA`; this cycle `we=1, wa=9, wd=0xBBBB, ra1=9` | `rd1 = 0xBBBB` **before** the edge | bypass: reader gets the new value straight from `wd` |
| no write-through (WT=0) | same as above | `rd1 = 0xAAAA` until the edge, then `0xBBBB` | single-cycle core: the reader **is** the writer |
| write-through, `we = 0` | `we=0, wa=9, wd=0xBBBB, ra1=9` | `rd1 = 0xAAAA` | bypass only when actually writing |
| every register | write `0xA5A5_0000 \| i` to each `i`, read back all 32 on both ports | `x0 = 0`, others = their pattern | catches a stuck address bit |

## Expected waveform (WRITE_THROUGH = 1)

Writes happen at the rising edge at the **end** of the cycle. Before that edge,
`rd1` comes from the bypass; after it, from the array.

```
cycle:      0         1         2         3
we:         1         0         1         0
wa:         9         -         0         -
wd:       BBBB        -       DEAD        -
ra1:        9         9         0         9
rd1:      BBBB      BBBB        0       BBBB
            ^bypass   ^array    ^x0 wins  ^still BBBB (x0 write did nothing)
```

## Expected waveform (WRITE_THROUGH = 0, single-cycle core)

```
cycle:      0         1
we:         1         0
wa:         9         -
wd:       BBBB        -
ra1:        9         9
rd1:      AAAA      BBBB     <- new value only after the edge
```

## Edge cases I worry about

- **x0 and write-through together.** If the bypass check came first, writing x0 would
  briefly leak a non-zero value to a reader of x0. The order `x0 ? 0 : bypass ? wd : regs`
  fixes that.
- **Combinational loop in the single-cycle core.** `addi x1, x1, 1` reads and writes x1 in
  the same cycle. With write-through on, `wd` would feed `rd1`, which feeds the ALU, which
  feeds `wd` again: a loop with no register in it. That is why `core_single.v` uses
  `WRITE_THROUGH(0)`.
- **Why write-through at all?** In the pipeline, an instruction in writeback and a later
  instruction in decode touch the same register in the same cycle. Without the bypass the
  later one would read the stale value.
- **No reset.** I must not write a testbench that expects all registers to be 0 after
  `rst_n` on the FPGA; that is only true in simulation because of the `initial` block.
- **x1 (`ra`) is the register the attack corrupts**, so this block holds the value
  ShieldV protects.
