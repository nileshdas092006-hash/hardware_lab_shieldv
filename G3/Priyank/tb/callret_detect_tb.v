// callret_detect_tb.v - classification table for calls, returns, indirect jumps (block C1)
// Owner: Priyank (G3)
`timescale 1ns/1ps
module callret_detect_tb;
    reg  [31:0] instr;
    wire        is_call, is_ret, needs_lpad;
    integer errors = 0, checks = 0;

    callret_detect dut (.instr(instr), .is_call(is_call), .is_ret(is_ret), .needs_lpad(needs_lpad));

    task check(input [31:0] i, input c, input r, input l, input [255:0] text);
        begin
            instr = i; #1; checks = checks + 1;
            if ({is_call, is_ret, needs_lpad} !== {c, r, l}) begin
                errors = errors + 1;
                $display("FAIL %0s: call/ret/lpad = %b%b%b expected %b%b%b", text, is_call, is_ret, needs_lpad, c, r, l);
            end
        end
    endtask

    initial begin
        //            encoding        call ret lpad
        check(32'h0080_00EF, 1, 0, 0, "jal ra, +8          (call)");
        check(32'h0080_02EF, 1, 0, 0, "jal t0, +8          (call via x5)");
        check(32'h0080_006F, 0, 0, 0, "j +8 (jal x0)       (plain jump)");
        check(32'h0080_016F, 0, 0, 0, "jal sp, +8          (rd not a link reg)");
        check(32'h0000_8067, 0, 1, 0, "ret = jalr x0,0(ra) (return)");
        check(32'h0002_8067, 0, 1, 0, "jr t0               (return via x5)");
        check(32'h0007_80E7, 1, 0, 1, "jalr ra, 0(a5)      (indirect call: push + lpad)");
        check(32'h0007_8067, 0, 0, 1, "jr a5               (indirect jump: lpad)");
        check(32'h0003_8067, 0, 0, 0, "jr t2               (x7 is exempt from lpad)");
        check(32'h0000_80E7, 1, 0, 0, "jalr ra, 0(ra)      (call: rd == rs1, push only)");
        check(32'h0002_80E7, 1, 1, 0, "jalr ra, 0(t0)      (coroutine swap: pop then push)");
        check(32'h0000_82E7, 1, 1, 0, "jalr t0, 0(ra)      (coroutine swap)");
        check(32'h0000_0013, 0, 0, 0, "nop");
        check(32'h0020_8463, 0, 0, 0, "beq                 (branches are not calls)");
        check(32'h0000_0097, 0, 0, 0, "auipc ra            (not a call)");

        if (errors == 0) $display("TEST PASSED (%0d checks)", checks);
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
