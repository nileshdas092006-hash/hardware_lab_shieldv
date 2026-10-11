// seg7_driver_tb.v - digit select and segment patterns (block B7)
// Owner: Nilesh (G2)
//
// Shows 0x1234ABCD and checks, for each of the 8 digit slots, that exactly
// one anode is on (low) and the segments spell the right hex digit.
`timescale 1ns/1ps
module seg7_driver_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    wire [6:0] seg;
    wire [7:0] an;
    wire       dp;
    integer errors = 0, d, seen = 0;

    seg7_driver #(.REFRESH_BITS(3)) dut (.clk(clk), .rst_n(rst_n), .value(32'h1234_ABCD),
                                         .seg(seg), .dp(dp), .an(an));

    // expected {g,f,e,d,c,b,a}, active low
    function [6:0] pattern(input [3:0] n);
        case (n)
            4'h1: pattern = ~7'b0000110;  4'h2: pattern = ~7'b1011011;
            4'h3: pattern = ~7'b1001111;  4'h4: pattern = ~7'b1100110;
            4'hA: pattern = ~7'b1110111;  4'hB: pattern = ~7'b1111100;
            4'hC: pattern = ~7'b0111001;  4'hD: pattern = ~7'b1011110;
            default: pattern = 7'h7F;
        endcase
    endfunction

    reg [3:0] digits [0:7];
    initial begin
        digits[0] = 4'hD; digits[1] = 4'hC; digits[2] = 4'hB; digits[3] = 4'hA;
        digits[4] = 4'h4; digits[5] = 4'h3; digits[6] = 4'h2; digits[7] = 4'h1;
        repeat (2) @(negedge clk);
        rst_n = 1;
        repeat (8 * 8 * 2) begin
            @(negedge clk);
            for (d = 0; d < 8; d = d + 1)
                if (an == ~(8'b1 << d)) begin
                    seen = seen | (1 << d);
                    if (seg !== pattern(digits[d])) begin
                        errors = errors + 1;
                        $display("FAIL digit %0d shows %b expected %b", d, seg, pattern(digits[d]));
                    end
                end
            if (!(an == 8'hFE || an == 8'hFD || an == 8'hFB || an == 8'hF7 ||
                  an == 8'hEF || an == 8'hDF || an == 8'hBF || an == 8'h7F)) begin
                errors = errors + 1; $display("FAIL more or fewer than one anode on: %b", an);
            end
        end
        if (seen != 255) begin errors = errors + 1; $display("FAIL not every digit was driven (%b)", seen); end
        if (dp !== 1'b1) begin errors = errors + 1; $display("FAIL decimal point should be off"); end
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
