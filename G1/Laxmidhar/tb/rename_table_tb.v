// rename_table_tb.v - register alias table (block A21)
// Owner: Laxmidhar (G1)
`timescale 1ns/1ps
module rename_table_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg        rst_n = 0, flush = 0, d_we = 0, c_en = 0;
    reg  [4:0] ra1 = 0, ra2 = 0, d_rd = 0, c_rd = 0;
    reg  [3:0] d_tag = 0, c_tag = 0;
    wire       busy1, busy2;
    wire [3:0] tag1, tag2;
    integer errors = 0;

    rename_table #(.TAG_W(4)) dut (.clk(clk), .rst_n(rst_n), .flush(flush),
        .ra1(ra1), .ra2(ra2), .busy1(busy1), .tag1(tag1), .busy2(busy2), .tag2(tag2),
        .d_we(d_we), .d_rd(d_rd), .d_tag(d_tag), .c_en(c_en), .c_rd(c_rd), .c_tag(c_tag));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask
    task claim(input [4:0] r, input [3:0] t);
        begin d_we = 1; d_rd = r; d_tag = t; @(negedge clk); d_we = 0; end
    endtask
    task retire(input [4:0] r, input [3:0] t);
        begin c_en = 1; c_rd = r; c_tag = t; @(negedge clk); c_en = 0; end
    endtask

    initial begin
        @(negedge clk); @(negedge clk); rst_n = 1;
        ra1 = 5; #1 expect(!busy1, "reset: x5 comes from the register file");

        claim(5, 4'd3);
        ra1 = 5; #1 expect(busy1 && tag1 == 3, "x5 now comes from ROB entry 3");
        claim(5, 4'd7);                                   // a younger writer of x5
        #1 expect(busy1 && tag1 == 7, "younger writer renames x5 again (no WAW stall)");
        retire(5, 4'd3);
        #1 expect(busy1 && tag1 == 7, "old writer commits: x5 still waits for entry 7");
        retire(5, 4'd7);
        #1 expect(!busy1, "newest writer commits: x5 back in the register file");

        // dispatch and commit of the same register in one cycle
        claim(6, 4'd1);
        d_we = 1; d_rd = 6; d_tag = 4'd2; c_en = 1; c_rd = 6; c_tag = 4'd1;
        @(negedge clk); d_we = 0; c_en = 0;
        ra2 = 6; #1 expect(busy2 && tag2 == 2, "dispatch wins over commit in the same cycle");

        // x0 is never renamed
        claim(0, 4'd9);
        ra1 = 0; #1 expect(!busy1, "x0 is never busy");

        // flush
        claim(10, 4'd4); claim(11, 4'd5);
        flush = 1; @(negedge clk); flush = 0;
        ra1 = 10; ra2 = 11; #1 expect(!busy1 && !busy2, "flush: everything from the register file");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
