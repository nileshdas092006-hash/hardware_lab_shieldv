// hazard_tb.v - forwarding, stall and flush decisions (blocks A9, A10, A11)
// Owner: Laxmidhar (G1)
`timescale 1ns/1ps
module hazard_tb;
    reg  [4:0] ex_rs1, ex_rs2, wb_rd;
    reg        wb_valid, wb_regw;
    wire       fwd_a, fwd_b;
    reg        m_wait, sh_freeze, ex_redirect, sh_trap;
    wire       stall, wb_bubble, flush_ifid, kill_ex;
    integer errors = 0;

    forward_unit u_f (.ex_rs1(ex_rs1), .ex_rs2(ex_rs2), .wb_valid(wb_valid), .wb_reg_write(wb_regw),
                      .wb_rd(wb_rd), .fwd_a(fwd_a), .fwd_b(fwd_b));
    hazard_unit  u_h (.m_wait(m_wait), .sh_freeze(sh_freeze), .stall(stall), .wb_bubble(wb_bubble));
    flush_unit   u_l (.ex_redirect(ex_redirect), .sh_trap(sh_trap), .flush_ifid(flush_ifid), .kill_ex(kill_ex));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask

    initial begin
        // ---- forwarding ----
        // add x5,x1,x2 (in WB) ; sub x6,x5,x3 (in EX) -> forward a
        wb_valid = 1; wb_regw = 1; wb_rd = 5; ex_rs1 = 5; ex_rs2 = 3; #1;
        expect(fwd_a && !fwd_b, "add -> sub forwards operand a");
        ex_rs1 = 3; ex_rs2 = 5; #1;
        expect(!fwd_a && fwd_b, "forwards operand b");
        ex_rs1 = 5; ex_rs2 = 5; #1;
        expect(fwd_a && fwd_b, "forwards both");
        // lw x1,0(sp) (in WB) ; jalr x0,0(x1) (ret, in EX): load data forwarded
        wb_rd = 1; ex_rs1 = 1; ex_rs2 = 0; #1;
        expect(fwd_a, "load -> jalr (ret) forwards ra");
        // never forward x0, bubbles, or instructions that do not write
        wb_rd = 0; ex_rs1 = 0; #1;            expect(!fwd_a, "x0 is never forwarded");
        wb_rd = 7; ex_rs1 = 7; wb_valid = 0; #1; expect(!fwd_a, "bubble is never forwarded");
        wb_valid = 1; wb_regw = 0; #1;        expect(!fwd_a, "store/branch (no write) not forwarded");

        // ---- stalls ----
        m_wait = 0; sh_freeze = 0; #1; expect(!stall && !wb_bubble, "no stall normally");
        m_wait = 1; #1;                expect(stall && wb_bubble, "DIV in EX stalls");
        m_wait = 0; sh_freeze = 1; #1; expect(stall && wb_bubble, "ShieldV freeze stalls");

        // ---- flushes ----
        ex_redirect = 0; sh_trap = 0; #1; expect(!flush_ifid && !kill_ex, "no flush");
        ex_redirect = 1; #1;              expect(flush_ifid && !kill_ex, "taken branch flushes IF/ID only");
        ex_redirect = 0; sh_trap = 1; #1; expect(flush_ifid && kill_ex, "trap flushes and kills EX");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
