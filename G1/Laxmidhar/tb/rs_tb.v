// rs_tb.v - reservation station: wake-up on the CDB and out-of-order issue (block A23)
// Owner: Laxmidhar (G1)
`timescale 1ns/1ps
module rs_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, flush = 0, in_valid = 0, in_r1 = 0, in_r2 = 0, cdb_valid = 0, take = 0;
    reg  [7:0]  in_payload = 0;
    reg  [3:0]  in_tag = 0, in_q1 = 0, in_q2 = 0, cdb_tag = 0;
    reg  [31:0] in_v1 = 0, in_v2 = 0, cdb_value = 0;
    wire        full, out_valid;
    wire [7:0]  out_payload;
    wire [3:0]  out_tag;
    wire [31:0] out_v1, out_v2;
    integer errors = 0;

    rs #(.N(4), .PW(8), .TAG_W(4)) dut (.clk(clk), .rst_n(rst_n), .flush(flush),
        .in_valid(in_valid), .in_payload(in_payload), .in_tag(in_tag),
        .in_r1(in_r1), .in_v1(in_v1), .in_q1(in_q1), .in_r2(in_r2), .in_v2(in_v2), .in_q2(in_q2),
        .full(full), .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .out_valid(out_valid), .out_payload(out_payload), .out_tag(out_tag),
        .out_v1(out_v1), .out_v2(out_v2), .take(take));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask
    // dispatch: tag, payload, op1 (ready?, value, waits-for), op2 (...)
    task put(input [3:0] t, input [7:0] p, input r1, input [31:0] v1, input [3:0] q1,
             input r2, input [31:0] v2, input [3:0] q2);
        begin
            in_valid = 1; in_tag = t; in_payload = p;
            in_r1 = r1; in_v1 = v1; in_q1 = q1; in_r2 = r2; in_v2 = v2; in_q2 = q2;
            @(negedge clk); in_valid = 0;
        end
    endtask
    task broadcast(input [3:0] t, input [31:0] v);
        begin cdb_valid = 1; cdb_tag = t; cdb_value = v; @(negedge clk); cdb_valid = 0; end
    endtask

    initial begin
        @(negedge clk); @(negedge clk); rst_n = 1;

        // older instruction (tag 1) waits for tag 9; younger (tag 2) is ready at once
        put(4'd1, 8'hA1, 0, 0, 4'd9, 1, 32'd5, 0);
        put(4'd2, 8'hA2, 1, 32'd7, 0, 1, 32'd8, 0);
        #1 expect(out_valid && out_tag == 2 && out_payload == 8'hA2, "younger ready instruction issues first");
        take = 1; @(negedge clk); take = 0;
        #1 expect(!out_valid, "older one still waiting for tag 9");

        // the CDB delivers tag 9 -> wake up
        broadcast(4'd9, 32'd1234);
        #1 expect(out_valid && out_tag == 1 && out_v1 == 1234 && out_v2 == 5, "woken up with the CDB value");
        // unit busy: stays put
        @(negedge clk);
        #1 expect(out_valid && out_tag == 1, "not taken: stays in the station");
        take = 1; @(negedge clk); take = 0;
        #1 expect(!out_valid, "issued");

        // both operands waiting on two different producers
        put(4'd3, 8'hA3, 0, 0, 4'd10, 0, 0, 4'd11);
        broadcast(4'd11, 32'd22);
        #1 expect(!out_valid, "one of two operands is not enough");
        broadcast(4'd10, 32'd11);
        #1 expect(out_valid && out_v1 == 11 && out_v2 == 22, "both operands captured");

        // full and flush
        put(4'd4, 8'h04, 0, 0, 4'd12, 1, 0, 0);
        put(4'd5, 8'h05, 0, 0, 4'd12, 1, 0, 0);
        put(4'd6, 8'h06, 0, 0, 4'd12, 1, 0, 0);
        #1 expect(full, "4 entries busy: full");
        flush = 1; @(negedge clk); flush = 0;
        #1 expect(!full && !out_valid, "flush empties the station");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
