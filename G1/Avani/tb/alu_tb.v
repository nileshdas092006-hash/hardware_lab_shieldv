// alu_tb.v - self-checking testbench for alu.v (block A6)
// Owner: Avani (G1)
//
// 1. Directed edge cases from golden/A6_alu.md (0, -1, INT_MIN, shift by 31)
// 2. 2000 random operand pairs for every operation, checked against a
//    reference model written independently below
`timescale 1ns/1ps
module alu_tb;
    reg  [31:0] a, b;
    reg  [3:0]  op;
    wire [31:0] y;
    integer errors = 0, checks = 0, i, k;

    alu dut (.a(a), .b(b), .op(op), .y(y));

    reg [3:0] ops [0:10];
    initial begin
        ops[0]=4'b0000; ops[1]=4'b1000; ops[2]=4'b0001; ops[3]=4'b0010; ops[4]=4'b0011;
        ops[5]=4'b0100; ops[6]=4'b0101; ops[7]=4'b1101; ops[8]=4'b0110; ops[9]=4'b0111;
        ops[10]=4'b1001;
    end

    // reference model
    function [31:0] model(input [31:0] x, input [31:0] z, input [3:0] o);
        reg signed [31:0] xs, zs;
        begin
            xs = x; zs = z;
            case (o)
                4'b0000: model = x + z;
                4'b1000: model = x - z;
                4'b0001: model = x << z[4:0];
                4'b0010: model = (xs < zs) ? 1 : 0;
                4'b0011: model = (x < z) ? 1 : 0;
                4'b0100: model = x ^ z;
                4'b0101: model = x >> z[4:0];
                4'b1101: model = xs >>> z[4:0];
                4'b0110: model = x | z;
                4'b0111: model = x & z;
                4'b1001: model = z;
                default: model = 0;
            endcase
        end
    endfunction

    task check(input [31:0] x, input [31:0] z, input [3:0] o, input [31:0] expect);
        begin
            a = x; b = z; op = o; #1;
            checks = checks + 1;
            if (y !== expect) begin
                errors = errors + 1;
                if (errors < 10) $display("FAIL op=%b a=%h b=%h got=%h expected=%h", o, x, z, y, expect);
            end
        end
    endtask

    initial begin
        // directed (golden table)
        check(32'd5,          32'd3,          4'b0000, 32'd8);
        check(32'hFFFF_FFFF,  32'd1,          4'b0000, 32'd0);           // -1 + 1 wraps to 0
        check(32'd3,          32'd5,          4'b1000, 32'hFFFF_FFFE);   // 3 - 5 = -2
        check(32'h8000_0000,  32'd1,          4'b1000, 32'h7FFF_FFFF);   // INT_MIN - 1 wraps
        check(32'd1,          32'd31,         4'b0001, 32'h8000_0000);   // shift by 31
        check(32'd1,          32'd32,         4'b0001, 32'd1);           // only 5 bits used
        check(32'hFFFF_FFFF,  32'd1,          4'b0010, 32'd1);           // -1 < 1 signed
        check(32'hFFFF_FFFF,  32'd1,          4'b0011, 32'd0);           // big > 1 unsigned
        check(32'h8000_0000,  32'd31,         4'b0101, 32'd1);           // srl
        check(32'h8000_0000,  32'd31,         4'b1101, 32'hFFFF_FFFF);   // sra copies sign
        check(32'hF0F0_0000,  32'h0FF0_1234,  4'b0110, 32'hFFF0_1234);
        check(32'hF0F0_0000,  32'h0FF0_1234,  4'b0111, 32'h00F0_0000);
        check(32'hAAAA_AAAA,  32'hFFFF_FFFF,  4'b0100, 32'h5555_5555);
        check(32'h1234_5678,  32'hABCD_E000,  4'b1001, 32'hABCD_E000);   // lui pass-through

        // random
        for (i = 0; i < 2000; i = i + 1)
            for (k = 0; k < 11; k = k + 1) begin
                a = $random; b = $random;
                check(a, b, ops[k], model(a, b, ops[k]));
            end

        if (errors == 0) $display("TEST PASSED (%0d checks)", checks);
        else             $display("TEST FAILED: %0d of %0d checks", errors, checks);
        $finish;
    end
endmodule
