// perf_counters_tb.v - cycle, instret, call and return counters (block B9)
// Owner: Nilesh (G2)
`timescale 1ns/1ps
module perf_counters_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg        rst_n = 0, frozen = 0, retire = 0, ev_call = 0, ev_ret = 0;
    reg        ev_branch = 0, ev_mispredict = 0, ev_violation = 0;
    reg  [7:0] rd_addr = 0;
    wire [31:0] rd_data;
    integer errors = 0, i;

    perf_counters #(.CORE_ID(32'd1)) dut (.clk(clk), .rst_n(rst_n), .frozen(frozen), .retire(retire),
                       .ev_call(ev_call), .ev_ret(ev_ret), .ev_branch(ev_branch),
                       .ev_mispredict(ev_mispredict), .ev_violation(ev_violation),
                       .rd_addr(rd_addr), .rd_data(rd_data));

    task expect_reg(input [7:0] a, input [31:0] want, input [127:0] what);
        begin
            rd_addr = a; #1;
            if (rd_data !== want) begin errors = errors + 1; $display("FAIL %0s = %0d expected %0d", what, rd_data, want); end
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        // 100 cycles: retire every other cycle, 10 calls, 7 returns
        for (i = 0; i < 100; i = i + 1) begin
            retire = (i % 2 == 0); ev_call = (i < 10); ev_ret = (i >= 50 && i < 57);
            ev_branch = (i % 4 == 0); ev_mispredict = (i % 20 == 0); ev_violation = (i == 99);
            @(negedge clk);
        end
        retire = 0; ev_call = 0; ev_ret = 0; ev_branch = 0; ev_mispredict = 0; ev_violation = 0;
        frozen = 1;                          // stop counting while the registers are read
        expect_reg(8'h20, 32'd100, "CYCLE");
        expect_reg(8'h24, 32'd50,  "INSTRET");
        expect_reg(8'h28, 32'd10,  "CALLS");
        expect_reg(8'h2C, 32'd7,   "RETS");
        expect_reg(8'h50, 32'd25,  "BRANCHES");
        expect_reg(8'h54, 32'd5,   "MISPRED");
        expect_reg(8'h58, 32'd1,   "VIOL");
        expect_reg(8'h5C, 32'd1,   "CORE_ID");
        // frozen: nothing counts
        frozen = 1; retire = 1;
        repeat (20) @(negedge clk);
        expect_reg(8'h20, 32'd100, "CYCLE while frozen");
        expect_reg(8'h24, 32'd50,  "INSTRET while frozen");
        ev_violation = 1; @(negedge clk); ev_violation = 0;
        expect_reg(8'h58, 32'd2,   "VIOL counts while frozen");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
