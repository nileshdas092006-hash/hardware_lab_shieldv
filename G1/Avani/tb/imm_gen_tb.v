// imm_gen_tb.v - self-checking testbench for imm_gen.v (block A4)
// Owner: Avani (G1)
//
// Each encoding below was produced by the assembler; the expected value is
// the immediate objdump prints for it (see golden/A4_imm_gen.md).
`timescale 1ns/1ps
module imm_gen_tb;
    reg  [31:0] instr;
    wire [31:0] imm;
    integer errors = 0, checks = 0;

    imm_gen dut (.instr(instr), .imm(imm));

    task check(input [31:0] i, input [31:0] want, input [127:0] text);
        begin
            instr = i; #1; checks = checks + 1;
            if (imm !== want) begin
                errors = errors + 1;
                $display("FAIL %0s: instr=%h imm=%h expected=%h", text, i, imm, want);
            end
        end
    endtask

    initial begin
        check(32'h0010_0093, 32'd1,          "addi x1,x0,1");
        check(32'hFFF0_0093, 32'hFFFF_FFFF,  "addi x1,x0,-1");
        check(32'h8000_0093, 32'hFFFF_F800,  "addi x1,x0,-2048");
        check(32'h7FF0_0093, 32'h0000_07FF,  "addi x1,x0,2047");
        check(32'hFFC1_2083, 32'hFFFF_FFFC,  "lw x1,-4(x2)");
        check(32'h0011_2223, 32'd4,          "sw x1,4(x2)");
        check(32'hFE11_2E23, 32'hFFFF_FFFC,  "sw x1,-4(x2)");
        check(32'h0020_8463, 32'd8,          "beq x1,x2,+8");
        check(32'hFE20_8EE3, 32'hFFFF_FFFC,  "beq x1,x2,-4");
        check(32'h8000_0063, 32'hFFFF_F000,  "beq x0,x0,-4096");
        check(32'h1234_50B7, 32'h1234_5000,  "lui x1,0x12345");
        check(32'hFFFF_F097, 32'hFFFF_F000,  "auipc x1,0xfffff");
        check(32'h0080_00EF, 32'd8,          "jal x1,+8");
        check(32'hFFDF_F0EF, 32'hFFFF_FFFC,  "jal x1,-4");
        check(32'h8000_006F, 32'hFFF0_0000,  "jal x0,-1MB");
        check(32'h0040_80E7, 32'd4,          "jalr x1,4(x1)");
        check(32'h0000_8067, 32'd0,          "ret");
        check(32'h0020_80B3, 32'd0,          "add (R-type has none)");

        if (errors == 0) $display("TEST PASSED (%0d checks)", checks);
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
