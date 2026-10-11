// uart_tx_tb.v - decodes the serial line back into bytes (block B8)
// Owner: Nilesh (G2)
//
// The testbench acts like the laptop: it waits for a start bit, samples each
// bit in the middle of its time slot, and rebuilds the byte. Every byte sent
// must come back unchanged, and the stop bit must be 1.
`timescale 1ns/1ps
module uart_tx_tb;
    localparam CLK_HZ = 50_000_000, BAUD = 115_200;
    localparam integer CPB = CLK_HZ / BAUD;            // clocks per bit = 434

    reg clk = 0;
    always #10 clk = ~clk;
    reg       rst_n = 0, start = 0;
    reg [7:0] data;
    wire      tx, busy;
    integer   errors = 0, i, n_rx = 0;

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) dut (.clk(clk), .rst_n(rst_n), .start(start),
                                               .data(data), .tx(tx), .busy(busy));

    reg [7:0] sent [0:15];
    reg [7:0] rx;

    // receiver model
    initial begin : receiver
        integer b;
        forever begin
            @(negedge tx);                               // start bit begins
            repeat (CPB / 2) @(posedge clk);
            if (tx !== 1'b0) begin errors = errors + 1; $display("FAIL start bit glitch"); end
            for (b = 0; b < 8; b = b + 1) begin
                repeat (CPB) @(posedge clk);
                rx[b] = tx;                              // LSB first
            end
            repeat (CPB) @(posedge clk);
            if (tx !== 1'b1) begin errors = errors + 1; $display("FAIL stop bit is not 1"); end
            if (rx !== sent[n_rx]) begin
                errors = errors + 1;
                $display("FAIL byte %0d: received %h expected %h", n_rx, rx, sent[n_rx]);
            end
            n_rx = n_rx + 1;
        end
    end

    initial begin
        sent[0] = "S"; sent[1] = "H"; sent[2] = "I"; sent[3] = "E"; sent[4] = "L"; sent[5] = "D";
        sent[6] = 8'h00; sent[7] = 8'hFF; sent[8] = 8'hA5; sent[9] = 8'h5A;
        repeat (3) @(negedge clk);
        if (tx !== 1'b1) begin errors = errors + 1; $display("FAIL line not idle-high after reset"); end
        rst_n = 1;
        for (i = 0; i < 10; i = i + 1) begin
            @(negedge clk); while (busy) @(negedge clk);   // what software does: poll busy
            data = sent[i]; start = 1;
            @(negedge clk); start = 0;
            if (!busy) begin errors = errors + 1; $display("FAIL busy not set"); end
            data = 8'h00; start = 1;                       // a write while busy is ignored
            @(negedge clk); start = 0;
        end
        while (busy) @(negedge clk);
        repeat (CPB) @(negedge clk);
        if (n_rx != 10) begin errors = errors + 1; $display("FAIL received %0d bytes, expected 10", n_rx); end
        if (errors == 0) $display("TEST PASSED (%0d bytes at %0d baud)", n_rx, BAUD);
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
