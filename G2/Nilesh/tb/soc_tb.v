// soc_tb.v - system testbench: runs a compiled C program on the whole SoC
// Owner: Nilesh (G2), used by everyone through scripts/run_prog.py
//
// Plusargs (set by run_prog.py):
//   +imem=<file> +dmem=<file>   memory images from build_sw.py
//   +sw=<hex>                   slide switch value (bit 0 = protection on)
//   +hacked=<hex>               address of hacked(); the test fails if the
//                               CPU ever executes an instruction there
//   +max_cycles=<n>             give up after n cycles
//   +commitlog=<file>           write a Spike-style commit log
//   +vcd=<file>                 dump a waveform (for timing diagrams)
//   +vcd_from=<n> +vcd_len=<n>  only dump cycles n .. n+len (default 0, 5000)
//   +trigger_pc=<hex>           print "TRIGGER cycle=<n>" the first time EX holds this PC
//   +trigger_waddr=<hex>        print "WTRIGGER cycle=<n> data=<hex>" at every store to this address
//
// Works with both cores (compile with SHIELDV_OOO defined for the
// out-of-order one): it only looks at the core's ports and at the commit-view
// wires cm_* / dbg_ex_* that both cores define. For the out-of-order core
// "EX" means the reorder-buffer head, where ShieldV checks it.
//
// What it prints:
//   * every character the program sends to the UART (snooped from the bus)
//   * "SIM_EXIT code=<n>" when the program writes 0x1000_00FC
//   * "SHIELDV ALARM ..." if ShieldV freezes the CPU
// and ends with "RESULT: ..." which run_prog.py checks.
`timescale 1ns/1ps
module soc_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [15:0] sw_val = 16'h0001;
    always #10 clk = ~clk;                      // 50 MHz

    wire [15:0] led;
    wire [6:0]  seg;
    wire [7:0]  an;
    wire        dp, uart_txd, alarm_led, ok_led;
    wire [31:0] tr_if_pc, tr_ex_pc, tr_wb_pc;
    wire        tr_stall, tr_flush, tr_ex_valid, tr_retire;

    soc_top #(
        .IMEM_INIT(""), .DMEM_INIT(""),
        .CLK_HZ(50_000_000), .BAUD(5_000_000),  // 10 clocks per bit: fast simulation
        .REFRESH_BITS(4)
    ) dut (
        .clk(clk), .rst_n(rst_n), .sw_raw(sw_val),
        .led(led), .seg(seg), .dp(dp), .an(an), .uart_txd(uart_txd),
        .alarm_led(alarm_led), .ok_led(ok_led),
        .tr_if_pc(tr_if_pc), .tr_ex_pc(tr_ex_pc), .tr_wb_pc(tr_wb_pc),
        .tr_stall(tr_stall), .tr_flush(tr_flush), .tr_ex_valid(tr_ex_valid), .tr_retire(tr_retire)
    );

    reg [1023:0] imem_file, dmem_file, log_file, vcd_file;
    reg [31:0]   hacked_addr;
    reg          check_hacked;
    integer      max_cycles, cycles, logfd, hacked_hits, retired, vcd_from, vcd_len;
    reg          dumping, triggered;
    reg [31:0]   trigger_pc, trigger_waddr;

    initial begin
        if (!$value$plusargs("imem=%s", imem_file)) begin
            $display("RESULT: ERROR no +imem given"); $finish;
        end
        $readmemh(imem_file, dut.u_core.u_imem.mem);
        if ($value$plusargs("dmem=%s", dmem_file)) $readmemh(dmem_file, dut.u_dmem.mem);
        if (!$value$plusargs("sw=%h", sw_val)) sw_val = 16'h0001;
        check_hacked = $value$plusargs("hacked=%h", hacked_addr);
        if (!$value$plusargs("max_cycles=%d", max_cycles)) max_cycles = 2_000_000;
        logfd = 0;
        if ($value$plusargs("commitlog=%s", log_file)) logfd = $fopen(log_file, "w");
        if (!$value$plusargs("vcd_from=%d", vcd_from)) vcd_from = 0;
        if (!$value$plusargs("vcd_len=%d", vcd_len))   vcd_len  = 5000;
        if (!$value$plusargs("trigger_pc=%h", trigger_pc)) trigger_pc = 32'hFFFF_FFFF;
        if (!$value$plusargs("trigger_waddr=%h", trigger_waddr)) trigger_waddr = 32'hFFFF_FFF0;
        dumping = 0; triggered = 0;
        if ($value$plusargs("vcd=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, soc_tb);
            $dumpoff;
            dumping = 1;
        end
        cycles = 0; hacked_hits = 0; retired = 0;
        repeat (5) @(posedge clk);
        @(negedge clk) rst_n = 1'b1;            // release between edges: no race with the flip-flops
    end

    // ---- watch the bus: UART characters and the simulation exit register ----
    wire        bus_we    = dut.u_core.bus_we;
    wire [31:0] bus_addr  = dut.u_core.bus_addr;
    wire [31:0] bus_wdata = dut.u_core.bus_wdata;

    // waveform window and trigger (for scripts/timing_diagrams.py)
    always @(posedge clk) if (rst_n) begin
        if (dumping && cycles == vcd_from)           $dumpon;
        if (dumping && cycles == vcd_from + vcd_len) $dumpoff;
        if (!triggered && dut.u_core.dbg_ex_valid && dut.u_core.ex_pc == trigger_pc) begin
            triggered = 1;
            $display("TRIGGER cycle=%0d", cycles);
        end
        // +trigger_waddr=<hex>: print "WTRIGGER cycle=<n> data=<hex>" at every store to that address
        if (bus_we && bus_addr == trigger_waddr)
            $display("WTRIGGER cycle=%0d data=%h", cycles, bus_wdata);
    end

    always @(posedge clk) if (rst_n) begin
        cycles <= cycles + 1;
        if (bus_we && bus_addr == 32'h1000_0010) $write("%c", bus_wdata[7:0]);
        if (bus_we && bus_addr == 32'h1000_00FC) begin
            $display("");
            $display("SIM_EXIT code=%0d cycles=%0d retired=%0d", bus_wdata, cycles, retired);
            if (hacked_hits)  $display("RESULT: HIJACKED exit=%0d", bus_wdata);
            else              $display("RESULT: EXIT %0d", bus_wdata);
            finish_sim;
        end
        if (cycles >= max_cycles) begin
            $display("");
            $display("RESULT: TIMEOUT after %0d cycles (pc=%h)", cycles, tr_if_pc);
            finish_sim;
        end
    end

    // ---- did any attacker instruction execute? ----
    always @(posedge clk) if (rst_n && check_hacked) begin
        if (dut.u_core.dbg_ex_go && dut.u_core.ex_pc == hacked_addr)
            hacked_hits = hacked_hits + 1;
    end

    // ---- ShieldV alarm: let it sit frozen for a while, then report ----
    always @(posedge alarm_led) begin
        $display("");
        $display("SHIELDV ALARM at cycle %0d: fault_pc=%h expected=%h actual=%h cause=%0d", cycles,
                 dut.g_shield.u_sh.fault_pc, dut.g_shield.u_sh.f_expected,
                 dut.g_shield.u_sh.f_actual, dut.g_shield.u_sh.f_cause);
        repeat (50) @(posedge clk);
        $display("frozen pc=%h (unchanged for 50 cycles), display shows %h",
                 tr_if_pc, dut.u_seg.value);
        if (hacked_hits) $display("RESULT: HIJACKED then frozen");
        else             $display("RESULT: BLOCKED fault_pc=%h", dut.g_shield.u_sh.fault_pc);
        finish_sim;
    end

    // ---- commit log in Spike's format: core 0: priv pc (instr) xN value ----
    always @(posedge clk) if (rst_n && dut.u_core.cm_valid) begin
        retired = retired + 1;
        if (logfd) begin
            if (dut.u_core.cm_instr[6:0] == 7'b0000011 && dut.u_core.cm_rd != 0)   // load: add address
                $fdisplay(logfd, "core   0: 3 0x%h (0x%h) x%0d 0x%h mem 0x%h",
                          dut.u_core.cm_pc, dut.u_core.cm_instr, dut.u_core.cm_rd, dut.u_core.cm_value,
                          dut.u_core.cm_addr);
            else if (dut.u_core.cm_we && dut.u_core.cm_rd != 0)
                $fdisplay(logfd, "core   0: 3 0x%h (0x%h) x%0d 0x%h",
                          dut.u_core.cm_pc, dut.u_core.cm_instr, dut.u_core.cm_rd, dut.u_core.cm_value);
            else
                $fdisplay(logfd, "core   0: 3 0x%h (0x%h)", dut.u_core.cm_pc, dut.u_core.cm_instr);
        end
    end

    task finish_sim;
        begin
            if (logfd) $fclose(logfd);
            $finish;
        end
    endtask
endmodule
