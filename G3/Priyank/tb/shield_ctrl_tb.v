// shield_ctrl_tb.v - control register and the lock bit (block C7)
// Owner: Priyank (G3)
//
// Directed write tests for the abstract's "lock integrity" goal:
//   1. reset value: enable on, unlocked
//   2. before the lock, CTRL and HANDLER take every write
//   3. a write with bit 4 = 1 sets the lock (and the other bits, same write)
//   4. after the lock, 1000 random writes to CTRL and HANDLER change nothing
//   5. SW0 still turns protection off (it is a switch, not a memory write)
//   6. only reset clears the lock
`timescale 1ns/1ps
module shield_ctrl_tb;
    reg clk = 0;
    always #5 clk = ~clk;

    reg         rst_n = 0, sw_enable = 1, we_ctrl = 0, we_handler = 0;
    reg  [31:0] wdata = 0;
    wire [4:0]  ctrl;
    wire [31:0] handler_pc;
    wire        locked, enabled, trap_mode, count_only, lpad_en;
    integer errors = 0, changes = 0, i;
    reg  [4:0]  ctrl_at_lock;
    reg  [31:0] handler_at_lock;

    shield_ctrl dut (.clk(clk), .rst_n(rst_n), .sw_enable(sw_enable),
        .we_ctrl(we_ctrl), .we_handler(we_handler), .wdata(wdata),
        .ctrl(ctrl), .handler_pc(handler_pc), .locked(locked),
        .enabled(enabled), .trap_mode(trap_mode), .count_only(count_only), .lpad_en(lpad_en));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask

    task wr_ctrl(input [31:0] d);    begin wdata = d; we_ctrl = 1;    @(negedge clk); we_ctrl = 0;    end endtask
    task wr_handler(input [31:0] d); begin wdata = d; we_handler = 1; @(negedge clk); we_handler = 0; end endtask

    initial begin
        @(negedge clk); @(negedge clk); rst_n = 1;

        // 1. reset value
        expect(ctrl == 5'b00001 && !locked && enabled, "1: reset = enable on, unlocked");

        // 2. unlocked: writes land
        wr_ctrl(32'h0000_000E);   expect(ctrl == 5'b01110 && !enabled, "2: CTRL write before lock");
        wr_handler(32'h0000_0123); expect(handler_pc == 32'h120, "2: HANDLER write (word aligned)");

        // 3. boot code: enable + trap mode + lock in one store
        wr_handler(32'h0000_0400);
        wr_ctrl(32'h0000_0013);
        expect(locked && enabled && trap_mode && ctrl == 5'b10011, "3: lock set together with enable + trap");
        ctrl_at_lock = ctrl; handler_at_lock = handler_pc;

        // 4. attacker writes: nothing may change
        for (i = 0; i < 1000; i = i + 1) begin
            wdata = $random; we_ctrl = $random; we_handler = $random;
            @(negedge clk);
            we_ctrl = 0; we_handler = 0;
            if (ctrl !== ctrl_at_lock || handler_pc !== handler_at_lock) changes = changes + 1;
        end
        wr_ctrl(32'h0);           // the obvious attack: switch ShieldV off
        if (ctrl !== ctrl_at_lock) changes = changes + 1;
        expect(changes == 0, "4: 0 register changes after the lock");

        // 5. the physical switch still works
        sw_enable = 0; #1 expect(!enabled, "5: SW0 down turns protection off");
        sw_enable = 1; #1 expect(enabled,  "5: SW0 up turns it back on");

        // 6. only reset unlocks
        rst_n = 0; @(negedge clk); rst_n = 1;
        expect(!locked && ctrl == 5'b00001 && handler_pc == 0, "6: reset clears the lock");
        wr_ctrl(32'h0); expect(ctrl == 5'b0, "6: writable again after reset");

        if (errors == 0) $display("TEST PASSED (1001 writes after the lock, %0d changes)", changes);
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
