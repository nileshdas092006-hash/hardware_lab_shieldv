// core_single_tb.v - runs a compiled C program on the single-cycle core
// Owner: Avani (G1)
//
// run_tests.py builds the program (default: fib) and passes
//   +imem=<file> +dmem=<file>
// The program prints over the UART register and ends by writing its result
// to 0x1000_00FC; 0 means every check in the program passed.
`timescale 1ns/1ps
module core_single_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;

    wire [31:0] pc, io_addr, io_wdata;
    wire        io_we;
    core_single #(.IMEM_INIT(""), .DMEM_INIT("")) dut (
        .clk(clk), .rst_n(rst_n), .pc_out(pc), .io_we(io_we), .io_addr(io_addr), .io_wdata(io_wdata));

    reg [1023:0] f;
    integer cycles = 0;

    initial begin
        if (!$value$plusargs("imem=%s", f)) begin $display("TEST FAILED: no +imem"); $finish; end
        $readmemh(f, dut.imem);
        if ($value$plusargs("dmem=%s", f)) $readmemh(f, dut.dmem);
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

    always @(posedge clk) if (rst_n) begin
        cycles <= cycles + 1;
        if (io_we && io_addr == 32'h1000_0010) $write("%c", io_wdata[7:0]);
        if (io_we && io_addr == 32'h1000_00FC) begin
            $display("");
            if (io_wdata == 0) $display("TEST PASSED (program exit 0 after %0d instructions)", cycles);
            else               $display("TEST FAILED: program exit %0d", io_wdata);
            $finish;
        end
        if (cycles > 2_000_000) begin $display("TEST FAILED: timeout, pc=%h", pc); $finish; end
    end
endmodule
