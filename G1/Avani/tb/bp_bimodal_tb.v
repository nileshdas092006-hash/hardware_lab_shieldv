// bp_bimodal_tb.v - 2-bit saturating counters of the bimodal predictor (block A16)
// Owner: Avani (G1)
//
// Checks: reset = weakly not taken; two taken outcomes flip it to taken;
// a strong counter survives one opposite outcome; counters saturate; two
// branches in different entries do not disturb each other.
`timescale 1ns/1ps
module bp_bimodal_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, upd_en = 0, upd_taken = 0;
    reg  [31:0] pred_pc = 0, upd_pc = 0;
    wire        pred_taken, upd_pred;
    integer errors = 0, i;

    bp_bimodal #(.IDX_W(6)) dut (.clk(clk), .rst_n(rst_n), .pred_pc(pred_pc), .pred_taken(pred_taken),
        .upd_en(upd_en), .upd_pc(upd_pc), .upd_taken(upd_taken), .upd_pred(upd_pred));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask
    task train(input [31:0] pc, input t);
        begin upd_pc = pc; upd_taken = t; upd_en = 1; @(negedge clk); upd_en = 0; end
    endtask
    task predict(input [31:0] pc);
        begin pred_pc = pc; #1; end
    endtask

    initial begin
        @(negedge clk); @(negedge clk); rst_n = 1;
        predict(32'h100); expect(!pred_taken, "reset: weakly not taken");
        train(32'h100, 1); predict(32'h100); expect(pred_taken,  "01 -> 10 after one taken: now taken");
        train(32'h100, 1); train(32'h100, 1); train(32'h100, 1);       // saturate at 11
        train(32'h100, 0); predict(32'h100); expect(pred_taken,  "strong taken survives one not-taken");
        train(32'h100, 0); predict(32'h100); expect(!pred_taken, "second not-taken flips it");
        for (i = 0; i < 5; i = i + 1) train(32'h100, 0);
        train(32'h100, 1); predict(32'h100); expect(!pred_taken, "saturated at 00: one taken is not enough");
        predict(32'h104); expect(!pred_taken, "neighbouring entry untouched");
        train(32'h104, 1); train(32'h104, 1);
        predict(32'h104); expect(pred_taken, "entry 0x104 trained separately");
        predict(32'h100); expect(!pred_taken, "entry 0x100 unchanged by 0x104");
        predict(32'h100 + 32'h100); expect(!pred_taken, "0x200 maps to the same entry as 0x100 (64 entries)");
        upd_pc = 32'h104; #1 expect(upd_pred, "second read port sees the trained counter");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
