// hazard_unit.v - central stall control (block A10)
// Owner: Laxmidhar (G1)
//
// One place decides when the front of the pipeline must wait. Having a single
// stall source avoids two blocks fighting over the same registers.
//
// Reasons to stall:
//   m_wait    : the instruction in EX is a MUL/DIV and the M-unit has not
//               raised done yet (DIV takes ~33 cycles)
//   sh_freeze : ShieldV caught a corrupted return address. The CPU must stop
//               BEFORE the PC jumps to the attacker's code, and stay stopped.
//
// What a stall does:
//   * PC holds, IF/ID holds, EX holds          (stall = 1)
//   * MEM/WB receives a bubble                 (wb_bubble = 1)
//     so the instruction stuck in EX is not written back twice.
// The instruction already in MEM/WB still finishes normally.
//
// Why no load-use stall? Our data RAM returns load data in MEM/WB, the stage
// right after EX, so forwarding covers "lw then use" with zero penalty.
module hazard_unit (
    input  wire m_wait,
    input  wire sh_freeze,
    output wire stall,
    output wire wb_bubble
);
    assign stall     = m_wait | sh_freeze;
    assign wb_bubble = stall;
endmodule
