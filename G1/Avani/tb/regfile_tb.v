// regfile_tb.v - self-checking testbench for regfile.v (block A5)
// Owner: Avani (G1)
`timescale 1ns/1ps
module regfile_tb;
    reg clk = 0;
    always #5 clk = ~clk;

    reg  [4:0]  ra1, ra2, wa;
    reg         we;
    reg  [31:0] wd;
    wire [31:0] rd1, rd2;
    integer errors = 0, i;

    regfile dut (.clk(clk), .ra1(ra1), .ra2(ra2), .rd1(rd1), .rd2(rd2), .we(we), .wa(wa), .wd(wd));

    task expect(input [31:0] got, input [31:0] want, input [255:0] what);
        if (got !== want) begin
            errors = errors + 1;
            $display("FAIL %0s: got %h expected %h", what, got, want);
        end
    endtask

    initial begin
        we = 0; wa = 0; wd = 0; ra1 = 0; ra2 = 0;
        // write every register with a unique pattern
        for (i = 0; i < 32; i = i + 1) begin
            @(negedge clk); we = 1; wa = i; wd = 32'hA5A5_0000 | i;
        end
        @(negedge clk); we = 0;
        // read them back on both ports
        for (i = 0; i < 32; i = i + 1) begin
            ra1 = i; ra2 = 31 - i; #1;
            expect(rd1, (i == 0) ? 32'd0 : (32'hA5A5_0000 | i), "port 1 readback");
            expect(rd2, (i == 31) ? 32'd0 : (32'hA5A5_0000 | (31 - i)), "port 2 readback");
        end
        // x0 can never change
        @(negedge clk); we = 1; wa = 0; wd = 32'hDEAD_BEEF; ra1 = 0; #1;
        expect(rd1, 32'd0, "x0 during write");
        @(negedge clk); we = 0; #1;
        expect(rd1, 32'd0, "x0 after write");
        // write-through: reading the register being written gives the new value
        @(negedge clk); we = 1; wa = 5'd7; wd = 32'h1234_5678; ra1 = 5'd7; ra2 = 5'd8; #1;
        expect(rd1, 32'h1234_5678, "write-through same cycle");
        expect(rd2, 32'hA5A5_0008, "other port unaffected");
        @(negedge clk); we = 0; #1;
        expect(rd1, 32'h1234_5678, "value stored");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
