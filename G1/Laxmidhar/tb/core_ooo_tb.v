// core_ooo_tb.v - the out-of-order core running the directed hazard program
// Owner: Laxmidhar (G1)
//
// run_tests.py builds tb/asm/hazards.S (the same program core_pipe_tb runs)
// and compiles this testbench with SHIELDV_OOO defined, so soc_top contains
// core_ooo instead of core_pipe (real M-unit, ShieldV on).
// Besides the program's own self-checks (exit code 0) it counts evidence that
// the core really works out of order:
//   ooo_issue : an ALU instruction executed while an OLDER instruction (the
//               reorder-buffer head) was still unfinished
//   flushes   : mispredicted branches repaired at commit
//   max_rob   : most reorder-buffer entries in use at once
`timescale 1ns/1ps
module core_ooo_tb;
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
    integer cycles = 0, ooo_issue = 0, flushes = 0, retired = 0, max_rob = 0;

    initial begin
`ifndef SHIELDV_OOO
        $display("TEST FAILED: compile with SHIELDV_OOO defined (run_tests.py does this)");
        $finish;
`endif
        if (!$value$plusargs("imem=%s", f)) begin $display("TEST FAILED: no +imem"); $finish; end
        $readmemh(f, dut.u_core.u_imem.mem);
        if ($value$plusargs("dmem=%s", f)) $readmemh(f, dut.u_dmem.mem);
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

`ifdef SHIELDV_OOO
    always @(posedge clk) if (rst_n) begin
        cycles <= cycles + 1;
        if (dut.u_core.alu_go && dut.u_core.rob_head_valid && !dut.u_core.rob_head_done &&
            dut.u_core.x_tag != dut.u_core.rob_head_tag)
            ooo_issue <= ooo_issue + 1;
        if (dut.u_core.mispredict_flush) flushes <= flushes + 1;
        if (dut.u_core.commit)           retired <= retired + 1;
        if (dut.u_core.u_rob.count > max_rob) max_rob <= dut.u_core.u_rob.count;
        if (dut.u_core.bus_we && dut.u_core.bus_addr == 32'h1000_00FC) begin
            $display("cycles=%0d retired=%0d out-of-order-issues=%0d mispredict-flushes=%0d max-ROB=%0d",
                     cycles, retired, ooo_issue, flushes, max_rob);
            if (dut.u_core.bus_wdata == 0 && ooo_issue > 10 && flushes > 0 && max_rob > 4)
                $display("TEST PASSED (all hazard checks in hazards.S passed, out of order)");
            else
                $display("TEST FAILED: hazards.S reported %0d failures", dut.u_core.bus_wdata);
            $finish;
        end
        if (cycles > 100000) begin $display("TEST FAILED: timeout pc=%h", tr_if_pc); $finish; end
    end
`endif
endmodule
