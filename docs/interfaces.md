# Interface contracts (frozen)

These port lists and the memory map are the **only** things the groups share. Because they are
fixed before any Verilog is written, all three groups can build at the same time against stubs.

**Changing anything here needs every owner of that interface to agree.** Write the change and
the reason as a short note at the bottom of this file (decision log) in the same commit.

All signals: `clk` is the system clock; `rst_n` is a synchronous, active-low reset
(0 = reset). Widths are explicit.

---

## IF-1 · Core ↔ M-unit

Implemented by **Nishant** (G2). Called by the core (**Avani / Laxmidhar**, G1).

```verilog
// into the M-unit
input         start,      // 1-cycle pulse: begin an operation
input  [2:0]  op,         // funct3 of the M instruction (000 MUL ... 111 REMU)
input  [31:0] a, b,       // rs1 and rs2 values
// out of the M-unit
output        busy,       // high while working
output        done,       // 1-cycle pulse: result is valid this cycle
output [31:0] result
```

Rule: the core stalls while `busy` is high. `result` is valid only in the cycle `done` = 1.
MUL family finishes in ≤ 2 cycles, DIV family in ≤ 34 cycles.

| op (funct3) | 000 | 001 | 010 | 011 | 100 | 101 | 110 | 111 |
|---|---|---|---|---|---|---|---|---|
| instruction | MUL | MULH | MULHSU | MULHU | DIV | DIVU | REM | REMU |

## IF-2 · Core ↔ Data bus

Driven by the core (**Laxmidhar**'s load/store unit). Decoded by the SoC (**Nilesh**).

```verilog
output [31:0] addr,       // byte address
output [31:0] wdata,      // store data, already shifted to the right byte lanes
output [3:0]  wstrb,      // byte enables: 0001 = byte 0 ... 1111 = whole word
output        we,         // write enable (store)
output        re,         // read enable (load)
input  [31:0] rdata       // load data, available the NEXT cycle
```

## IF-3 · Core EX stage ↔ ShieldV

Exported by the core (**Laxmidhar**). Consumed by ShieldV (**Priyank**).

```verilog
// core -> ShieldV
output        ex_valid,   // a real instruction is in EX this cycle (not a bubble, not flushed, not waiting for the M-unit)
output [31:0] ex_instr,   // the instruction in EX
output [31:0] ex_pc,      // its address
output [31:0] ex_target,  // where a jal/jalr wants to jump (bit 0 already cleared for jalr)
output [31:0] ex_link,    // pc + 4, the return address a call saves
// ShieldV -> core
input         sh_freeze,  // hold the whole pipeline (commitment)
input         sh_trap,    // redirect to the handler instead of ex_target (goal)
input  [31:0] sh_handler_pc
```

## IF-4 · Trace port

Exported by the core (**Laxmidhar**). Observed by the ILA, the timing-diagram scripts and the
performance counters (**Nilesh**).

```verilog
output [31:0] if_pc, ex_pc, wb_pc,
output        stall, flush, ex_valid,
output        retire,       // an instruction finished
output        branch,       // a branch or jump finished           (added 2026-10-11)
output        mispredict    // ... and had to redirect the fetch   (added 2026-10-11)
```

For the out-of-order core, `ex_pc` is the reorder-buffer head and `stall` means
"nothing was dispatched this cycle".

---

## Memory map

Owned by **Nilesh** (bus decoder). Used by **Priyank**'s C runtime.

| Address | Name | Access | Meaning |
|---|---|---|---|
| `0x0000_0000` | IMEM | read | 16 KB, program code (.text) |
| `0x0001_0000` | DMEM | read/write | 16 KB, data + stack; `sp` starts at `0x0001_4000` |
| `0x1000_0000` | LED | write | 16 bits to the board LEDs |
| `0x1000_0004` | SEG7 | write | 32 bits = 8 hex digits on the display |
| `0x1000_0008` | SWITCH | read | 16 switches, synchronised |
| `0x1000_0010` | UART_TX | write | send 1 byte |
| `0x1000_0014` | UART_STATUS | read | bit 0 = busy |
| `0x1000_0020` | CYCLE | read | cycles since reset |
| `0x1000_0024` | INSTRET | read | instructions retired |
| `0x1000_0028` | CALLS | read | calls seen by ShieldV (pushes) |
| `0x1000_002C` | RETS | read | returns seen by ShieldV (pops) |
| `0x1000_0030` | SHIELD_CTRL | read/write | bit 0 enable (reset 1), bit 1 trap mode, bit 2 count-only, bit 3 landing-pad check, bit 4 **lock** |
| `0x1000_0034` | SHIELD_STAT | read | [7:0] violations, [13:8] depth, [19:16] cause, [30] locked, [31] alarm |
| `0x1000_0038` | FAULT_PC | read | PC of the instruction that was caught |
| `0x1000_003C` | EXPECTED | read | return address ShieldV saved |
| `0x1000_0040` | ACTUAL | read | address the program tried to go to |
| `0x1000_0044` | SHIELD_HANDLER | read/write | security handler address (trap mode) |
| `0x1000_0050` | BRANCHES | read | branches and jumps retired |
| `0x1000_0054` | MISPRED | read | of those, how many redirected the fetch (mispredicted) |
| `0x1000_0058` | VIOL | read | ShieldV violations seen (counts even while frozen) |
| `0x1000_005C` | CORE_ID | read | 0 = in-order core, 1 = out-of-order core |
| `0x1000_00FC` | SIM_EXIT | write | simulation only: the testbench stops and prints the value |

Unmapped reads return 0. Unmapped writes are ignored. The instruction RAM is not
on the data bus, so constant data (strings, tables) is linked into the data RAM.

SHIELD_STAT cause codes: 1 return mismatch, 2 shadow-stack underflow,
3 shadow-stack overflow, 4 missing landing pad.

Protection is on only when SHIELD_CTRL bit 0 **and** switch SW0 are both 1.

**Lock bit.** Writing SHIELD_CTRL with bit 4 = 1 sets the lock (the other bits of that same
write still take effect). From then on every write to SHIELD_CTRL and SHIELD_HANDLER is
ignored until reset. Boot code sets it right after turning protection on, so a program
bug that lets an attacker write memory cannot switch ShieldV off or move the handler.
SW0 still works: it is a physical switch, not a memory write.

**Why memory-mapped I/O?** C code lights an LED or prints a character with an ordinary store
(`*(volatile unsigned*)0x10000000 = 0xFFFF;`). No new instructions are needed, and the I/O can be
tested without a CPU.

---

## Decision log

Add one line per change: date, what changed, why, who agreed.

- 2026-10-04 · Contracts IF-1 to IF-4 and memory map frozen from the build plan.
