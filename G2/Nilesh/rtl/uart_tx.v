// uart_tx.v - UART transmitter, 8 data bits, no parity, 1 stop bit (block B8)
// Owner: Nilesh (G2)
//
// How one byte travels on the wire (idle level is 1):
//
//   idle  start  d0 d1 d2 d3 d4 d5 d6 d7  stop  idle
//   1111    0    .. data, LSB first ..      1   1111
//
// Each bit is held for CLK_HZ / BAUD clock cycles
// (50 MHz / 115200 = 434 cycles). The USB chip on the board turns this into
// a serial port on the laptop; open it at 115200 baud to read the output.
//
// Software writes a byte to UART_TX (0x1000_0010) and must wait while
// UART_STATUS bit 0 (busy) is 1. A write while busy is ignored.
module uart_tx #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115_200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] data,
    output reg        tx,
    output wire       busy
);
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;

    reg [15:0] clk_cnt;
    reg [3:0]  bit_idx;          // 0 = start bit, 1..8 = data, 9 = stop bit
    reg [9:0]  shifter;          // {stop, data[7:0], start}
    reg        active;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx <= 1'b1; active <= 1'b0; clk_cnt <= 16'd0; bit_idx <= 4'd0; shifter <= 10'h3FF;
        end else if (!active) begin
            tx <= 1'b1;
            if (start) begin
                shifter <= {1'b1, data, 1'b0};
                active  <= 1'b1;
                clk_cnt <= 16'd0;
                bit_idx <= 4'd0;
                tx      <= 1'b0;                 // start bit right away
            end
        end else begin
            if (clk_cnt == CLKS_PER_BIT - 1) begin
                clk_cnt <= 16'd0;
                if (bit_idx == 4'd9) begin
                    active <= 1'b0;              // stop bit done
                    tx     <= 1'b1;
                end else begin
                    bit_idx <= bit_idx + 4'd1;
                    tx      <= shifter[bit_idx + 4'd1];
                end
            end else begin
                clk_cnt <= clk_cnt + 16'd1;
            end
        end
    end

    assign busy = active;
endmodule
