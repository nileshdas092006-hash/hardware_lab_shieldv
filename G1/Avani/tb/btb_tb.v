// btb_tb.v - branch target buffer (block A19)
// Owner: Avani (G1)
`timescale 1ns/1ps
module btb_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, upd_en = 0;
    reg  [31:0] pc = 0, upd_pc = 0, upd_target = 0;
    wire        hit;
    wire [31:0] target;
    integer errors = 0;

    btb #(.IDX_W(4)) dut (.clk(clk), .rst_n(rst_n), .pc(pc), .hit(hit), .target(target),
        .upd_en(upd_en), .upd_pc(upd_pc), .upd_target(upd_target));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask
    task learn(input [31:0] p, input [31:0] t);
        begin upd_pc = p; upd_target = t; upd_en = 1; @(negedge clk); upd_en = 0; end
    endtask

    initial begin
        @(negedge clk); @(negedge clk); rst_n = 1;
        pc = 32'h0000_0120; #1 expect(!hit, "empty after reset");
        learn(32'h0000_0120, 32'h0000_0400);
        pc = 32'h0000_0120; #1 expect(hit && target == 32'h400, "hit with the learned target");
        pc = 32'h0000_0124; #1 expect(!hit, "0x124 uses another entry: miss");
        pc = 32'h0000_1120; #1 expect(!hit, "0x1120: same entry as 0x120, different tag: miss");
        learn(32'h0000_1120, 32'h0000_0800);
        pc = 32'h0000_1120; #1 expect(hit && target == 32'h800, "new owner of the entry");
        pc = 32'h0000_0120; #1 expect(!hit, "old owner evicted (direct-mapped)");
        learn(32'h0000_1120, 32'h0000_0900);
        pc = 32'h0000_1120; #1 expect(hit && target == 32'h900, "target updated");
        rst_n = 0; @(negedge clk); rst_n = 1;
        pc = 32'h0000_1120; #1 expect(!hit, "reset clears");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
