// led_reg.v - memory-mapped LED register (block B5)
// Owner: Nilesh (G2)
//
// A store to 0x1000_0000 sets the 16 board LEDs: bit i lights LED i.
//     *(volatile unsigned *)0x10000000 = 0x00FF;   // right 8 LEDs on
// The simplest proof of life, and the HACKED pattern in the demo.
module led_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [31:0] wdata,
    output reg  [15:0] led
);
    always @(posedge clk) begin
        if (!rst_n)  led <= 16'h0000;
        else if (we) led <= wdata[15:0];
    end
endmodule
