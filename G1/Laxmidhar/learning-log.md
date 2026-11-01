# Learning log · G1 pipeline control (Laxmidhar Mohapatra)

Five plain-language lines per block: what it does, the key idea, what surprised me, how it
connects to ShieldV, and a "break it on purpose" check (what I change, which test should
catch it). Golden tables are in [`golden/`](golden/).

## A12 Load/Store Unit (`rtl/lsu.v`)

1. Shuffles byte and halfword data between 32-bit CPU registers and memory based on transfer size and byte offset.
2. Store generation creates active byte strobes (`wstrb`) by shifting byte/halfword masks; loads shift selected bytes to bit 0 and sign- or zero-extend.
3. Memory is strictly 32-bit aligned in hardware, so a byte store to address `0x0002` sets `wstrb = 4'b0100` rather than altering the physical bus address.
4. The return address overwrite in the attack program is a `sw` instruction; if `wstrb` or data alignment fails, the attack wouldn't even target the stack correctly.
5. Break it: change `wstrb` for halfword store (`sh`) at offset 0 to `4'b0001` instead of `4'b0011`. The store tests in `lsu_tb` fail immediately on halfword writes.

## A8-A11 Pipeline Registers (`rtl/pipe_ifid_ex.v`, `rtl/pipe_ex_wb.v`)

1. Synchronous stage registers that carry instructions, operands, PC, and control flags from IF/ID into EX, and execution results from EX into MEM/WB.
2. Stall freezes the upstream register so no state is lost, while flush clears the valid bit or replaces the instruction with a `nop` bubble.
3. A single bubble insertion requires coordinating stall on the upstream register and synchronous flush on the downstream register simultaneously.
4. When ShieldV signals a trap, the pipeline registers must instantaneously squash wrong-path speculative instructions in IF/ID before they execute.
5. Break it: ignore the `flush` input in `pipe_ifid_ex.v`. `pipe_regs_tb` catches that flushed cycles still propagate valid instructions instead of bubbles.

## Forwarding Unit (`rtl/forward_unit.v`)

1. Detects data hazards where an instruction in EX needs a register value currently being computed by the instruction in MEM/WB.
2. Directly routes the writeback data mux output back to ALU operand inputs `a` or `b`, bypassing the register file write and read cycle.
3. Forwarding must never activate for register `x0`, because writes to `x0` are discarded and reading `x0` must always return zero.
4. In `timing_final.S`, reading back `SHIELD_CTRL` into `t4` is immediately followed by a branch; forwarding provides the value with zero stall cycles.
5. Break it: omit `rd != 5'd0` in the comparator. Forwarding stale data on `x0` causes `hazard_tb` to fail on zero-register dependency tests.

## Hazard & Stall Unit (`rtl/hazard_unit.v`)

1. Monitors system-wide structural and multi-cycle execution hazards to temporarily freeze instruction progression across the pipeline.
2. Asserts a global pipeline stall whenever the multi-cycle M-extension multiplier/divider is active (`m_busy = 1`) or ShieldV enters a security freeze.
3. Stall must hold the PC register and the IF/ID register frozen while allowing the EX stage to finish its multi-cycle computation.
4. When ShieldV detects a control-flow violation in ALARM mode, `freeze = 1` commands the hazard unit to halt the core permanently to prevent payload execution.
5. Break it: deassert `stall` while `m_busy` is high. The multi-cycle multiplication test in `hazard_tb` fails because subsequent instructions clobber the multiplier.

## Flush Unit (`rtl/flush_unit.v`)

1. Clears transient, wrong-path instructions from the fetch and decode stages upon taken branches, jumps, or hardware trap exceptions.
2. Generates single-cycle synchronous flush pulses that turn speculative IF/ID contents into harmless pipeline bubbles.
3. Traps take strict precedence over normal branch mispredict flushes, ensuring urgent hardware security vectors are never overridden.
4. When a hijacked return triggers ShieldV's `trap = 1`, the flush unit discards the attacker's target instruction before it enters the execution datapath.
5. Break it: force `flush_ifid` low during a taken branch. Branch tests in `hazard_tb` fail because the wrong fall-through instruction executes.

## Trace Port (`rtl/trace_port.v`)

1. Non-intrusive monitoring interface that snoops instructions retiring in the pipeline and decodes branch, call, and return events.
2. Identifies function calls (`jal`/`jalr` with `rd = x1`) and returns (`jalr` with `rs1 = x1, rd = x0`), passing target PCs and event pulses to ShieldV.
3. Distinguishing calls from returns requires examining both opcode and register index fields simultaneously (`rd` vs `rs1`).
4. This block is ShieldV's eyes: without the trace port's real-time signals, the shadow stack cannot know when to push or pop return addresses.
5. Break it: change return detection to ignore `rs1 == 5'd1`. ShieldV stops receiving `is_ret` pulses and completely misses return violations in simulation.

## 3-Stage Pipelined Core (`rtl/core_pipe.v`)

1. Top-level integration connecting fetch (PC, IMEM), decode/execute (ALU, decoder, regfile, branch, LSU), and writeback with forwarding and hazards.
2. Operates at a target CPI approaching 1.0 for straight-line code, dropping only on branch mispredictions, multi-cycle M-ops, and load delays.
3. Maintaining correct signal polarity across stage registers requires strict adherence to naming conventions (`f_`, `e_`, `w_`).
4. Integrates the ShieldV wrapper seamlessly between the execution branch comparator and the instruction fetch redirection multiplexer.
5. Break it: disconnect `fwd_a` from the ALU first operand multiplexer. `core_pipe_tb` fails on RAW dependency assembly programs.

## A21 Register Alias Table (`rtl/rename_table.v`)

1. Out-of-order register renaming structure mapping 32 architectural RISC-V registers (ARF) to speculative Physical Register / ROB tags.
2. Eliminates false WAW (write-after-write) and WAR (write-after-read) dependencies by assigning a fresh physical tag on every architectural write.
3. Architectural register `x0` is hardwired to tag `0` and ready status, ensuring attempts to rename `x0` never consume real renaming entries.
4. In speculative execution, an attack that overwrites `ra` generates a speculative tag; if squashed, the RAT restores committed architectural state.
5. Break it: allow `x0` to allocate a valid rename tag. `rename_table_tb` fails when instructions writing `x0` contaminate physical register mappings.

## A22 Reorder Buffer (`rtl/rob.v`)

1. 16-entry circular FIFO tracking out-of-order instruction completion and guaranteeing in-order architectural retirement and precise exceptions.
2. Instructions allocate entries in program order at decode, receive completion values from the CDB out of order, and commit only at the FIFO head.
3. An instruction that encounters an exception or misprediction holds the exception flag until reaching the commit head, preventing premature state corruption.
4. ShieldV's violation trap is integrated at commit: a mispredicted or tampered return is flushed cleanly before committing architectural state.
5. Break it: advance the commit pointer before `rob_ready[head]` is asserted. `rob_tb` fails due to committing uncalculated speculative results.

## Reservation Station (`rtl/rs.v`)

1. Distributed execution buffer holding dispatched instructions until all source operands are valid and the execution unit is available.
2. Snoops the Common Data Bus (CDB) every cycle to wake up waiting source tags when earlier instructions produce their results.
3. Instructions can dispatch out of order as soon as both operands are marked ready, achieving true dynamic instruction-level parallelism.
4. When ShieldV freezes execution, RS issue grants are withheld, preventing further instruction scheduling until the security exception resolves.
5. Break it: disable CDB tag matching for operand 2. `rs_tb` fails because dependent instructions waiting on operand 2 hang indefinitely.

## Load/Store Queue (`rtl/lsq.v`)

1. Manages out-of-order memory operations, enforcing memory disambiguation rules, store-to-load forwarding, and in-order bus access.
2. Loads can bypass older pending stores once all older store addresses are known and disjoint; matching addresses forward store data directly.
3. Stores are never written to data RAM speculatively; they remain in the store buffer until the instruction reaches ROB commit.
4. The attack's stack overwrite store is held in the LSQ until commit, ensuring speculative memory writes cannot pollute cache or memory early.
5. Break it: permit speculative stores to write directly to data RAM before ROB commit. `lsq_tb` fails when flushed speculative branch paths corrupt memory.

## Common Data Bus Arbiter (`rtl/cdb_arbiter.v`)

1. Arbitrates broadcast access to the Common Data Bus among competing functional units (ALU, LSU, Multiplier/Divider).
2. Prioritizes long-latency multi-cycle units to minimize execution buffer congestion and prevent head-of-line blocking in reservation stations.
3. Broadcasts the winning result, destination tag, and validity bit across the ROB and Reservation Stations in a single clock cycle.
4. The CDB broadcast latency directly dictates how fast speculative results propagate to dependent instructions waiting in the pipeline.
5. Break it: invert priority to favor single-cycle ALU over the M-unit. Multiplier-heavy benchmark testbenches experience starvation and latency penalties.

## Out-of-Order Core (`rtl/core_ooo.v`)

1. Complete superscalar/dynamic RV32IM core combining RAT, ROB, Reservation Stations, LSQ, and CDB with the same external bus interface as `core_pipe`.
2. Decouples instruction dispatch from execution, allowing instructions behind high-latency operations to execute out of program order.
3. Preserves precise architectural state by rolling back RAT pointers and ROB entries upon branch mispredictions or security exceptions.
4. Connects to the same ShieldV hardware security module, proving that shadow-stack return address validation operates correctly on dynamic out-of-order cores.
5. Break it: commit instructions out of order from the ROB tail. `core_ooo_tb` fails immediately on hazard test programs.
