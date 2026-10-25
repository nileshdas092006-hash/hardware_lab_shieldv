// ret_compare.v - the return check itself (block C5)
// Owner: Priyank (G3)
//
// A return is legitimate only if it goes back to the address that the
// matching call saved. We have two copies of that address:
//   actual   : where the jalr wants to go (computed from ra, which lives on the
//              normal stack and may have been overwritten)
//   expected : the top of the shadow stack (cannot be overwritten)
// Different => the return address was tampered with.
//
// Also flags the two stack-shape errors:
//   underflow : a return with nothing on the shadow stack
//   overflow  : a call when the shadow stack is already full (recursion > 32)
//
// Purely combinational: the answer is ready in the same cycle, so the check
// costs zero clock cycles.
module ret_compare (
    input  wire        is_ret,
    input  wire        is_call,
    input  wire [31:0] actual,
    input  wire [31:0] expected,
    input  wire        empty,
    input  wire        full,
    output wire        mismatch,
    output wire        underflow,
    output wire        overflow
);
    assign underflow = is_ret & empty;
    assign mismatch  = is_ret & ~empty & (actual != expected);
    assign overflow  = is_call & ~is_ret & full;
endmodule
