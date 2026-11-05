// cdb_arbiter_tb.v - one result per cycle on the common data bus (block A25)
// Owner: Laxmidhar (G1)
//
// Tries all 8 combinations of the three requesters (load, M-unit, ALU) and
// checks: exactly one grant when anyone asks, priority L > M > A, and the
// bus carries the granted unit's tag and value.
`timescale 1ns/1ps
module cdb_arbiter_tb;
    reg        l_valid, m_valid, a_valid;
    wire       l_grant, m_grant, a_grant, cdb_valid, cdb_taken, cdb_mispred;
    wire [3:0] cdb_tag;
    wire [31:0] cdb_value, cdb_aux;
    integer errors = 0, i;

    cdb_arbiter #(.TAG_W(4)) dut (
        .l_valid(l_valid), .l_tag(4'd1), .l_value(32'h11), .l_aux(32'h1000),
        .m_valid(m_valid), .m_tag(4'd2), .m_value(32'h22),
        .a_valid(a_valid), .a_tag(4'd3), .a_value(32'h33), .a_aux(32'h3000),
        .a_taken(1'b1), .a_mispred(1'b1),
        .l_grant(l_grant), .m_grant(m_grant), .a_grant(a_grant),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value), .cdb_aux(cdb_aux),
        .cdb_taken(cdb_taken), .cdb_mispred(cdb_mispred));

    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            {l_valid, m_valid, a_valid} = i; #1;
            if ((l_grant + m_grant + a_grant) != (i != 0)) begin errors = errors + 1; $display("FAIL grants for %b", i[2:0]); end
            if (cdb_valid != (i != 0))                      begin errors = errors + 1; $display("FAIL valid for %b", i[2:0]); end
            if (l_valid && !(l_grant && cdb_tag == 1 && cdb_value == 32'h11 && cdb_aux == 32'h1000 && !cdb_mispred))
                begin errors = errors + 1; $display("FAIL load priority for %b", i[2:0]); end
            if (!l_valid && m_valid && !(m_grant && cdb_tag == 2 && cdb_value == 32'h22))
                begin errors = errors + 1; $display("FAIL M-unit priority for %b", i[2:0]); end
            if (i == 1 && !(a_grant && cdb_tag == 3 && cdb_taken && cdb_mispred && cdb_aux == 32'h3000))
                begin errors = errors + 1; $display("FAIL ALU alone"); end
        end
        if (errors == 0) $display("TEST PASSED (8 request patterns)");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
