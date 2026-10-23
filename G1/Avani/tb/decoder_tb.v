// decoder_tb.v - table-driven testbench for decoder.v (block A3)
// Owner: Avani (G1)
//
// One encoding of each instruction family, checked against the expected
// control word. Control word layout (16 bits):
//   {alu_op[3:0], a_pc, b_imm, reg_write, wb_sel[1:0], load, store, branch, jal, jalr, mop, illegal}
`timescale 1ns/1ps
module decoder_tb;
    reg  [31:0] instr;
    wire [4:0]  rs1, rs2, rd;
    wire [2:0]  funct3;
    wire [3:0]  alu_op;
    wire        a_pc, b_imm, reg_write, is_load, is_store, is_branch, is_jal, is_jalr, is_mop, illegal;
    wire [1:0]  wb_sel;
    integer errors = 0, checks = 0;

    decoder dut (.instr(instr), .rs1(rs1), .rs2(rs2), .rd(rd), .funct3(funct3),
        .alu_op(alu_op), .alu_src_a_pc(a_pc), .alu_src_b_imm(b_imm), .reg_write(reg_write),
        .wb_sel(wb_sel), .is_load(is_load), .is_store(is_store), .is_branch(is_branch),
        .is_jal(is_jal), .is_jalr(is_jalr), .is_mop(is_mop), .illegal(illegal));

    wire [15:0] word = {alu_op, a_pc, b_imm, reg_write, wb_sel, is_load, is_store,
                        is_branch, is_jal, is_jalr, is_mop, illegal};

    //                         alu  a b w wb ld st br jl jr m  il
    task check(input [31:0] i, input [15:0] want, input [127:0] text);
        begin
            instr = i; #1; checks = checks + 1;
            if (word !== want) begin
                errors = errors + 1;
                $display("FAIL %0s (%h): got %b expected %b", text, i, word, want);
            end
        end
    endtask

    initial begin
        check(32'h0020_80B3, {4'b0000,1'b0,1'b0,1'b1,2'b00,7'b0000000}, "add x1,x1,x2");
        check(32'h4020_80B3, {4'b1000,1'b0,1'b0,1'b1,2'b00,7'b0000000}, "sub x1,x1,x2");
        check(32'h4020_D0B3, {4'b1101,1'b0,1'b0,1'b1,2'b00,7'b0000000}, "sra x1,x1,x2");
        check(32'h0020_F0B3, {4'b0111,1'b0,1'b0,1'b1,2'b00,7'b0000000}, "and x1,x1,x2");
        check(32'hFFF0_8093, {4'b0000,1'b0,1'b1,1'b1,2'b00,7'b0000000}, "addi x1,x1,-1");
        check(32'h4030_D093, {4'b1101,1'b0,1'b1,1'b1,2'b00,7'b0000000}, "srai x1,x1,3");
        check(32'h0030_D093, {4'b0101,1'b0,1'b1,1'b1,2'b00,7'b0000000}, "srli x1,x1,3");
        check(32'h4030_8093, {4'b0000,1'b0,1'b1,1'b1,2'b00,7'b0000000}, "addi with bit30 set is still add");
        check(32'h1234_50B7, {4'b1001,1'b0,1'b1,1'b1,2'b00,7'b0000000}, "lui");
        check(32'h0000_1097, {4'b0000,1'b1,1'b1,1'b1,2'b00,7'b0000000}, "auipc");
        check(32'hFFC1_2083, {4'b0000,1'b0,1'b1,1'b1,2'b01,7'b1000000}, "lw");
        check(32'h0011_2223, {4'b0000,1'b0,1'b1,1'b0,2'b00,7'b0100000}, "sw");
        check(32'h0020_8463, {4'b0000,1'b0,1'b0,1'b0,2'b00,7'b0010000}, "beq");
        check(32'h0080_00EF, {4'b0000,1'b0,1'b0,1'b1,2'b10,7'b0001000}, "jal x1");
        check(32'h0000_8067, {4'b0000,1'b0,1'b0,1'b1,2'b10,7'b0000100}, "ret (jalr x0)");
        check(32'h0220_80B3, {4'b0000,1'b0,1'b0,1'b1,2'b11,7'b0000010}, "mul");
        check(32'h0220_C0B3, {4'b0000,1'b0,1'b0,1'b1,2'b11,7'b0000010}, "div");
        check(32'h0000_0073, {4'b0000,1'b0,1'b0,1'b0,2'b00,7'b0000000}, "ecall = nop");
        check(32'h0FF0_000F, {4'b0000,1'b0,1'b0,1'b0,2'b00,7'b0000000}, "fence = nop");
        check(32'hFFFF_FFFF, {4'b0000,1'b0,1'b0,1'b0,2'b00,7'b0000001}, "illegal");
        check(32'h0000_3083, {4'b0000,1'b0,1'b1,1'b0,2'b01,7'b0000001}, "ld (RV64 only) is illegal");

        // register fields
        instr = 32'h00C5_8533; #1;                 // add x10, x11, x12
        if (rd !== 5'd10 || rs1 !== 5'd11 || rs2 !== 5'd12 || funct3 !== 3'd0) begin
            errors = errors + 1; $display("FAIL register fields");
        end

        if (errors == 0) $display("TEST PASSED (%0d checks)", checks);
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
