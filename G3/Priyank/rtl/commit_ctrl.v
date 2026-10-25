// commit_ctrl.v - only real instructions may touch the shadow stack (block C4)
// Owner: Priyank (G3)
//
// In a pipeline, some instructions are fetched and then thrown away (flushed)
// because a branch ahead of them was taken. If a flushed call pushed onto the
// shadow stack, the stack would go out of step with the program and the next
// return would raise a false alarm.
//
// The core marks every real, committing EX instruction with ex_valid
// (flushed instructions arrive as bubbles with valid = 0, and an instruction
// waiting for the M-unit is held back). Here we additionally refuse to change
// the stack in a cycle where ShieldV itself is freezing or trapping, so the
// stack is preserved exactly as it was at the moment of the attack.
module commit_ctrl (
    input  wire ex_valid,
    input  wire is_call,
    input  wire is_ret,
    input  wire block,          // freeze or trap happening this cycle
    output wire do_push,
    output wire do_pop
);
    assign do_push = ex_valid & is_call & ~block;
    assign do_pop  = ex_valid & is_ret  & ~block;
endmodule
