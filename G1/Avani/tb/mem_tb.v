// mem_tb.v - testbench for imem.v and dmem.v (blocks A2, A15)
// Owner: Avani (G1)
//
// imem: fill through the same array $readmemh uses, then check the
//       one-cycle read latency.
// dmem: byte-write patterns and read-after-write.
`timescale 1ns/1ps
module mem_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    integer errors = 0, i;

    // ---------------- imem ----------------
    reg  [31:0] iaddr = 0;
    wire [31:0] idata;
    imem #(.INIT_FILE("")) u_imem (.clk(clk), .addr(iaddr), .rdata(idata));

    // ---------------- dmem ----------------
    reg         en = 0;
    reg  [3:0]  wstrb = 0;
    reg  [31:0] daddr = 0, wdata = 0;
    wire [31:0] rdata;
    dmem #(.INIT_FILE("")) u_dmem (.clk(clk), .en(en), .wstrb(wstrb), .addr(daddr), .wdata(wdata), .rdata(rdata));

    task check(input [31:0] got, input [31:0] want, input [127:0] what);
        if (got !== want) begin errors = errors + 1; $display("FAIL %0s: got %h expected %h", what, got, want); end
    endtask

    initial begin
        // imem: empty memory reads as nop, then load a pattern
        for (i = 0; i < 16; i = i + 1) u_imem.mem[i] = 32'h1000_0000 + i;
        @(negedge clk); iaddr = 32'h0000_0008;
        @(negedge clk); check(idata, 32'h1000_0002, "imem word 2 after one clock");
        iaddr = 32'h0000_000C; #1;
        check(idata, 32'h1000_0002, "imem output only changes on the clock edge");
        @(negedge clk); check(idata, 32'h1000_0003, "imem word 3");
        iaddr = 32'h0000_3FFC;
        @(negedge clk); check(idata, 32'h0000_0013, "unwritten imem holds nop");

        // dmem: full word write then read
        @(negedge clk); en = 1; wstrb = 4'b1111; daddr = 32'h0001_0010; wdata = 32'hAABB_CCDD;
        @(negedge clk); wstrb = 4'b0000;                 // read
        @(negedge clk); check(rdata, 32'hAABB_CCDD, "dmem word");
        // byte write into lane 2 only
        wstrb = 4'b0100; wdata = 32'h0011_0000;
        @(negedge clk); wstrb = 4'b0000;
        @(negedge clk); check(rdata, 32'hAA11_CCDD, "dmem byte lane 2");
        // half-word write into the upper half
        wstrb = 4'b1100; wdata = 32'h1234_0000;
        @(negedge clk); wstrb = 4'b0000;
        @(negedge clk); check(rdata, 32'h1234_CCDD, "dmem upper half");
        // en = 0: no write, output holds
        en = 0; wstrb = 4'b1111; wdata = 32'hFFFF_FFFF;
        @(negedge clk); en = 1; wstrb = 4'b0000;
        @(negedge clk); check(rdata, 32'h1234_CCDD, "dmem ignores writes when en = 0");
        // top of the stack area
        wstrb = 4'b1111; daddr = 32'h0001_3FFC; wdata = 32'h0000_0104;
        @(negedge clk); wstrb = 4'b0000;
        @(negedge clk); check(rdata, 32'h0000_0104, "dmem top word (saved ra)");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
