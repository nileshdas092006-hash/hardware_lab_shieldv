// multiplier_tb.v - 10,000 random cases + edge cases for MUL/MULH/MULHSU/MULHU (block B1)
// Owner: Nishant (G2)
//
// Reference model: 64-bit multiplication done by the simulator itself,
// with the sign rules of each instruction written out separately.
`timescale 1ns/1ps
module multiplier_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, start = 0;
    reg  [1:0]  op;
    reg  [31:0] a, b;
    wire        busy, done;
    wire [31:0] result;
    integer errors = 0, checks = 0, i, k, lat, max_lat = 0;

    multiplier dut (.clk(clk), .rst_n(rst_n), .start(start), .op(op), .a(a), .b(b),
                    .busy(busy), .done(done), .result(result));

    function [31:0] model(input [1:0] o, input [31:0] x, input [31:0] y);
        reg signed [63:0] ss, su;
        reg        [63:0] uu;
        begin
            ss = $signed(x) * $signed(y);
            su = $signed({{32{x[31]}}, x}) * $signed({32'd0, y});
            uu = {32'd0, x} * {32'd0, y};
            case (o)
                2'd0: model = ss[31:0];
                2'd1: model = ss[63:32];
                2'd2: model = su[63:32];
                default: model = uu[63:32];
            endcase
        end
    endfunction

    task run_one(input [1:0] o, input [31:0] x, input [31:0] y);
        reg [31:0] want;
        begin
            want = model(o, x, y);
            @(negedge clk); op = o; a = x; b = y; start = 1;
            @(negedge clk); start = 0; a = 32'hX; b = 32'hX;   // operands must have been captured
            lat = 1;
            while (!done) begin @(negedge clk); lat = lat + 1; end
            if (lat > max_lat) max_lat = lat;
            checks = checks + 1;
            if (result !== want) begin
                errors = errors + 1;
                if (errors < 10) $display("FAIL op=%0d a=%h b=%h got=%h expected=%h", o, x, y, result, want);
            end
        end
    endtask

    reg [31:0] edges [0:7];
    initial begin
        edges[0] = 32'h0000_0000; edges[1] = 32'h0000_0001; edges[2] = 32'hFFFF_FFFF;
        edges[3] = 32'h8000_0000; edges[4] = 32'h7FFF_FFFF; edges[5] = 32'h0000_FFFF;
        edges[6] = 32'hFFFF_0000; edges[7] = 32'h1234_5678;
        repeat (2) @(negedge clk);
        rst_n = 1;
        // every pair of edge values, every op (includes -2^31 x -2^31 and -1 x 1)
        for (k = 0; k < 4; k = k + 1)
            for (i = 0; i < 64; i = i + 1)
                run_one(k, edges[i / 8], edges[i % 8]);
        // 10,000 random cases
        for (i = 0; i < 10000; i = i + 1)
            run_one({$random} % 4, $random, $random);

        $display("max latency %0d cycles (goal: <= 2)", max_lat);
        if (errors == 0 && max_lat <= 2) $display("TEST PASSED (%0d checks, latency %0d)", checks, max_lat);
        else                             $display("TEST FAILED: %0d errors, latency %0d", errors, max_lat);
        $finish;
    end
endmodule
