// bus_exerciser.v - a tiny "fake CPU" that tests the I/O on the board
// Owner: Nilesh (G2)
//
// Proves the LEDs, display, switches and UART work on the real board BEFORE
// any CPU exists (milestone M2). It talks to the peripherals through the same
// io_we / io_addr / io_wdata signals the bus decoder produces, so the
// peripherals cannot tell it apart from the real core.
//
// Every PERIOD cycles it:
//   1. copies the switches onto the LEDs   (store to 0x1000_0000)
//   2. shows a counter on the display      (store to 0x1000_0004)
//   3. prints "SHIELDV OK\r\n" over UART   (stores to 0x1000_0010, waiting
//                                           while UART_STATUS says busy)
module bus_exerciser #(
    parameter PERIOD = 25_000_000            // 0.5 s at 50 MHz
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sw,
    input  wire        uart_busy,
    output reg         io_we,
    output reg  [7:0]  io_addr,
    output reg  [31:0] io_wdata
);
    localparam MSG_LEN = 12;
    reg [7:0] msg [0:MSG_LEN-1];
    initial begin
        msg[0]="S"; msg[1]="H"; msg[2]="I"; msg[3]="E"; msg[4]="L"; msg[5]="D";
        msg[6]="V"; msg[7]=" "; msg[8]="O"; msg[9]="K"; msg[10]=8'h0D; msg[11]=8'h0A;
    end

    localparam S_WAIT = 3'd0, S_LED = 3'd1, S_SEG = 3'd2, S_CHAR = 3'd3, S_GAP = 3'd4, S_POLL = 3'd5;

    reg [2:0]  state;
    reg [31:0] timer;
    reg [31:0] count;
    reg [3:0]  idx;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_WAIT; timer <= 32'd0; count <= 32'd0; idx <= 4'd0;
            io_we <= 1'b0; io_addr <= 8'd0; io_wdata <= 32'd0;
        end else begin
            io_we <= 1'b0;
            case (state)
                S_WAIT: if (timer == PERIOD - 1) begin timer <= 32'd0; state <= S_LED; end
                        else timer <= timer + 32'd1;
                S_LED:  begin io_we <= 1'b1; io_addr <= 8'h00; io_wdata <= {16'd0, sw}; state <= S_SEG; end
                S_SEG:  begin io_we <= 1'b1; io_addr <= 8'h04; io_wdata <= count;
                              count <= count + 32'd1; idx <= 4'd0; state <= S_POLL; end
                S_POLL: if (!uart_busy) state <= S_CHAR;
                S_CHAR: begin
                    io_we <= 1'b1; io_addr <= 8'h10; io_wdata <= {24'd0, msg[idx]};
                    state <= S_GAP;
                end
                S_GAP:  begin                       // give busy one cycle to rise
                    if (idx == MSG_LEN - 1) state <= S_WAIT;
                    else begin idx <= idx + 4'd1; state <= S_POLL; end
                end
                default: state <= S_WAIT;
            endcase
        end
    end
endmodule
