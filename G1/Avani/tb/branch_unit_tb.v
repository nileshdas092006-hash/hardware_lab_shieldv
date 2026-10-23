// branch_unit_tb.v - testbench for branch_unit.v (block A7)
// Owner: Avani (G1)
`timescale 1ns/1ps
module branch_unit_tb;
    reg  [31:0] pc, rs1, rs2, imm;
    reg  [2:0]  f3;
    reg         br, jal, jalr;
    wire        taken;
    wire [31:0] target, link;
    integer errors = 0, checks = 0, i;

    branch_unit dut (.pc(pc), .rs1_val(rs1), .rs2_val(rs2), .imm(imm), .funct3(f3),
                     .is_branch(br), .is_jal(jal), .is_jalr(jalr),
                     .taken(taken), .target(target), .link(link));

    task check_taken(input [2:0] f, input [31:0] x, input [31:0] y, input want);
        begin
            br = 1; jal = 0; jalr = 0; f3 = f; rs1 = x; rs2 = y; #1; checks = checks + 1;
            if (taken !== want) begin
                errors = errors + 1;
                $display("FAIL funct3=%b rs1=%h rs2=%h taken=%b expected %b", f, x, y, taken, want);
            end
        end
    endtask

    function ref_cond(input [2:0] f, input [31:0] x, input [31:0] y);
        case (f)
            3'b000: ref_cond = (x == y);
            3'b001: ref_cond = (x != y);
            3'b100: ref_cond = ($signed(x) <  $signed(y));
            3'b101: ref_cond = ($signed(x) >= $signed(y));
            3'b110: ref_cond = (x <  y);
            3'b111: ref_cond = (x >= y);
            default: ref_cond = 0;
        endcase
    endfunction

    initial begin
        pc = 32'h100; imm = 32'h20;
        // signed vs unsigned edge: -1 vs 1
        check_taken(3'b100, 32'hFFFF_FFFF, 32'd1, 1);   // blt  -1 < 1
        check_taken(3'b110, 32'hFFFF_FFFF, 32'd1, 0);   // bltu 0xFFFFFFFF < 1 is false
        check_taken(3'b101, 32'h8000_0000, 32'h7FFF_FFFF, 0);  // bge INT_MIN >= INT_MAX false
        check_taken(3'b111, 32'h8000_0000, 32'h7FFF_FFFF, 1);  // bgeu
        check_taken(3'b000, 32'd7, 32'd7, 1);
        check_taken(3'b001, 32'd7, 32'd7, 0);
        check_taken(3'b101, 32'd5, 32'd5, 1);           // bge equal
        // random against the reference
        for (i = 0; i < 3000; i = i + 1) begin
            f3 = {$random} % 8;
            if (f3 == 3'b010 || f3 == 3'b011) f3 = 3'b000;
            rs1 = (i % 3 == 0) ? 32'd42 : $random;
            rs2 = (i % 3 == 0) ? 32'd42 : $random;
            check_taken(f3, rs1, rs2, ref_cond(f3, rs1, rs2));
        end
        // branch target and link
        br = 1; f3 = 3'b000; rs1 = 1; rs2 = 1; pc = 32'h200; imm = 32'hFFFF_FFF0; #1;
        if (target !== 32'h1F0 || link !== 32'h204) begin errors = errors + 1; $display("FAIL branch target/link"); end
        // jal: always taken, pc + imm
        br = 0; jal = 1; pc = 32'h100; imm = 32'h400; #1;
        if (!taken || target !== 32'h500) begin errors = errors + 1; $display("FAIL jal"); end
        // jalr: (rs1 + imm) with bit 0 cleared
        jal = 0; jalr = 1; rs1 = 32'h1001; imm = 32'h4; #1;
        if (!taken || target !== 32'h1004) begin errors = errors + 1; $display("FAIL jalr bit0 clear: %h", target); end
        rs1 = 32'h2000; imm = 32'hFFFF_FFFF; #1;            // 0x2000 - 1 = 0x1FFF -> 0x1FFE
        if (target !== 32'h1FFE) begin errors = errors + 1; $display("FAIL jalr negative imm: %h", target); end
        // nothing set: never taken
        jalr = 0; br = 0; #1;
        if (taken) begin errors = errors + 1; $display("FAIL taken with no branch"); end

        if (errors == 0) $display("TEST PASSED (%0d checks)", checks);
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
