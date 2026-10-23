// pc_reg_tb.v - testbench for pc_reg.v (block A1)
// Owner: Avani (G1)
`timescale 1ns/1ps
module pc_reg_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, hold = 0, trap = 0, redirect = 0;
    reg  [31:0] trap_pc = 32'h0000_0800, target = 32'h0000_0400;
    wire [31:0] pc, pc_next;
    integer errors = 0;

    pc_reg dut (.clk(clk), .rst_n(rst_n), .hold(hold), .trap(trap), .trap_pc(trap_pc),
                .redirect(redirect), .target(target), .pc(pc), .pc_next(pc_next));

    task expect_pc(input [31:0] want, input [127:0] what);
        if (pc !== want) begin errors = errors + 1; $display("FAIL %0s: pc=%h expected %h", what, pc, want); end
    endtask

    initial begin
        @(negedge clk); @(negedge clk);
        expect_pc(32'h0, "reset value");
        rst_n = 1;
        @(negedge clk); expect_pc(32'h4, "pc+4");
        @(negedge clk); expect_pc(32'h8, "pc+4 again");
        hold = 1;
        @(negedge clk); expect_pc(32'h8, "hold");
        redirect = 1; trap = 1;                 // hold beats everything
        @(negedge clk); expect_pc(32'h8, "hold beats trap and redirect");
        hold = 0;
        @(negedge clk); expect_pc(32'h800, "trap beats redirect");
        trap = 0;
        @(negedge clk); expect_pc(32'h400, "redirect");
        redirect = 0;
        @(negedge clk); expect_pc(32'h404, "sequential after redirect");
        rst_n = 0;
        @(negedge clk); expect_pc(32'h0, "synchronous reset");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
