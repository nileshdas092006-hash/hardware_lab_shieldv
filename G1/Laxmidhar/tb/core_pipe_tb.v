// core_pipe_tb.v - the pipelined core running the directed hazard program
// Owner: Laxmidhar (G1)
//
// run_tests.py builds tb/asm/hazards.S and passes +imem/+dmem. The core runs
// inside soc_top (real M-unit, ShieldV on). Besides the program's own
// self-checks (exit code 0), this testbench counts how often the pipeline
// stalled and flushed, so you can see the hazard logic actually working.
`timescale 1ns/1ps
module core_pipe_tb;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst_n = 0;

    wire [31:0] tr_if_pc, tr_ex_pc, tr_wb_pc;
    wire        tr_stall, tr_flush, tr_ex_valid, tr_retire;
    soc_top #(.IMEM_INIT(""), .DMEM_INIT(""), .BAUD(5_000_000), .REFRESH_BITS(4)) dut (
        .clk(clk), .rst_n(rst_n), .sw_raw(16'h0001),
        .led(), .seg(), .dp(), .an(), .uart_txd(), .alarm_led(), .ok_led(),
        .tr_if_pc(tr_if_pc), .tr_ex_pc(tr_ex_pc), .tr_wb_pc(tr_wb_pc),
        .tr_stall(tr_stall), .tr_flush(tr_flush), .tr_ex_valid(tr_ex_valid), .tr_retire(tr_retire));

    reg [1023:0] f;
    integer cycles = 0, stalls = 0, flushes = 0, fwds = 0, retired = 0;

    initial begin
        if (!$value$plusargs("imem=%s", f)) begin $display("TEST FAILED: no +imem"); $finish; end
        $readmemh(f, dut.u_core.u_imem.mem);
        if ($value$plusargs("dmem=%s", f)) $readmemh(f, dut.u_dmem.mem);
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

    always @(posedge clk) if (rst_n) begin
        cycles <= cycles + 1;
        if (dut.u_core.stall)      stalls  <= stalls + 1;
        if (dut.u_core.flush_ifid) flushes <= flushes + 1;
        if (dut.u_core.e_valid && (dut.u_core.fwd_a || dut.u_core.fwd_b)) fwds <= fwds + 1;
        if (dut.u_core.w_valid)    retired <= retired + 1;
        if (dut.u_core.bus_we && dut.u_core.bus_addr == 32'h1000_00FC) begin
            $display("cycles=%0d retired=%0d stall-cycles=%0d flushes=%0d forwards=%0d",
                     cycles, retired, stalls, flushes, fwds);
            if (dut.u_core.bus_wdata == 0 && stalls > 30 && flushes > 5 && fwds > 10)
                $display("TEST PASSED (all hazard checks in hazards.S passed)");
            else
                $display("TEST FAILED: hazards.S reported %0d failures", dut.u_core.bus_wdata);
            $finish;
        end
        if (cycles > 100000) begin $display("TEST FAILED: timeout pc=%h", tr_if_pc); $finish; end
    end
endmodule
