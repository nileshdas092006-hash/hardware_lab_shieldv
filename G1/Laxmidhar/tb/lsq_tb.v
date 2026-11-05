// lsq_tb.v - load/store queue ordering rules (block A24)
// Owner: Laxmidhar (G1)
//
//   1. a load to a different word than an older store goes early
//   2. a load to the SAME word waits until that store commits (pop)
//   3. an older store with an unknown address blocks every younger load
//   4. a store reports "done" once, when address and data are known
//   5. an I/O load waits until it is the oldest instruction (ROB head)
`timescale 1ns/1ps
module lsq_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, flush = 0, in_valid = 0, in_store = 0, in_rb = 0, in_rd = 0;
    reg  [2:0]  in_funct3 = 3'b010;
    reg  [31:0] in_imm = 0, in_vb = 0, in_vd = 0, cdb_value = 0;
    reg  [3:0]  in_tag = 0, in_qb = 0, in_qd = 0, cdb_tag = 0, rob_head_tag = 0;
    reg         cdb_valid = 0, ld_go = 0, pop = 0;
    wire        full, sr_valid, ld_req, head_valid, head_store;
    wire [3:0]  sr_tag, ld_tag;
    wire [31:0] sr_addr, ld_addr, head_addr, head_data;
    wire [2:0]  ld_funct3, head_funct3;
    integer errors = 0, sr_count = 0;

    lsq #(.N(8), .PTR_W(3), .TAG_W(4)) dut (.clk(clk), .rst_n(rst_n), .flush(flush),
        .in_valid(in_valid), .in_store(in_store), .in_funct3(in_funct3), .in_imm(in_imm), .in_tag(in_tag),
        .in_rb(in_rb), .in_vb(in_vb), .in_qb(in_qb), .in_rd(in_rd), .in_vd(in_vd), .in_qd(in_qd),
        .full(full), .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .sr_valid(sr_valid), .sr_tag(sr_tag), .sr_addr(sr_addr),
        .rob_head_tag(rob_head_tag), .ld_req(ld_req), .ld_addr(ld_addr), .ld_funct3(ld_funct3),
        .ld_tag(ld_tag), .ld_go(ld_go),
        .head_valid(head_valid), .head_store(head_store), .head_addr(head_addr), .head_data(head_data),
        .head_funct3(head_funct3), .pop(pop));

    always @(posedge clk) if (sr_valid) sr_count = sr_count + 1;

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask
    // store: tag, base ready?, base value or tag, data ready, data
    task st(input [3:0] t, input rb, input [31:0] vb, input [3:0] qb, input [31:0] vd);
        begin
            in_valid = 1; in_store = 1; in_tag = t; in_imm = 0;
            in_rb = rb; in_vb = vb; in_qb = qb; in_rd = 1; in_vd = vd;
            @(negedge clk); in_valid = 0;
        end
    endtask
    task ld(input [3:0] t, input [31:0] base);
        begin
            in_valid = 1; in_store = 0; in_tag = t; in_imm = 0;
            in_rb = 1; in_vb = base; in_rd = 1; in_vd = 0;
            @(negedge clk); in_valid = 0;
        end
    endtask
    task commit_head; begin pop = 1; @(negedge clk); pop = 0; end endtask

    initial begin
        @(negedge clk); @(negedge clk); rst_n = 1;

        // 1 + 4. store to 0x10040, then a load from 0x10080
        st(4'd0, 1, 32'h0001_0040, 0, 32'hCAFE);
        #1 expect(sr_valid && sr_tag == 0 && sr_addr == 32'h0001_0040, "4: store reports done + address");
        ld(4'd1, 32'h0001_0080);
        #1 expect(ld_req && ld_tag == 1 && ld_addr == 32'h0001_0080, "1: load to another word goes before the store commits");
        ld_go = 1; @(negedge clk); ld_go = 0;
        #1 expect(!ld_req, "1: issued once");
        expect(sr_count == 1, "4: store reported done only once");

        // 2. a load from the same word as the store
        ld(4'd2, 32'h0001_0040);
        #1 expect(!ld_req, "2: same word as an older store: wait");
        expect(head_valid && head_store && head_addr == 32'h0001_0040 && head_data == 32'hCAFE,
               "head is the store, ready to be written at commit");
        commit_head;                                     // the store commits
        #1 expect(ld_req && ld_tag == 2, "2: store committed: the load may go");
        ld_go = 1; @(negedge clk); ld_go = 0;
        commit_head; commit_head;                        // loads 1 and 2 commit

        // 3. store with an unknown address (base comes from tag 7)
        st(4'd3, 0, 0, 4'd7, 32'h1);
        ld(4'd4, 32'h0001_0100);
        #1 expect(!ld_req, "3: older store address unknown: load waits");
        cdb_valid = 1; cdb_tag = 4'd7; cdb_value = 32'h0001_0200; @(negedge clk); cdb_valid = 0;
        #1 expect(ld_req && ld_tag == 4, "3: address known and different: load goes");
        ld_go = 1; @(negedge clk); ld_go = 0;
        commit_head; commit_head;

        // 5. I/O load (UART status) must be the oldest instruction
        ld(4'd5, 32'h1000_0014);
        rob_head_tag = 4'd4; #1 expect(!ld_req, "5: I/O load waits while an older instruction is in the ROB");
        rob_head_tag = 4'd5; #1 expect(ld_req && ld_tag == 5, "5: I/O load goes when it is the ROB head");

        flush = 1; @(negedge clk); flush = 0;
        #1 expect(!head_valid && !ld_req, "flush empties the queue");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
