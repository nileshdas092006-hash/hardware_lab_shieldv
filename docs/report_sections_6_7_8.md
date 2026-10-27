# ShieldV (Group 8): answers for report sections 6, 7 and 8

## 6. Gantt Chart

The full chart is `docs/gantt_chart.xlsx`, with green cells for Oct 1 to Nov 8. `docs/gantt_chart.png` is a picture of it for the report.

It has 25 activities, and each one has an owner, a type (design, implementation, verification, FPGA debug) and a "done when" test. Key dates:

- **Oct 25:** a core function is implemented and tested on the board. This is the RV32IM 3-stage core running MUL/DIV C programs on the Nexys A7 (activities 14–15).
- **Nov 1:** the minimum system (commitment) is met. ShieldV with the lock bit and trap catches the attack on the board, and the ILA capture is checked (activities 16–17).
- **Parallel work:** all five members build their own blocks against frozen interfaces from Oct 5. Integration then goes one rung at a time (I1–I4). Goal items (predictors, out-of-order core) run alongside, never in front of, the commitment items.

## 7. Risks & Challenges

- Shadow-stack corruption from flushed or stalled instructions pushing/popping twice. Commit control lets only instructions that really finish change it.
- Multi-cycle MUL/DIV stalls (up to 34 cycles) interacting with flush and trap in the same cycle.
- Signed vs unsigned DIV/REM edge cases (divide by 0, INT_MIN / −1) and MULH/MULHSU sign handling.
- FPGA timing and sim-vs-board mismatch. The out-of-order build meets 50 MHz with only +0.159 ns slack, and BRAM init/reset can differ on the board.
- False alarms from deep recursion past the 32-entry shadow stack or from non-matching returns (e.g. longjmp).

## 8. Response to TA feedback (Group 8)

**1. "Title says 5 Stage pipelined but the description says 3 Stage pipeline."**
That was our mistake in the title. The committed design is a **3-stage** pipeline: IF/ID, EX, MEM/WB, and the title is corrected to say 3-stage. The README and build plan also say 3-stage. The RTL is `core_pipe.v`, and it has two pipeline registers: `pipe_ifid_ex.v` and `pipe_ex_wb.v`.

**2. "Implementing only basic features like MUL and DIV would likely receive a low score; consider expanding the hardware."**
We expanded the hardware in both the minimum system and the goals.

- **Commitment (minimum system):**
  - RV32IM 3-stage core with a multi-cycle M-unit (DSP multiplier, restoring divider).
  - The **ShieldV** security unit, which is new hardware. It has:
    - a 32-entry hardware shadow stack;
    - call/return detection;
    - a return-address compare;
    - a violation FSM with freeze/trap modes;
    - fault registers;
    - a **lock bit** so software cannot switch protection off.
  - The full SoC on the Nexys A7: bus decoder, UART, LEDs, switches, 7-segment display and performance counters.
- **Goal:** a second, interchangeable **out-of-order (Tomasulo) core**, protected by the same ShieldV at commit. It has:
  - a rename table;
  - a 16-entry ROB;
  - reservation stations;
  - an 8-entry load/store queue;
  - a CDB arbiter;
  - a tournament branch predictor, BTB and return-address stack;
  - landing-pad checks for indirect jumps.
- **Stretch:** the out-of-order core on the board, plus formal proofs of the shadow-stack properties.

**Status on Oct 11:** about 55 Verilog modules exist and pass in simulation.

- **Tests:** 37 unit testbenches pass. On both cores, 48/48 riscv-tests pass and 20/20 random programs match a golden model.
- **Vivado (laptop build, nothing on the board yet):** both builds meet 50 MHz. The in-order SoC uses 2,110 LUTs (3.3 %) and the out-of-order one 9,806 LUTs (15.5 %). ShieldV itself is 198 LUTs.

**Repository access:** the TA still needs to be added as a collaborator on the GitHub repo. We have to do that ourselves under the repo's Settings → Collaborators.
