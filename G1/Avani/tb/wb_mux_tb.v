// wb_mux_tb.v - testbench for wb_mux.v (block A13)
// Owner: Avani (G1)
`timescale 1ns/1ps
module wb_mux_tb;
    reg  [1:0]  sel;
    wire [31:0] wd;
    integer errors = 0;

    wb_mux dut (.sel(sel), .alu_y(32'h1111_1111), .load_data(32'h2222_2222),
                .link(32'h3333_3333), .m_result(32'h4444_4444), .wd(wd));

    initial begin
        sel = 2'b00; #1; if (wd !== 32'h1111_1111) begin errors = errors + 1; $display("FAIL ALU"); end
        sel = 2'b01; #1; if (wd !== 32'h2222_2222) begin errors = errors + 1; $display("FAIL load"); end
        sel = 2'b10; #1; if (wd !== 32'h3333_3333) begin errors = errors + 1; $display("FAIL link"); end
        sel = 2'b11; #1; if (wd !== 32'h4444_4444) begin errors = errors + 1; $display("FAIL M-unit"); end
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
