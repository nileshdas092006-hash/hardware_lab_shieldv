# A21 Register alias table (rename table)

## What it does

For each architectural register x1..x31, the table remembers where its newest value will
come from. `busy = 0` means the value is already in the register file. `busy = 1` means it
is still being computed by the instruction in ROB entry `tag`. Two instructions that both
write x5 get different tags, so a later reader waits for the right one and the writers
never wait for each other. This removes WAR and WAW stalls.

## Ports

| port | width | dir | meaning |
|------|-------|-----|---------|
| `ra1`, `ra2` | 5 | in | source registers of the instruction being dispatched |
| `busy1`/`tag1`, `busy2`/`tag2` | 1 / 4 | out | is the source still in flight, and which ROB entry will produce it |
| `d_we`, `d_rd`, `d_tag` | 1 / 5 / 4 | in | dispatch: `rd` will now come from ROB entry `d_tag` |
| `c_en`, `c_rd`, `c_tag` | 1 / 5 / 4 | in | commit: ROB entry `c_tag` has written `rd` to the register file |
| `flush` | 1 | in | mispredict or trap: forget everything in flight |

## Sequence -> expected table state

Start after reset: every `busy = 0`. Each row is one clock edge.

| step | action | expected state after the edge | reads in the same cycle | why |
|------|--------|-------------------------------|-------------------------|-----|
| 1 | dispatch `add x5,...` with tag 3 | x5: busy=1, tag=3 | - | x5 now comes from ROB 3 |
| 2 | read ra1 = x5 | unchanged | busy1=1, tag1=3 | a reader of x5 must wait for ROB 3 |
| 3 | dispatch `sub x5,...` with tag 4 | x5: busy=1, tag=4 | - | WAW: the newer writer takes over |
| 4 | commit tag 3, rd = x5 | x5: busy=1, tag=4 | - | tag 3 ≠ 4, so x5 stays busy (a younger writer is still in flight) |
| 5 | commit tag 4, rd = x5 | x5: busy=0 | - | tag matches: the value is now in the register file |
| 6 | read ra1 = x5 | unchanged | busy1=0 | read the register file directly |
| 7 | dispatch x0 with tag 7 | x0: busy=0 | - | x0 is never renamed |
| 8 | read ra1 = x0 | - | busy1=0 | x0 always reads as ready (and as 0) |
| 9 | dispatch x6 tag 2, and commit x6 tag 1, same cycle | x6: busy=1, tag=2 | - | dispatch wins over commit for the same register |
| 10 | dispatch x8 tag 5, then `flush` | all busy=0 | - | flush throws away everything in flight; all reads come from the register file |

## Edge cases I worry about

- Step 4 is the key case. Committing an **old** writer must not free a register that a younger writer still owns.
- Dispatch and commit of the same register in one cycle (step 9).
- After a flush, the tags are stale, but that is harmless because `busy = 0` means nobody looks at them.
- x0 never becomes busy, from either a read or a write.

Compare with `G1/Laxmidhar/tb/rename_table_tb.v`.

---
*Drafted with Claude (AI) from `rtl/rename_table.v` on 27 Oct 2026. Laxmidhar to check every row against the testbench before committing.
Checked by: Laxmidhar date: 27th October*
