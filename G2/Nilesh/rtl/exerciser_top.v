// exerciser_top.v - board bring-up design: I/O only, no CPU (milestone M2)
// Owner: Nilesh (G2)
//
// Build with:  make fpga TOP=exerciser_top
// Expected on the board:
//   * LEDs follow the switches (updated twice a second)
//   * the display counts up in hex
//   * a serial terminal at 115200 baud prints "SHIELDV OK" twice a second
module exerciser_top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire [15:0] SW,
    output wire [15:0] LED,
    output wire        LED16_G,
    output wire        LED17_R,
    output wire        CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0]  AN,
    output wire        UART_RXD_OUT
);
    wire clk, rst_n;
    clk_rst u_clk (.clk100(CLK100MHZ), .btn_rst_n(CPU_RESETN), .clk(clk), .rst_n(rst_n));

    wire [15:0] sw;
    switch_sync #(.W(16)) u_sw (.clk(clk), .sw_raw(SW), .sw(sw));

    wire        io_we, uart_busy;
    wire [7:0]  io_addr;
    wire [31:0] io_wdata;
    bus_exerciser u_ex (.clk(clk), .rst_n(rst_n), .sw(sw), .uart_busy(uart_busy),
                        .io_we(io_we), .io_addr(io_addr), .io_wdata(io_wdata));

    led_reg u_led (.clk(clk), .rst_n(rst_n), .we(io_we && io_addr == 8'h00), .wdata(io_wdata), .led(LED));

    reg [31:0] seg_value;
    always @(posedge clk) begin
        if (!rst_n)                         seg_value <= 32'd0;
        else if (io_we && io_addr == 8'h04) seg_value <= io_wdata;
    end
    wire [6:0] seg;
    seg7_driver u_seg (.clk(clk), .rst_n(rst_n), .value(seg_value), .seg(seg), .dp(DP), .an(AN));
    assign {CG, CF, CE, CD, CC, CB, CA} = seg;

    uart_tx u_uart (.clk(clk), .rst_n(rst_n), .start(io_we && io_addr == 8'h10),
                    .data(io_wdata[7:0]), .tx(UART_RXD_OUT), .busy(uart_busy));

    assign LED16_G = rst_n;
    assign LED17_R = 1'b0;
endmodule
