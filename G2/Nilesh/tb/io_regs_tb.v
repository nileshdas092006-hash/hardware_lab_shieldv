// io_regs_tb.v - LED register, switch synchroniser and reset synchroniser (B5, B6, B10)
// Owner: Nilesh (G2)
`timescale 1ns/1ps
module io_regs_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    integer errors = 0;

    // LED register
    reg         rst_n = 0, we = 0;
    reg  [31:0] wdata = 0;
    wire [15:0] led;
    led_reg u_led (.clk(clk), .rst_n(rst_n), .we(we), .wdata(wdata), .led(led));

    // switch synchroniser
    reg  [15:0] sw_raw = 0;
    wire [15:0] sw;
    switch_sync u_sw (.clk(clk), .sw_raw(sw_raw), .sw(sw));

    // reset synchroniser
    reg  arst_n = 0;
    wire srst_n;
    rst_sync u_rst (.clk(clk), .arst_n(arst_n), .rst_n(srst_n));

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s", what); end
    endtask

    initial begin
        @(negedge clk); expect(led == 16'h0, "LEDs off in reset");
        rst_n = 1;
        we = 1; wdata = 32'hDEAD_00FF;
        @(negedge clk); we = 0; expect(led == 16'h00FF, "LED register takes the low 16 bits");
        wdata = 32'h1234;
        @(negedge clk); expect(led == 16'h00FF, "LEDs hold without a write");

        // a switch change shows up after exactly two clock edges
        #3 sw_raw = 16'h0001;                     // change between edges, like a real switch
        @(posedge clk); #1 expect(sw == 16'h0000, "not visible after 1 edge");
        @(posedge clk); #1 expect(sw == 16'h0001, "visible after 2 edges");

        // reset: asserts immediately, releases only after two clock edges
        @(negedge clk); expect(srst_n == 1'b0, "reset held while button pressed");
        #2 arst_n = 1;
        @(posedge clk); #1 expect(srst_n == 1'b0, "reset still on after 1 edge");
        @(posedge clk); #1 expect(srst_n == 1'b1, "reset released after 2 edges");
        #2 arst_n = 0; #1 expect(srst_n == 1'b0, "reset asserts without waiting for a clock");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
