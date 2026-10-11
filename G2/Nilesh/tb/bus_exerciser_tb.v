// bus_exerciser_tb.v - the board bring-up design prints "SHIELDV OK" (milestone M2)
// Owner: Nilesh (G2)
//
// Runs bus_exerciser + LED register + UART together (as in exerciser_top.v,
// without the clock manager) and decodes the serial line.
`timescale 1ns/1ps
module bus_exerciser_tb;
    localparam CPB = 10;                              // fast UART for simulation
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst_n = 0;
    wire        io_we, busy, tx;
    wire [7:0]  io_addr;
    wire [31:0] io_wdata;
    wire [15:0] led;
    integer errors = 0, n = 0, b;
    reg [7:0] rx;
    reg [8*12-1:0] text = 0;

    bus_exerciser #(.PERIOD(100)) u_ex (.clk(clk), .rst_n(rst_n), .sw(16'hA5C3), .uart_busy(busy),
                                       .io_we(io_we), .io_addr(io_addr), .io_wdata(io_wdata));
    led_reg u_led (.clk(clk), .rst_n(rst_n), .we(io_we && io_addr == 8'h00), .wdata(io_wdata), .led(led));
    uart_tx #(.CLK_HZ(CPB * 1000), .BAUD(1000)) u_uart (.clk(clk), .rst_n(rst_n),
        .start(io_we && io_addr == 8'h10), .data(io_wdata[7:0]), .tx(tx), .busy(busy));

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        while (n < 12) begin
            @(negedge tx);
            repeat (CPB / 2) @(posedge clk);
            for (b = 0; b < 8; b = b + 1) begin repeat (CPB) @(posedge clk); rx[b] = tx; end
            repeat (CPB) @(posedge clk);
            text = {text[8*11-1:0], rx};
            n = n + 1;
        end
        $display("received: %s", text[8*12-1:16]);
        if (text !== {"SHIELDV OK", 8'h0D, 8'h0A}) begin errors = errors + 1; $display("FAIL wrong text"); end
        if (led !== 16'hA5C3) begin errors = errors + 1; $display("FAIL LEDs do not follow switches: %h", led); end
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end

    initial begin #5_000_000; $display("TEST FAILED: timeout"); $finish; end
endmodule
