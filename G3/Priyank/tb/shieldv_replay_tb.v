// shieldv_replay_tb.v - replay a real program's calls and returns into ShieldV
// Owner: Priyank (G3)
//
// The trace (+trace=<file>, made by sw/golden/make_trace.py from a commit log)
// lists every jal/jalr a real workload executed: "<instr> <pc> <target>".
// This testbench feeds it to ShieldV with no CPU at all, adding pipeline
// noise between instructions: bubbles and FLUSHED fake calls (ex_valid = 0),
// which a correct ShieldV must ignore.
//
//   Pass 1: the honest trace            -> zero violations (no false alarms)
//   Pass 2: the 100th return tampered    -> caught, freeze, fault PC correct
`timescale 1ns/1ps
module shieldv_replay_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, ex_valid = 0;
    reg  [31:0] ex_instr = 32'h13, ex_pc = 0, ex_target = 0, ex_link = 0;
    wire        sh_freeze, sh_trap, alarm, ev_call, ev_ret, ev_violation;
    wire [31:0] sh_handler_pc, reg_rdata, fault_pc;

    shieldv dut (.clk(clk), .rst_n(rst_n),
        .ex_valid(ex_valid), .ex_instr(ex_instr), .ex_pc(ex_pc), .ex_target(ex_target), .ex_link(ex_link),
        .sh_freeze(sh_freeze), .sh_trap(sh_trap), .sh_handler_pc(sh_handler_pc),
        .sw_enable(1'b1), .reg_we(1'b0), .reg_addr(8'h34), .reg_wdata(32'd0), .reg_rdata(reg_rdata),
        .alarm(alarm), .fault_pc(fault_pc), .ev_call(ev_call), .ev_ret(ev_ret), .ev_violation(ev_violation));

    localparam INJECT_AT = 100;
    reg [1023:0] trace_file;
    integer fd, n, errors = 0, lines, calls, rets, violations, max_depth, ret_no, caught_at;
    reg [31:0] instr, pc, target;

    always @(posedge clk) if (rst_n) begin
        if (ev_call)      calls      <= calls + 1;
        if (ev_ret)       rets       <= rets + 1;
        if (ev_violation) violations <= violations + 1;
        if (dut.depth > max_depth) max_depth <= dut.depth;
    end

    task replay(input integer inject);
        begin
            fd = $fopen(trace_file, "r");
            lines = 0; calls = 0; rets = 0; violations = 0; max_depth = 0; ret_no = 0; caught_at = 0;
            rst_n = 0; @(negedge clk); @(negedge clk); rst_n = 1;
            while (!$feof(fd) && !alarm) begin
                n = $fscanf(fd, "%h %h %h\n", instr, pc, target);
                if (n == 3) begin
                    lines = lines + 1;
                    // pipeline noise first: a bubble, sometimes a flushed fake call
                    if (lines % 3 == 0) begin
                        ex_valid = 0; ex_instr = 32'h0000_00EF; ex_pc = 32'h0000_FFF0; ex_target = 32'h0000_0BAD;
                        ex_link = 32'h0000_FFF4;
                        @(negedge clk);
                    end
                    // the real instruction commits
                    ex_valid = 1; ex_instr = instr; ex_pc = pc; ex_target = target; ex_link = pc + 4;
                    #1;
                    if (dut.is_ret) begin
                        ret_no = ret_no + 1;
                        if (ret_no == inject) begin ex_target = target ^ 32'h4; caught_at = pc; end
                    end
                    @(negedge clk);
                    ex_valid = 0; ex_instr = 32'h13;
                end
            end
            $fclose(fd);
            repeat (3) @(negedge clk);
        end
    endtask

    initial begin
        if (!$value$plusargs("trace=%s", trace_file)) begin $display("TEST FAILED: no +trace"); $finish; end

        replay(0);
        $display("pass 1: %0d jumps, %0d pushes, %0d pops, max depth %0d, %0d violations",
                 lines, calls, rets, max_depth, violations);
        if (violations != 0 || alarm) begin errors = errors + 1; $display("FAIL false alarm on an honest trace"); end
        if (calls == 0 || rets == 0)   begin errors = errors + 1; $display("FAIL trace had no calls/returns"); end

        replay(INJECT_AT);
        $display("pass 2: tampered return #%0d at pc %h -> alarm=%b fault_pc=%h",
                 INJECT_AT, caught_at, alarm, fault_pc);
        if (!alarm || !sh_freeze)   begin errors = errors + 1; $display("FAIL tampered return not caught"); end
        if (fault_pc !== caught_at) begin errors = errors + 1; $display("FAIL wrong fault PC"); end

        if (errors == 0) $display("TEST PASSED (no false alarms, injected attack caught)");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
