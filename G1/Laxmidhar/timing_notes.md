# Timing Notes · Final Timing Diagram (24 Clock Cycles)

**Author:** Laxmidhar Mohapatra (G1 - Pipeline Control)  
**Program:** `timing_final.S` on 3-Stage Pipelined RV32IM Core with ShieldV Shadow Stack (`SW0 = 1`)  
**Waveform Reference:** `diagrams/timing_diagram.svg` / `diagrams/timing_diagram.png` (generated via `scripts/vcd2wave.py`)

---

## Overview

The final timing diagram captures a 24-clock-cycle execution window of `timing_final.S` starting from the first store instruction configuring `SHIELD_CTRL`. This trace exercises the key interactions between the 3-stage pipeline (IF/ID, EX, MEM/WB), pipeline hazard control (stall, flush, forwarding), the multi-cycle M-extension execution unit, and the ShieldV hardware security module (shadow stack, violation detection, trap redirection).

---

## Cycle-by-Cycle Trace Breakdown

### Phase 1: Security Configuration and Attacker Lockout (Cycles 1–4)

* **Cycle 1: `sw t3, 0x30(t1)` (Configure and Lock ShieldV)**
  * **Pipeline State:** The store instruction is in the EX stage (`e_pc = 0x0000_0038`).
  * **Bus Interface:** `bus_we = 1`, `bus_addr = 0x1000_0030`, `bus_wdata = 0x0000_0013`.
  * **ShieldV Status:** `SHIELD_CTRL` register transitions to `0x13` (`enable = 1`, `trap_mode = 1`, `lock = 1`).
  * **Lock Transition:** `locked` signal asserts (`locked = 1`), permanently preventing subsequent software writes from clearing the protection or changing the security policy until hard reset.

* **Cycle 2: `sw zero, 0x30(t1)` (Attacker Attempt: Ignored)**
  * **Pipeline State:** Attacker attempt in EX stage (`e_pc = 0x0000_003C`).
  * **Bus Interface:** `bus_we = 1`, `bus_addr = 0x1000_0030`, `bus_wdata = 0x0000_0000`.
  * **ShieldV Status:** Because `locked = 1`, the write decoder inside `mode_reg.v` ignores the write request. `SHIELD_CTRL` remains firmly at `0x13`.

* **Cycle 3: `lw t4, 0x30(t1)` (Verify Lock Configuration)**
  * **Pipeline State:** Load instruction in EX stage (`e_pc = 0x0000_0040`).
  * **Bus Interface:** `bus_re = 1`, `bus_addr = 0x1000_0030`. The bus returns `bus_rdata = 0x0000_0013`.
  * **Forwarding Setup:** The loaded value is staged into the MEM/WB pipeline register for forwarding to the subsequent branch.

* **Cycle 4: `bne t4, t3, fail` (Branch Not Taken)**
  * **Pipeline State:** Branch instruction evaluates in EX stage (`e_pc = 0x0000_0044`).
  * **Forwarding Unit:** Operands `t4` (`0x13`) and `t3` (`0x13`) are compared.
  * **Hazard Decision:** Condition evaluates to false ($19 \ne 19$ is false). Branch is NOT taken.
  * **Pipeline Flow:** No stall, no flush (`stall = 0`, `flush = 0`). The next instruction `jal ra, scale` was already fetched into IF/ID and proceeds directly into EX.

---

### Phase 2: Function Call, Multi-Cycle Stall, and Return (Cycles 5–11)

* **Cycle 5: `jal ra, scale` (Call: Shadow Stack Push & Pipeline Flush)**
  * **Pipeline State:** JAL instruction reaches EX stage (`e_pc = 0x0000_0048`).
  * **Control Decision:** JAL unconditionally redirects PC to target `scale` (`0x0000_0060`).
  * **Flush Unit:** Asserts `flush_ifid = 1` to discard the fall-through instruction (`beq a0, a2, 1f`) fetched in cycle 5.
  * **ShieldV Trace:** The trace port detects a call instruction (`is_call = 1`, `link_ra = 1`).
  * **Shadow Stack Push:** `do_push = 1`. The return address `0x0000_004C` is pushed onto the shadow stack. Stack depth increases from `0` to `1` (`ss depth = 1`), and `ss top` becomes `0x0000_004C`.

* **Cycle 6: Pipeline Bubble (Branch Delay / Refill)**
  * **Pipeline State:** Pipeline bubble in EX stage caused by the JAL redirect in cycle 5.
  * **Fetch Stage:** Target address `scale` (`0x0000_0060`) is fetched from instruction memory.

* **Cycles 7–9: `mul a0, a0, a1` (Multi-Cycle M-Unit Busy Stall)**
  * **Cycle 7:** `mul` instruction enters EX stage (`e_pc = 0x0000_0060`). It triggers the iterative/pipelined multiplier (`m_valid = 1`).
  * **Hazard Unit:** The multiplier asserts `m_busy = 1`. The hazard unit immediately asserts `stall = 1`.
  * **Cycle 8:** Multiplier processing. The instruction in EX is held, IF/ID pipeline register holds PC, and PC register freeze holds fetch (`stall = 1`, `m_busy = 1`).
  * **Cycle 9:** Multiplier completes calculation ($7 \times 3 = 21$). `m_busy` deasserts at the end of cycle 9, allowing result writeback and releasing pipeline stall.

* **Cycle 10: `ret` / `jalr x0, 0(ra)` (Legitimate Return: Shadow Stack Pop)**
  * **Pipeline State:** Return instruction in EX stage (`e_pc = 0x0000_0064`).
  * **Control Decision:** Target is read from register `ra` (`0x0000_004C`).
  * **Flush Unit:** Asserts `flush_ifid = 1` to clear wrong-path fetch.
  * **ShieldV Trace:** The trace port identifies a return (`is_ret = 1`).
  * **Shadow Stack Check:** Expected target from shadow stack (`ss top = 0x0000_004C`) is compared against actual target (`ex_target = 0x0000_004C`).
  * **Result:** Perfect match! `mismatch = 0`. Shadow stack pops (`do_pop = 1`), reducing depth back to `0` (`ss depth = 0`).

* **Cycle 11: Pipeline Bubble (Return Delay / Refill)**
  * **Pipeline State:** Bubble in EX stage while PC refills to the return site `0x0000_004C`.

---

### Phase 3: Taken Branch and Stack Buffer Overflow (Cycles 12–15)

* **Cycle 12: `beq a0, a2, 1f` (Branch Taken: Mispredict Flush)**
  * **Pipeline State:** Branch instruction in EX stage (`e_pc = 0x0000_004C`).
  * **Evaluation:** $a0 = 21$ equals $a2 = 21$. Branch condition is met (TAKEN).
  * **Hazard / Branch Unit:** The default static predictor assumed not-taken. The branch unit marks misprediction (`tr_mispredict = 1`, `tr_branch = 1`).
  * **Flush Unit:** Asserts `flush_ifid = 1` to flush the wrong-path instruction `j fail` from IF/ID.
  * **PC Redirection:** Next PC is updated to label `1f` (`0x0000_0054`).

* **Cycle 13: Pipeline Bubble (Branch Delay / Refill)**
  * **Pipeline State:** Pipeline bubble in EX stage while target `0x0000_0054` is fetched.

* **Cycle 14: `sw t2, 12(sp)` (Simulated Attack: Stack Buffer Overwrite)**
  * **Pipeline State:** Store instruction in EX stage (`e_pc = 0x0000_0054`).
  * **Memory Operation:** Writes malicious target address `&hacked` (`t2 = 0x0000_0068`) into the stack slot `12(sp)` where the legitimate caller return address was saved.
  * **Bus Interface:** `bus_we = 1`, `bus_addr = 0x0000_3FFC`, `bus_wdata = 0x0000_0068`. Data RAM is corrupted by the attack.

* **Cycle 15: `lw ra, 12(sp)` (Loading Corrupted Return Address)**
  * **Pipeline State:** Load instruction in EX stage (`e_pc = 0x0000_0058`).
  * **Memory Operation:** Loads corrupted pointer from `12(sp)` into register `ra`.
  * **Forwarding:** Data forwarded to EX stage for the upcoming return instruction.

---

### Phase 4: Security Violation Detection and Hardware Trap (Cycles 16–24)

* **Cycle 16: `ret` / `jalr x0, 0(ra)` (Tampered Return Detected!)**
  * **Pipeline State:** Corrupted return instruction in EX stage (`e_pc = 0x0000_005C`).
  * **Target Resolution:** Instruction attempts to jump to `ex_target = 0x0000_0068` (`&hacked`).
  * **ShieldV Check:**
    * Shadow stack top holds the legitimate caller return address (`ss top = 0x0000_0034`).
    * Actual branch target: `ex_target = 0x0000_0068`.
    * **MISMATCH DETECTED:** `mismatch = 1` asserts combinationally!
  * **Hardware Trap Trigger:**
    * In trap mode (`SHIELD_CTRL[1] = 1`), ShieldV asserts `trap = 1` and `sh_trap = 1`.
    * Fault registers latch immediately:
      * `fault pc = 0x0000_005C` (address of violating return instruction)
      * `fault actual = 0x0000_0068` (unauthorized target address)
    * Violation counter increments: `violations = 1`.
  * **Pipeline Redirection:** Hardware overrides the branch target! Instead of jumping to `hacked` (`0x0000_0068`), the PC is forcibly redirected to the registered security trap handler `shield_trap_entry` (`0x0000_0200`).
  * **Flush Unit:** Asserts `flush = 1` to squash any speculative wrong-path fetch.

* **Cycle 17: Pipeline Bubble (Trap Redirection Delay)**
  * **Pipeline State:** Bubble in EX stage while vector address `0x0000_0200` is fetched from IMEM.
  * **Attack Neutralized:** Attacker's code at `hacked` was never fetched or executed.

* **Cycles 18–24: Security Trap Handler Execution**
  * **Cycle 18:** Handler entry instruction fetched (`shield_trap_entry` in `crt0.S`).
  * **Cycles 19–21:** Secure stack pointer initialization and state preservation.
  * **Cycle 22:** Function call into `shield_trap_handler` (shadow stack pushes handler return address, `ss depth = 1`).
  * **Cycles 23–24:** Handler inspects fault registers (`fault_pc`, `fault_actual`, `f_count`) and cleanly exits the simulation with exit code `3` (`RESULT: EXIT 3`).

---

## Summary of Verified Pipeline Control Features

1. **Hazard Forwarding:** Tested in Cycle 4 (`lw` to `bne`), enabling zero-penalty dependent operations without pipeline bubbles.
2. **Multi-Cycle Stall:** Tested in Cycles 7–9 (`m_busy`), verifying that the hazard unit holds PC and IF/ID while maintaining instruction integrity in EX.
3. **Control Hazard Flushing:** Verified in Cycles 5 (`jal`), 10 (`ret`), 12 (`beq taken`), and 16 (`sh_trap`), confirming that branch penalty bubbles correctly clear transient instructions from IF/ID.
4. **Security Intervention:** Demonstrated zero-latency hardware detection of corrupted control flow with immediate trap redirection to the trusted handler.
