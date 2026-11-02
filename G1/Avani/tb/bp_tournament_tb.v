// bp_tournament_tb.v - gshare + bimodal + chooser on branch patterns (blocks A17, A18)
// Owner: Avani (G1)
//
// Plays the role of the core: each round predicts one branch (fetch, which
// shifts the speculative history), then trains it with the real outcome
// (commit), restoring the history when the guess was wrong.
//   pattern A: T T T N repeating (a loop that runs 4 times). Bimodal can be
//              right at most 3 of 4 times; gshare learns it from history.
//   pattern B: always taken. Both tables learn it.
// Pass: the tournament is >= 95 % right on A after warm-up (and beats the
// bimodal table alone) and 100 % on B.
`timescale 1ns/1ps
module bp_tournament_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, spec_shift = 0, spec_taken = 0, upd_en = 0, upd_taken = 0, restore = 0;
    reg  [31:0] pred_pc = 0, upd_pc = 0;
    reg  [7:0]  upd_hist = 0;
    wire        pred_taken;
    wire [7:0]  pred_hist;
    integer errors = 0, n, right, bim_right;
    reg guess, actual, bim_guess;
    reg [7:0] h;

    bp_tournament #(.HIST_W(8)) dut (.clk(clk), .rst_n(rst_n),
        .pred_pc(pred_pc), .pred_taken(pred_taken), .pred_hist(pred_hist),
        .spec_shift(spec_shift), .spec_taken(spec_taken),
        .upd_en(upd_en), .upd_pc(upd_pc), .upd_hist(upd_hist), .upd_taken(upd_taken),
        .restore(restore));

    // one fetch + commit of the branch at pc with the given real outcome
    task round(input [31:0] pc, input real_taken);
        begin
            pred_pc = pc; #1;
            guess = pred_taken; h = pred_hist; bim_guess = dut.b_taken;
            spec_shift = 1; spec_taken = guess; @(negedge clk); spec_shift = 0;
            upd_pc = pc; upd_hist = h; upd_taken = real_taken; upd_en = 1;
            restore = (guess != real_taken);
            @(negedge clk); upd_en = 0; restore = 0;
        end
    endtask

    initial begin
        @(negedge clk); @(negedge clk); rst_n = 1;

        // pattern A: T T T N
        right = 0; bim_right = 0;
        for (n = 0; n < 400; n = n + 1) begin
            actual = (n % 4) != 3;
            round(32'h0000_0240, actual);
            if (n >= 200) begin
                right = right + (guess == actual);
                bim_right = bim_right + (bim_guess == actual);
            end
        end
        $display("pattern TTTN: tournament %0d/200, bimodal alone %0d/200", right, bim_right);
        if (right < 190)       begin errors = errors + 1; $display("FAIL tournament below 95%% on TTTN"); end
        if (right <= bim_right) begin errors = errors + 1; $display("FAIL chooser did not pick the better table"); end

        // pattern B: always taken (a different branch)
        right = 0;
        for (n = 0; n < 100; n = n + 1) begin
            round(32'h0000_0380, 1'b1);
            if (n >= 50) right = right + guess;
        end
        $display("pattern always-taken: %0d/50", right);
        if (right != 50) begin errors = errors + 1; $display("FAIL always-taken branch not learned"); end

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
