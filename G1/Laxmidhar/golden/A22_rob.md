# A22 Reorder buffer (ROB, 16 entries)

## What it does

The out-of-order core executes instructions as soon as their operands are ready, but the
program must still see them finish in program order. The ROB is a 16-entry circular queue.
Instructions are allocated at the **tail** in program order and marked **done** when their
result comes over the common data bus (CDB). Only the **head**, the oldest entry, may
**commit**, and only once it is done. Nothing becomes permanent before commit: not the
register write, the store, or ShieldV's push and pop. So a wrong guess is undone by a
**flush**, which drops every entry behind the head.

## Ports (main ones)

| port | dir | meaning |
|------|-----|---------|
| `alloc`, `a_*` | in | dispatch a new instruction at the tail |
| `alloc_tag` | out | the entry number it gets (= its tag on the CDB) |
| `full` | out | 16 entries in use: dispatch must wait |
| `cdb_valid`, `cdb_tag`, `cdb_value` | in | a result is ready: mark entry `cdb_tag` done |
| `st_valid`, `st_tag`, `st_addr` | in | a store has its address and data: mark it done |
| `rd_tag1/2` → `rd_done1/2`, `rd_value1/2` | in/out | dispatch reads results that are done but not yet committed |
| `head_valid`, `head_done`, `head_*` | out | the oldest instruction and whether it can commit |
| `commit` | in | retire the head this cycle; the core raises it only when `head_done = 1` (the ROB itself only checks `head_valid`) |
| `flush` | in | drop everything (after this cycle's commit) |

## Sequence -> expected state

Start after reset: head = 0, tail = 0, count = 0.

| step | action | expected head / tail / count | other outputs | why |
|------|--------|------------------------------|---------------|-----|
| 1 | alloc A (`lw x5`) | 0 / 1 / 1 | alloc_tag was 0 | A gets entry 0 |
| 2 | alloc B (`add x6,x5,x1`) | 0 / 2 / 2 | alloc_tag was 1 | B gets entry 1 |
| 3 | alloc C (`addi x7,x0,1`) | 0 / 3 / 3 | - | C gets entry 2 |
| 4 | CDB: tag 2 (C) done | 0 / 3 / 3 | head_done = 0 | C finished first, but head is A, so nothing commits |
| 5 | CDB: tag 0 (A) done | 0 / 3 / 3 | head_done = 1 | the oldest is now done |
| 6 | commit | 1 / 3 / 2 | head is now B, head_done = 0 | A retires; B is still waiting |
| 7 | CDB: tag 1 (B) done | 1 / 3 / 2 | head_done = 1 | B can commit next cycle |
| 8 | commit, commit | 3 / 3 / 0 | head_valid = 0 | B then C retire in order; the ROB is empty |
| 9 | alloc 16 entries | 3 / 3 / 16 (tail wrapped) | full = 1 | 16 in use; the 17th alloc is ignored |
| 10 | flush (with commit = 1) | 4 / 4 / 0 | full = 0, all done = 0 | head retires, everything younger is dropped |

## Edge cases I worry about

- Results arrive out of order (step 4), but commits stay in order (steps 6 and 8).
- Wrap-around: tail goes 15 → 0. With 4-bit pointers this happens on its own, and `count` (5 bits) tells full from empty.
- `alloc` while full, or during a flush, must be ignored.
- A flush in the same cycle as a commit keeps that commit (head + 1) and drops everything else.
- ShieldV checks returns at **commit**, so a return on a mispredicted path never touches the shadow stack.

Compare with `G1/Laxmidhar/tb/rob_tb.v`.

---
*Drafted with Claude (AI) from `rtl/rob.v` on 27 Oct 2026. Laxmidhar to check every row against the testbench before committing.
Checked by: Laxmidhar date: 27th October*
