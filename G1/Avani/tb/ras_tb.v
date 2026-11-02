// ras_tb.v - return-address stack with speculative and committed copies (block A20)
// Owner: Avani (G1)
`timescale 1ns/1ps
module ras_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, push = 0, pop = 0, c_push = 0, c_pop = 0, restore = 0;
    reg  [31:0] push_addr = 0, c_push_addr = 0;
    wire [31:0] top;
    wire        empty;
    integer errors = 0, i;

    ras #(.DEPTH(8), .PTR_W(3)) dut (.clk(clk), .rst_n(rst_n),
        .push(push), .pop(pop), .push_addr(push_addr), .top(top), .empty(empty),
        .c_push(c_push), .c_pop(c_pop), .c_push_addr(c_push_addr), .restore(restore));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask
    task s_push(input [31:0] a); begin push = 1; push_addr = a; @(negedge clk); push = 0; end endtask
    task s_pop;                  begin pop = 1; @(negedge clk); pop = 0; end endtask
    task k_push(input [31:0] a); begin c_push = 1; c_push_addr = a; @(negedge clk); c_push = 0; end endtask

    initial begin
        @(negedge clk); @(negedge clk); rst_n = 1;
        expect(empty, "empty after reset");

        // calls predicted at fetch
        s_push(32'h104); s_push(32'h208); s_push(32'h30C);
        expect(!empty && top == 32'h30C, "top is the newest call");
        s_pop; expect(top == 32'h208, "pop returns to the previous one");

        // replace (coroutine swap)
        push = 1; pop = 1; push_addr = 32'h444; @(negedge clk); push = 0; pop = 0;
        expect(top == 32'h444, "push+pop replaces the top");

        // flush: only committed calls survive
        k_push(32'h104);                       // only the first call committed
        restore = 1; @(negedge clk); restore = 0;
        expect(top == 32'h104 && !empty, "restore: speculative entries dropped");
        s_pop; expect(empty, "and that one popped leaves it empty");

        // restore in the same cycle as a commit includes that commit
        c_push = 1; c_push_addr = 32'h500; restore = 1; @(negedge clk); c_push = 0; restore = 0;
        expect(top == 32'h500, "restore sees the same-cycle commit");

        // overflow: 10 nested calls in an 8-entry stack keep the newest 8
        rst_n = 0; @(negedge clk); rst_n = 1;
        for (i = 0; i < 10; i = i + 1) s_push(32'h1000 + 4 * i);
        for (i = 9; i >= 2; i = i - 1) begin
            expect(top == 32'h1000 + 4 * i, "overflow keeps the newest 8");
            s_pop;
        end
        expect(empty, "count saturated at 8");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
