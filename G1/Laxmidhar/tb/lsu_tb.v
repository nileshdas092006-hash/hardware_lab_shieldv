// lsu_tb.v - every load/store width at every byte offset (block A12)
// Owner: Laxmidhar (G1)
`timescale 1ns/1ps
module lsu_tb;
    reg  [2:0]  st_f3, ld_f3;
    reg  [1:0]  st_off, ld_off;
    reg  [31:0] st_data, rdata;
    reg         st_en;
    wire [3:0]  wstrb;
    wire [31:0] wdata, load_data;
    integer errors = 0, checks = 0, off;

    lsu dut (.st_funct3(st_f3), .st_offset(st_off), .st_data(st_data), .st_en(st_en),
             .wstrb(wstrb), .wdata(wdata),
             .ld_funct3(ld_f3), .ld_offset(ld_off), .rdata(rdata), .load_data(load_data));

    // apply wstrb/wdata to a word, as the RAM would
    function [31:0] merge(input [31:0] old, input [31:0] d, input [3:0] s);
        merge = {s[3] ? d[31:24] : old[31:24], s[2] ? d[23:16] : old[23:16],
                 s[1] ? d[15:8]  : old[15:8],  s[0] ? d[7:0]   : old[7:0]};
    endfunction

    task check(input [31:0] got, input [31:0] want, input [127:0] what);
        begin
            checks = checks + 1;
            if (got !== want) begin errors = errors + 1; $display("FAIL %0s: got %h expected %h", what, got, want); end
        end
    endtask

    initial begin
        st_en = 1; st_data = 32'hCAFE_BABE;
        // sb at every offset: only that byte changes
        for (off = 0; off < 4; off = off + 1) begin
            st_f3 = 3'b000; st_off = off; #1;
            check(merge(32'h0000_0000, wdata, wstrb), 32'h0000_00BE << (8 * off), "sb");
        end
        // sh at offsets 0 and 2
        st_f3 = 3'b001; st_off = 0; #1; check(merge(32'h1111_1111, wdata, wstrb), 32'h1111_BABE, "sh off 0");
        st_off = 2; #1;                 check(merge(32'h1111_1111, wdata, wstrb), 32'hBABE_1111, "sh off 2");
        // sw
        st_f3 = 3'b010; st_off = 0; #1; check(merge(32'h1111_1111, wdata, wstrb), 32'hCAFE_BABE, "sw");
        check({28'd0, wstrb}, 32'hF, "sw strobes");
        // not a store: no strobes
        st_en = 0; #1; check({28'd0, wstrb}, 32'h0, "no store");

        // loads from the word 0x80FF_7F01 (bytes: 01 7F FF 80)
        rdata = 32'h80FF_7F01;
        ld_f3 = 3'b000; ld_off = 0; #1; check(load_data, 32'h0000_0001, "lb +0");
        ld_off = 1; #1;                 check(load_data, 32'h0000_007F, "lb +1");
        ld_off = 2; #1;                 check(load_data, 32'hFFFF_FFFF, "lb +2 sign-extends");
        ld_off = 3; #1;                 check(load_data, 32'hFFFF_FF80, "lb +3");
        ld_f3 = 3'b100; ld_off = 2; #1; check(load_data, 32'h0000_00FF, "lbu +2 zero-extends");
        ld_off = 3; #1;                 check(load_data, 32'h0000_0080, "lbu +3");
        ld_f3 = 3'b001; ld_off = 0; #1; check(load_data, 32'h0000_7F01, "lh +0");
        ld_off = 2; #1;                 check(load_data, 32'hFFFF_80FF, "lh +2 sign-extends");
        ld_f3 = 3'b101; ld_off = 2; #1; check(load_data, 32'h0000_80FF, "lhu +2");
        ld_f3 = 3'b010; ld_off = 0; #1; check(load_data, 32'h80FF_7F01, "lw");

        if (errors == 0) $display("TEST PASSED (%0d checks)", checks);
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
