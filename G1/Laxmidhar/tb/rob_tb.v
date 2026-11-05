// rob_tb.v - reorder buffer: in-order commit of out-of-order results (block A22)
// Owner: Laxmidhar (G1)
//
//   1. fill all 16 entries -> full
//   2. finish them in REVERSE order on the CDB; the head stays on the oldest
//      until it is done, then commits come out in program order
//   3. operand read ports see results before they commit
//   4. a store is completed through the store port (address, no value)
//   5. flush drops everything behind a committing head
`timescale 1ns/1ps
module rob_tb;
    reg clk = 0;
    always #5 clk = ~clk;

    reg         rst_n = 0, flush = 0, alloc = 0, commit = 0;
    reg  [31:0] a_pc = 0;
    reg         a_store = 0, a_done = 0;
    reg         cdb_valid = 0, st_valid = 0;
    reg  [3:0]  cdb_tag = 0, st_tag = 0, rd_tag1 = 0, rd_tag2 = 0;
    reg  [31:0] cdb_value = 0, st_addr = 0;
    wire [3:0]  alloc_tag, head_tag;
    wire        full, head_valid, head_done, rd_done1, rd_done2, head_store;
    wire [31:0] head_pc, head_value, head_aux, rd_value1, rd_value2;
    integer errors = 0, i, last_pc, order_ok;

    rob #(.TAG_W(4), .N(16), .HIST_W(8)) dut (
        .clk(clk), .rst_n(rst_n), .flush(flush),
        .alloc(alloc), .a_pc(a_pc), .a_instr(32'h13), .a_rd(5'd1), .a_regw(1'b1), .a_mem(a_store),
        .a_store(a_store), .a_ctrl(1'b0), .a_cond(1'b0), .a_hist(8'd0), .a_done(a_done),
        .a_value(32'd0), .a_aux(32'd0), .a_taken(1'b0),
        .alloc_tag(alloc_tag), .full(full),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value), .cdb_aux(32'd0),
        .cdb_taken(1'b0), .cdb_mispred(1'b0),
        .st_valid(st_valid), .st_tag(st_tag), .st_addr(st_addr),
        .rd_tag1(rd_tag1), .rd_done1(rd_done1), .rd_value1(rd_value1),
        .rd_tag2(rd_tag2), .rd_done2(rd_done2), .rd_value2(rd_value2),
        .head_valid(head_valid), .head_tag(head_tag), .head_done(head_done),
        .head_pc(head_pc), .head_instr(), .head_rd(), .head_regw(), .head_mem(), .head_store(head_store),
        .head_ctrl(), .head_cond(), .head_hist(), .head_value(head_value), .head_aux(head_aux),
        .head_taken(), .head_mispred(), .commit(commit));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask

    initial begin
        @(negedge clk); @(negedge clk); rst_n = 1;
        expect(!head_valid, "empty after reset");

        // 1. allocate 16 instructions, pc = 0x100, 0x104, ...
        for (i = 0; i < 16; i = i + 1) begin
            a_pc = 32'h100 + 4 * i; alloc = 1; @(negedge clk);
        end
        alloc = 0;
        expect(full, "16 entries: full");

        // 2. complete in reverse order; try to commit every cycle
        // (like the core: commit is asked for only when the head is done)
        for (i = 15; i >= 1; i = i - 1) begin
            cdb_valid = 1; cdb_tag = i; cdb_value = 1000 + i; #1;
            expect(!head_done && head_tag == 0, "oldest not done: nothing can commit");
            @(negedge clk);
        end
        cdb_valid = 0;
        // 3. read ports see a finished result that has not committed yet
        rd_tag1 = 4'd9; #1 expect(rd_done1 && rd_value1 == 1009, "read port: entry 9 done, value 1009");
        // finish the oldest; now all 16 commit in program order, one per cycle
        cdb_valid = 1; cdb_tag = 0; cdb_value = 1000; @(negedge clk); cdb_valid = 0;
        order_ok = 1; last_pc = 32'h0FC; commit = 1;
        for (i = 0; i < 16; i = i + 1) begin
            #1 if (!(head_valid && head_done && head_pc == last_pc + 4 && head_value == 1000 + i)) order_ok = 0;
            last_pc = head_pc;
            @(negedge clk);
        end
        commit = 0;
        expect(order_ok, "commits in program order with the right values");
        expect(!head_valid, "empty after 16 commits");

        // 4. a store completes through the store port
        a_store = 1; a_pc = 32'h200; alloc = 1; @(negedge clk); alloc = 0; a_store = 0;
        st_valid = 1; st_tag = head_tag; st_addr = 32'h0001_0040; @(negedge clk); st_valid = 0;
        expect(head_done && head_store && head_aux == 32'h0001_0040, "store done with its address");
        commit = 1; @(negedge clk); commit = 0;

        // 5. flush behind a committing head
        a_done = 1; alloc = 1; a_pc = 32'h300; @(negedge clk);
        a_done = 0; a_pc = 32'h304; @(negedge clk); a_pc = 32'h308; @(negedge clk); alloc = 0;
        commit = 1; flush = 1; @(negedge clk); commit = 0; flush = 0;
        expect(!head_valid && !full, "flush: only the committed head survived, the rest is gone");
        a_done = 1; alloc = 1; a_pc = 32'h400; @(negedge clk); alloc = 0; a_done = 0;
        expect(head_valid && head_pc == 32'h400, "fetch restarts cleanly after the flush");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
