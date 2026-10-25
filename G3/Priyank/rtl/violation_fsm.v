// violation_fsm.v - what ShieldV does when it catches an attack (block C6)
// Owner: Priyank (G3)
//
// States:
//   NORMAL : checking every return
//   ALARM  : a violation was caught in freeze mode; the CPU stays frozen
//            until reset (red LED on, fault PC on the 7-segment display)
//
// What happens on a violation depends on the mode (from shield_ctrl.v):
//   protection off  : nothing (the attack succeeds; it is still counted)
//   count-only      : nothing but counting (used to diagnose false alarms)
//   freeze (default): raise freeze in the SAME cycle, so the PC never takes
//                     the attacker's address; go to ALARM
//   trap (goal)     : redirect to the security handler instead of the target
//
// freeze is combinational from the violation, which is what guarantees zero
// attacker instructions execute.
module violation_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire violation,     // any check failed this cycle (already gated by ex_valid)
    input  wire enabled,       // protection on
    input  wire count_only,
    input  wire trap_mode,
    output wire freeze,
    output wire trap,
    output wire alarm,         // state == ALARM
    output wire capture        // latch the fault registers this cycle
);
    localparam NORMAL = 1'b0;
    localparam ALARM  = 1'b1;

    reg state;

    wire act = violation & enabled & ~count_only;    // a violation we must act on

    assign freeze  = (state == ALARM) | (act & ~trap_mode);
    assign trap    = (state == NORMAL) & act & trap_mode;
    assign alarm   = (state == ALARM);
    assign capture = (state == NORMAL) & violation;

    always @(posedge clk) begin
        if (!rst_n)                   state <= NORMAL;
        else if (act && !trap_mode)   state <= ALARM;
    end
endmodule
