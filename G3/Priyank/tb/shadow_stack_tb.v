// shadow_stack_tb.v - push/pop, full, empty, swap (blocks C2 + C3)
// Owner: Priyank (G3)
`timescale 1ns/1ps
module shadow_stack_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, push = 0, pop = 0;
    reg  [31:0] data = 0;
    wire [31:0] top;
    wire        empty, full;
    wire [5:0]  depth;
    integer errors = 0, i;

    shadow_stack dut (.clk(clk), .rst_n(rst_n), .push(push), .pop(pop), .push_data(data),
                      .top(top), .empty(empty), .full(full), .depth(depth));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s (depth=%0d top=%h)", what, depth, top); end
    endtask

    task op(input pu, input po, input [31:0] d);
        begin push = pu; pop = po; data = d; @(negedge clk); push = 0; pop = 0; end
    endtask

    initial begin
        @(negedge clk); rst_n = 1;
        expect(empty && !full && depth == 0, "empty after reset");
        // nested calls: push 1..32 (return addresses 0x1000 + 4i)
        for (i = 0; i < 32; i = i + 1) begin
            op(1, 0, 32'h1000 + 4 * i);
            expect(top == 32'h1000 + 4 * i, "top is the latest push");
        end
        expect(full && depth == 32, "full after 32 pushes");
        op(1, 0, 32'hDEAD);                         // 33rd push is dropped
        expect(depth == 32 && top == 32'h107C, "push when full is ignored");
        // returns: pop in reverse order
        for (i = 31; i >= 0; i = i - 1) begin
            expect(top == 32'h1000 + 4 * i, "pop order is last-in first-out");
            op(0, 1, 0);
        end
        expect(empty, "empty after 32 pops");
        op(0, 1, 0);
        expect(empty && depth == 0, "pop when empty is ignored");
        // coroutine swap: push and pop together replaces the top
        op(1, 0, 32'hAAAA); op(1, 0, 32'hBBBB);
        op(1, 1, 32'hCCCC);
        expect(depth == 2 && top == 32'hCCCC, "swap replaces the top");
        op(0, 1, 0);
        expect(top == 32'hAAAA, "entry below the swap untouched");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
