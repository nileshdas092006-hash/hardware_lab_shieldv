// munit_tb.v - the start/busy/done handshake of the whole M-unit (block B3, IF-1)
// Owner: Nishant (G2)
//
// Checks the contract the core relies on:
//   * done is a single-cycle pulse, result valid in that cycle
//   * back-to-back operations (start in the cycle right after done) work
//   * MUL takes <= 2 cycles, DIV <= 34
//   * the real unit and munit_stub give identical results
`timescale 1ns/1ps
module munit_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, start = 0;
    reg  [2:0]  op;
    reg  [31:0] a, b;
    wire        busy, done, s_busy, s_done;
    wire [31:0] result, s_result;
    integer errors = 0, checks = 0, i, lat, done_len;

    munit      dut  (.clk(clk), .rst_n(rst_n), .start(start), .op(op), .a(a), .b(b),
                     .busy(busy), .done(done), .result(result));
    munit_stub stub (.clk(clk), .rst_n(rst_n), .start(start), .op(op), .a(a), .b(b),
                     .busy(s_busy), .done(s_done), .result(s_result));

    reg [31:0] stub_val, dut_val;
    reg        s_seen = 0;
    always @(posedge clk) begin
        if (start)       s_seen <= 1'b0;
        else if (s_done) begin s_seen <= 1'b1; stub_val <= s_result; end
    end

    task run_one(input [2:0] o, input [31:0] x, input [31:0] y, input integer max_lat);
        begin
            @(negedge clk); op = o; a = x; b = y; start = 1;
            @(negedge clk); start = 0;
            lat = 1;
            while (!done) begin @(negedge clk); lat = lat + 1; end
            dut_val = result;
            while (!s_seen) @(negedge clk);         // the stub (3-cycle delay) as reference
            checks = checks + 1;
            if (dut_val !== stub_val) begin
                errors = errors + 1;
                $display("FAIL op=%0d a=%h b=%h unit=%h stub=%h", o, x, y, dut_val, stub_val);
            end
            if (lat > max_lat) begin
                errors = errors + 1;
                $display("FAIL op=%0d latency %0d > %0d", o, lat, max_lat);
            end
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        for (i = 0; i < 400; i = i + 1)
            run_one(i % 8, $random, (i % 16 == 5) ? 32'd0 : $random, (i % 8 < 4) ? 2 : 34);

        // done must be exactly one cycle long, and a new start right after works
        @(negedge clk); op = 3'd0; a = 6; b = 7; start = 1;
        @(negedge clk); start = 0;
        while (!done) @(negedge clk);
        if (result !== 32'd42) begin errors = errors + 1; $display("FAIL 6*7"); end
        op = 3'd4; a = 100; b = 3; start = 1;          // back-to-back DIV in the done cycle's next edge
        @(negedge clk); start = 0;
        if (done) begin errors = errors + 1; $display("FAIL done longer than one cycle"); end
        while (!done) @(negedge clk);
        if (result !== 32'd33) begin errors = errors + 1; $display("FAIL back-to-back 100/3 = %0d", result); end

        if (errors == 0) $display("TEST PASSED (%0d handshakes)", checks);
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
