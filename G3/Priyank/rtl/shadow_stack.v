// shadow_stack.v - shadow stack RAM with pointer, full and empty (blocks C2 + C3)
// Owner: Priyank (G3)
//
// A small stack of return addresses kept in FPGA logic (LUTRAM), completely
// separate from data memory. Nothing on the data bus is connected to it, so
// no load or store, including an attacker's overflowing store, can change it.
// That physical separation is the whole security argument.
//
//   push         : write push_data on top, pointer + 1
//   pop          : remove the top, pointer - 1
//   push and pop : (coroutine swap) replace the top, pointer unchanged
//
// top is read asynchronously (LUTRAM), so the comparison can happen in the
// same cycle as the return: zero extra cycles.
//
// sp counts entries: 0 = empty, DEPTH = full. A push when full is dropped
// (ShieldV reports it as an overflow); a pop when empty is ignored (underflow).
module shadow_stack #(
    parameter DEPTH = 32,
    parameter PTR_W = 6               // enough bits to hold the value DEPTH
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             push,
    input  wire             pop,
    input  wire [31:0]      push_data,
    output wire [31:0]      top,
    output wire             empty,
    output wire             full,
    output wire [PTR_W-1:0] depth
);
    (* ram_style = "distributed" *) reg [31:0] mem [0:DEPTH-1];
    reg [PTR_W-1:0] sp;

    integer i;
    initial for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'd0;

    assign empty = (sp == {PTR_W{1'b0}});
    assign full  = (sp == DEPTH);
    assign depth = sp;
    assign top   = empty ? 32'd0 : mem[sp - 1'b1];

    wire do_swap = push & pop & ~empty;          // replace the top
    wire do_push = push & ~pop & ~full;
    wire do_pop  = pop & ~push & ~empty;
    wire pop_then_push_empty = push & pop & empty; // nothing to pop: behaves as a push

    always @(posedge clk) begin
        if (do_swap)
            mem[sp - 1'b1] <= push_data;
        else if (do_push || pop_then_push_empty)
            mem[sp] <= push_data;
    end

    always @(posedge clk) begin
        if (!rst_n)                   sp <= {PTR_W{1'b0}};
        else if (do_push)             sp <= sp + 1'b1;
        else if (pop_then_push_empty) sp <= sp + 1'b1;
        else if (do_pop)              sp <= sp - 1'b1;
    end
endmodule
