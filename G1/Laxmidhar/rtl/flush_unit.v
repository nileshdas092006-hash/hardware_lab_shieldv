// flush_unit.v - flush logic (block A11)
// Owner: Laxmidhar (G1)
//
// Branches and jumps are decided in EX. By then the IF/ID stage has already
// fetched the next sequential instruction (pc+4), which is wrong if the
// branch was taken. That instruction must be thrown away ("flushed"): it
// enters EX as a bubble (valid = 0).
//
//   ex_redirect : a taken branch / jal / jalr is leaving EX this cycle
//   sh_trap     : ShieldV redirects to the security handler (goal tier)
//
//   flush_ifid  : turn the IF/ID instruction into a bubble
//   kill_ex     : the EX instruction itself must not complete (trap only:
//                 the bad return is not allowed to finish)
//
// A flushed call never reaches EX as a valid instruction, so it can never
// push onto the shadow stack. That is why ShieldV trusts ex_valid.
module flush_unit (
    input  wire ex_redirect,
    input  wire sh_trap,
    output wire flush_ifid,
    output wire kill_ex
);
    assign flush_ifid = ex_redirect | sh_trap;
    assign kill_ex    = sh_trap;
endmodule
