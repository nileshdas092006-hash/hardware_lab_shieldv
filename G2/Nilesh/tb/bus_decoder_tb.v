// bus_decoder_tb.v - every address range selects exactly one target (block B4)
// Owner: Nilesh (G2)
`timescale 1ns/1ps
module bus_decoder_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, we = 0, re = 0;
    reg  [31:0] addr = 0, wdata = 0;
    reg  [3:0]  wstrb = 0;
    wire [31:0] rdata, io_wdata;
    wire        dmem_en, io_we;
    wire [3:0]  dmem_wstrb;
    wire [7:0]  io_addr;
    integer errors = 0;

    // fake devices: data RAM answers addr+1 next cycle, I/O answers {io_addr} immediately
    reg [31:0] dmem_q;
    always @(posedge clk) if (dmem_en) dmem_q <= addr + 1;
    wire [31:0] io_rdata = {24'hAB0000, io_addr};

    bus_decoder dut (.clk(clk), .rst_n(rst_n), .addr(addr), .wdata(wdata), .wstrb(wstrb),
        .we(we), .re(re), .rdata(rdata), .dmem_en(dmem_en), .dmem_wstrb(dmem_wstrb),
        .dmem_rdata(dmem_q), .io_we(io_we), .io_addr(io_addr), .io_wdata(io_wdata), .io_rdata(io_rdata));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s (addr=%h rdata=%h)", what, addr, rdata); end
    endtask

    task write(input [31:0] a);
        begin addr = a; we = 1; re = 0; wstrb = 4'hF; #1; end
    endtask

    initial begin
        repeat (2) @(negedge clk); rst_n = 1;
        // writes
        write(32'h0001_0000); expect(dmem_en && dmem_wstrb == 4'hF && !io_we, "store to DMEM base");
        write(32'h0001_3FFC); expect(dmem_en && !io_we, "store to top of stack");
        write(32'h0001_4000); expect(!dmem_en && !io_we, "just above DMEM is unmapped");
        write(32'h0000_0100); expect(!dmem_en && !io_we, "IMEM is not writable");
        write(32'h1000_0000); expect(io_we && !dmem_en && io_addr == 8'h00, "LED register");
        write(32'h1000_0010); expect(io_we && io_addr == 8'h10, "UART_TX");
        write(32'h1000_0100); expect(!io_we, "outside the I/O page");
        // reads arrive the next cycle
        @(negedge clk); we = 0; re = 1; addr = 32'h0001_0040;
        @(negedge clk); re = 0; addr = 32'hFFFF_FFFF; #1;
        expect(rdata == 32'h0001_0041, "DMEM read data next cycle");
        @(negedge clk); re = 1; addr = 32'h1000_0034;
        @(negedge clk); re = 0; #1;
        expect(rdata == 32'hAB00_0034, "I/O read data next cycle");
        @(negedge clk); re = 1; addr = 32'h2000_0000;
        @(negedge clk); re = 0; #1;
        expect(rdata == 32'h0, "unmapped read returns 0");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
