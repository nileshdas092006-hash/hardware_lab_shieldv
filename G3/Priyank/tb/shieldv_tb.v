// shieldv_tb.v - the whole ShieldV unit driven by a "fake pipeline" (C1-C9)
// Owner: Priyank (G3)
//
// Instead of a CPU, this testbench plays the role of the EX stage: each task
// call presents one instruction on IF-3 for one cycle. Scenarios:
//   1. nested calls and returns           -> no alarm
//   2. a FLUSHED call (ex_valid = 0)       -> must not push
//   3. a return that sits in EX while the M-unit stalls (ex_valid = 0) -> one pop
//   4. a tampered return                   -> freeze in the SAME cycle, stays frozen
//   5. protection off / count-only         -> no freeze, still counted
//   6. trap mode                           -> sh_trap + handler address
//   7. underflow and overflow
//   8. landing pads (goal tier)
//   9. register reads (CTRL, STAT, FAULT_PC, EXPECTED, ACTUAL)
//  10. lock bit: after boot code locks, a write cannot switch ShieldV off
`timescale 1ns/1ps
module shieldv_tb;
    reg clk = 0;
    always #5 clk = ~clk;

    reg         rst_n = 0, ex_valid = 0, sw_en = 1, reg_we = 0;
    reg  [31:0] ex_instr = 32'h13, ex_pc = 0, ex_target = 0, ex_link = 0, reg_wdata = 0;
    reg  [7:0]  reg_addr = 0;
    wire        sh_freeze, sh_trap, alarm, ev_call, ev_ret, ev_violation;
    wire [31:0] sh_handler_pc, reg_rdata, fault_pc;
    integer errors = 0;

    shieldv dut (.clk(clk), .rst_n(rst_n),
        .ex_valid(ex_valid), .ex_instr(ex_instr), .ex_pc(ex_pc), .ex_target(ex_target), .ex_link(ex_link),
        .sh_freeze(sh_freeze), .sh_trap(sh_trap), .sh_handler_pc(sh_handler_pc),
        .sw_enable(sw_en), .reg_we(reg_we), .reg_addr(reg_addr), .reg_wdata(reg_wdata), .reg_rdata(reg_rdata),
        .alarm(alarm), .fault_pc(fault_pc), .ev_call(ev_call), .ev_ret(ev_ret), .ev_violation(ev_violation));

    localparam CALL = 32'h0000_00EF;     // jal ra, 0  (offset irrelevant here)
    localparam RET  = 32'h0000_8067;     // jalr x0, 0(ra)
    localparam ICALL= 32'h0007_80E7;     // jalr ra, 0(a5)
    localparam LPAD = 32'h0000_0017;     // auipc x0, 0
    localparam NOP  = 32'h0000_0013;

    reg saw_freeze, saw_trap;

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask

    // present one instruction in EX for one cycle; sample outputs mid-cycle
    task ex(input v, input [31:0] instr, input [31:0] pc, input [31:0] target);
        begin
            ex_valid = v; ex_instr = instr; ex_pc = pc; ex_target = target; ex_link = pc + 4;
            #1 saw_freeze = sh_freeze; saw_trap = sh_trap;
            @(negedge clk);
            ex_valid = 0; ex_instr = NOP;
        end
    endtask

    task call(input [31:0] pc, input [31:0] target);  begin ex(1, CALL, pc, target); end endtask
    task ret_to(input [31:0] pc, input [31:0] target); begin ex(1, RET, pc, target);  end endtask

    task write_reg(input [7:0] a, input [31:0] d);
        begin reg_addr = a; reg_wdata = d; reg_we = 1; @(negedge clk); reg_we = 0; end
    endtask

    task read_reg(input [7:0] a, output [31:0] d);
        begin reg_addr = a; #1 d = reg_rdata; end
    endtask

    task reset;
        begin rst_n = 0; @(negedge clk); @(negedge clk); rst_n = 1; end
    endtask

    reg [31:0] r;
    integer i;

    initial begin
        reset;

        // ---- 1. nested calls and returns ----
        call(32'h100, 32'h200);                 // main -> f  (push 0x104)
        call(32'h210, 32'h300);                 // f -> g     (push 0x214)
        ret_to(32'h30C, 32'h214);   expect(!saw_freeze, "1: g returns correctly");
        ret_to(32'h220, 32'h104);   expect(!saw_freeze, "1: f returns correctly");
        expect(dut.depth == 0, "1: stack empty again");

        // ---- 2. a flushed call never pushes ----
        call(32'h100, 32'h200);                 // push 0x104
        ex(0, CALL, 32'h204, 32'h500);          // fetched behind a taken branch, flushed
        ret_to(32'h208, 32'h104);   expect(!saw_freeze && dut.depth == 0, "2: flushed call ignored");

        // ---- 3. a return held in EX (stall) pops exactly once ----
        call(32'h100, 32'h200);
        ex(0, RET, 32'h208, 32'h104);           // waiting, not committing
        ex(0, RET, 32'h208, 32'h104);
        ret_to(32'h208, 32'h104);               // commits once
        expect(!saw_freeze && dut.depth == 0, "3: stalled return pops once");

        // ---- 4. the attack: tampered return address ----
        call(32'h100, 32'h200);                 // expected return 0x104
        ret_to(32'h208, 32'h300);               // ra overwritten with hacked() = 0x300
        expect(saw_freeze, "4: freeze in the same cycle as the bad return");
        repeat (5) @(negedge clk);
        expect(sh_freeze && alarm, "4: stays frozen");
        expect(fault_pc == 32'h208, "4: fault PC latched");
        read_reg(8'h3C, r); expect(r == 32'h104, "4: EXPECTED register");
        read_reg(8'h40, r); expect(r == 32'h300, "4: ACTUAL register");
        read_reg(8'h34, r); expect(r[31] && r[19:16] == 4'd1 && r[7:0] == 8'd1, "4: STAT alarm, cause 1, count 1");
        expect(dut.depth == 1, "4: shadow stack preserved (no pop on the bad return)");
        reset;
        expect(!sh_freeze, "4: reset clears the freeze");

        // ---- 5a. protection off (switch down): attack goes through, but is counted ----
        sw_en = 0;
        call(32'h100, 32'h200);
        ret_to(32'h208, 32'h300);   expect(!saw_freeze, "5a: switch off: no freeze");
        read_reg(8'h34, r);         expect(r[7:0] == 8'd1, "5a: violation still counted");
        sw_en = 1;
        reset;
        // ---- 5b. count-only mode ----
        write_reg(8'h30, 32'h5);                // enable + count-only
        call(32'h100, 32'h200);
        ret_to(32'h208, 32'h300);   expect(!saw_freeze, "5b: count-only does not freeze");
        call(32'h100, 32'h200);
        ret_to(32'h208, 32'h300);
        read_reg(8'h34, r);         expect(r[7:0] == 8'd2, "5b: two violations counted");
        reset;

        // ---- 6. trap mode ----
        write_reg(8'h44, 32'h0000_0080);        // handler address
        write_reg(8'h30, 32'h3);                // enable + trap
        call(32'h100, 32'h200);
        ret_to(32'h208, 32'h300);
        expect(saw_trap && !saw_freeze, "6: trap instead of freeze");
        expect(sh_handler_pc == 32'h80, "6: handler address");
        expect(!sh_freeze, "6: CPU keeps running in the handler");
        reset;

        // ---- 7. underflow and overflow ----
        ret_to(32'h208, 32'h104);   expect(saw_freeze, "7: return with empty shadow stack");
        read_reg(8'h34, r);         expect(r[19:16] == 4'd2, "7: cause 2 = underflow");
        reset;
        for (i = 0; i < 32; i = i + 1) call(32'h100 + 16 * i, 32'h200);
        expect(dut.full, "7: 32 nested calls fill the stack");
        call(32'h900, 32'h200);     expect(saw_freeze, "7: 33rd call overflows");
        read_reg(8'h34, r);         expect(r[19:16] == 4'd3, "7: cause 3 = overflow");
        reset;

        // ---- 8. landing pads ----
        write_reg(8'h30, 32'h9);                // enable + lpad check
        ex(1, ICALL, 32'h100, 32'h400);         // function-pointer call
        ex(1, LPAD,  32'h400, 32'h0);           // target starts with lpad: OK
        expect(!saw_freeze, "8: indirect call to an lpad passes");
        ret_to(32'h40C, 32'h104);
        ex(1, ICALL, 32'h100, 32'h500);
        ex(1, NOP,   32'h500, 32'h0);           // target without lpad
        expect(saw_freeze, "8: indirect call to a non-lpad instruction is caught");
        read_reg(8'h34, r);         expect(r[19:16] == 4'd4, "8: cause 4 = landing pad");
        reset;
        ex(1, ICALL, 32'h100, 32'h500);         // lpad check off by default
        ex(1, NOP,   32'h500, 32'h0);
        expect(!saw_freeze, "8: landing-pad check is off by default");
        reset;

        // ---- 9. CTRL register ----
        read_reg(8'h30, r); expect(r == 32'h1, "9: CTRL resets to enable");

        // ---- 10. lock bit ----
        write_reg(8'h44, 32'h0000_0080);
        write_reg(8'h30, 32'h13);               // enable + trap + lock
        read_reg(8'h34, r); expect(r[30], "10: STAT shows locked");
        write_reg(8'h30, 32'h0);                // attacker tries to switch ShieldV off
        write_reg(8'h44, 32'h0000_0300);        // ... and to move the handler
        read_reg(8'h30, r); expect(r == 32'h13, "10: CTRL unchanged after the lock");
        read_reg(8'h44, r); expect(r == 32'h80, "10: HANDLER unchanged after the lock");
        call(32'h100, 32'h200);
        ret_to(32'h208, 32'h300);
        expect(saw_trap && sh_handler_pc == 32'h80, "10: attack still trapped to the real handler");
        reset;
        read_reg(8'h34, r); expect(!r[30], "10: reset clears the lock");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
