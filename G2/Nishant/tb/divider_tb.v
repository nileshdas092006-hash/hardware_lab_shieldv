// divider_tb.v - 10,000 random cases + every spec edge case for DIV/DIVU/REM/REMU (block B2)
// Owner: Nishant (G2)
`timescale 1ns/1ps
module divider_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg         rst_n = 0, start = 0;
    reg  [1:0]  op;
    reg  [31:0] a, b;
    wire        busy, done;
    wire [31:0] result;
    integer errors = 0, checks = 0, i, k, lat, max_lat = 0;

    divider dut (.clk(clk), .rst_n(rst_n), .start(start), .op(op), .a(a), .b(b),
                 .busy(busy), .done(done), .result(result));

    // reference model, straight from the RISC-V spec table
    function [31:0] model(input [1:0] o, input [31:0] x, input [31:0] y);
        reg signed [31:0] qs, rs;     // own variables: keeps the division signed
        reg        [31:0] ys, yu;     // never divide by 0 or INT_MIN/-1 inside the simulator
        begin
            yu = (y == 0) ? 32'd1 : y;
            ys = (y == 0 || (x == 32'h8000_0000 && y == 32'hFFFF_FFFF)) ? 32'd1 : y;
            qs = $signed(x) / $signed(ys);
            rs = $signed(x) % $signed(ys);
            case (o)
                2'd0: model = (y == 0) ? 32'hFFFF_FFFF :
                              (x == 32'h8000_0000 && y == 32'hFFFF_FFFF) ? 32'h8000_0000 :
                              qs;
                2'd1: model = (y == 0) ? 32'hFFFF_FFFF : x / yu;
                2'd2: model = (y == 0) ? x :
                              (x == 32'h8000_0000 && y == 32'hFFFF_FFFF) ? 32'd0 :
                              rs;
                default: model = (y == 0) ? x : x % yu;
            endcase
        end
    endfunction

    task run_one(input [1:0] o, input [31:0] x, input [31:0] y);
        reg [31:0] want;
        begin
            want = model(o, x, y);
            @(negedge clk); op = o; a = x; b = y; start = 1;
            @(negedge clk); start = 0; a = 32'hX; b = 32'hX;
            if (!busy) begin errors = errors + 1; $display("FAIL busy did not rise"); end
            lat = 1;
            while (!done) begin @(negedge clk); lat = lat + 1; end
            if (lat > max_lat) max_lat = lat;
            checks = checks + 1;
            if (result !== want) begin
                errors = errors + 1;
                if (errors < 10) $display("FAIL op=%0d a=%h b=%h got=%h expected=%h", o, x, y, result, want);
            end
            @(negedge clk);
            if (busy) begin errors = errors + 1; $display("FAIL busy stuck after done"); end
        end
    endtask

    reg [31:0] edges [0:9];
    initial begin
        edges[0] = 32'd0;          edges[1] = 32'd1;          edges[2] = 32'hFFFF_FFFF;  // -1
        edges[3] = 32'h8000_0000;  edges[4] = 32'h7FFF_FFFF;  edges[5] = 32'd7;
        edges[6] = 32'hFFFF_FFF9;  edges[7] = 32'd2;          edges[8] = 32'hFFFF_FFFE;  // -7, -2
        edges[9] = 32'd100;
        repeat (2) @(negedge clk);
        rst_n = 1;
        // every pair of edge values and op: covers x/0, INT_MIN/-1, signs of -7/2
        for (k = 0; k < 4; k = k + 1)
            for (i = 0; i < 100; i = i + 1)
                run_one(k, edges[i / 10], edges[i % 10]);
	        // Additional directed edge cases for G2-NS14

        // DIV: signed division, truncation toward zero
        run_one(2'd0, 32'd7,          32'd2);          //  7 / 2 =  3
        run_one(2'd0, 32'hFFFF_FFF9,  32'd2);          // -7 / 2 = -3
        run_one(2'd0, 32'd7,          32'hFFFF_FFFE);  //  7 / -2 = -3
        run_one(2'd0, 32'hFFFF_FFF9,  32'hFFFF_FFFE);  // -7 / -2 = 3
        run_one(2'd0, 32'h8000_0000,  32'd1);          // INT_MIN / 1
        run_one(2'd0, 32'h8000_0000,  32'd2);          // INT_MIN / 2
        run_one(2'd0, 32'h7FFF_FFFF,  32'd2);          // INT_MAX / 2

        // DIVU: unsigned division
        run_one(2'd1, 32'hFFFF_FFFF,  32'd2);
        run_one(2'd1, 32'h8000_0000,  32'h7FFF_FFFF);
        run_one(2'd1, 32'h7FFF_FFFF,  32'h8000_0000);

        // REM: signed remainder
        run_one(2'd2, 32'hFFFF_FFF9,  32'd2);          // -7 % 2 = -1
        run_one(2'd2, 32'd7,          32'hFFFF_FFFE);  //  7 % -2 = 1
        run_one(2'd2, 32'hFFFF_FFF9,  32'hFFFF_FFFE);  // -7 % -2 = -1
        run_one(2'd2, 32'h8000_0000,  32'hFFFF_FFFF);  // INT_MIN % -1 = 0

        // REMU: unsigned remainder
        run_one(2'd3, 32'hFFFF_FFFF,  32'd2);
        run_one(2'd3, 32'h8000_0000,  32'h7FFF_FFFF);
        run_one(2'd3, 32'h7FFF_FFFF,  32'h8000_0000);
        // random: mix of full-width and small divisors
        for (i = 0; i < 10000; i = i + 1)
            run_one({$random} % 4, $random, (i % 2) ? $random : ($random % 1000));

        $display("max latency %0d cycles (goal: <= 34)", max_lat);
        if (errors == 0 && max_lat <= 34) $display("TEST PASSED (%0d checks, latency %0d)", checks, max_lat);
        else                              $display("TEST FAILED: %0d errors, latency %0d", errors, max_lat);
        $finish;
    end
endmodule
