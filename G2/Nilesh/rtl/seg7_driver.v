// seg7_driver.v - 8-digit 7-segment display driver (block B7)
// Owner: Nilesh (G2)
//
// The 8 digits on the Nexys A7 share the same 7 segment wires (CA..CG).
// Only one digit is switched on at a time (through its anode AN0..AN7), and
// we cycle through all 8 fast enough (about 1 kHz per digit) that the eye
// sees a steady 8-digit number.
//
// Both segments and anodes are ACTIVE LOW on this board: 0 = on.
//
//      a
//     ---
//  f | g | b       seg[6:0] = {g, f, e, d, c, b, a}
//     ---
//  e |   | c
//     ---
//      d
module seg7_driver #(
    parameter REFRESH_BITS = 16          // 50 MHz / 2^16 = ~760 Hz per digit
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] value,            // 8 hex digits, digit 7 on the left
    output reg  [6:0]  seg,              // {g,f,e,d,c,b,a}, active low
    output wire        dp,
    output reg  [7:0]  an                // active low
);
    reg [REFRESH_BITS+2:0] cnt;
    always @(posedge clk) begin
        if (!rst_n) cnt <= 0;
        else        cnt <= cnt + 1'b1;
    end

    wire [2:0] digit = cnt[REFRESH_BITS+2:REFRESH_BITS];
    wire [3:0] nib   = value >> {digit, 2'b00};

    always @* begin
        an = ~(8'b0000_0001 << digit);
        case (nib)                       //  gfedcba (1 = lit, inverted below)
            4'h0: seg = ~7'b0111111;
            4'h1: seg = ~7'b0000110;
            4'h2: seg = ~7'b1011011;
            4'h3: seg = ~7'b1001111;
            4'h4: seg = ~7'b1100110;
            4'h5: seg = ~7'b1101101;
            4'h6: seg = ~7'b1111101;
            4'h7: seg = ~7'b0000111;
            4'h8: seg = ~7'b1111111;
            4'h9: seg = ~7'b1101111;
            4'hA: seg = ~7'b1110111;
            4'hB: seg = ~7'b1111100;
            4'hC: seg = ~7'b0111001;
            4'hD: seg = ~7'b1011110;
            4'hE: seg = ~7'b1111001;
            default: seg = ~7'b1110001;  // F
        endcase
    end

    assign dp = 1'b1;                    // decimal points off
endmodule
