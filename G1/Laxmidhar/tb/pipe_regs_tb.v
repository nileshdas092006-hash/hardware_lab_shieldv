// pipe_regs_tb.v - pipeline registers: stall holds, flush makes a bubble (block A8)
// Owner: Laxmidhar (G1)
`timescale 1ns/1ps
module pipe_regs_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, stall = 0, flush = 0, bubble = 0;
    reg [31:0] pc = 0;
    integer errors = 0;

    wire        q_valid, w_valid;
    wire [31:0] q_pc, q_instr, q_rs1, q_rs2, q_imm, w_pc;
    wire [14:0] q_ctrl;

    pipe_ifid_ex u_p1 (.clk(clk), .rst_n(rst_n), .stall(stall), .flush(flush),
        .d_valid(1'b1), .d_pc(pc), .d_instr(32'h0000_0013 + pc), .d_rs1_val(pc), .d_rs2_val(~pc),
        .d_imm(32'd0), .d_ctrl(15'h7ABC),
        .q_valid(q_valid), .q_pc(q_pc), .q_instr(q_instr), .q_rs1_val(q_rs1), .q_rs2_val(q_rs2),
        .q_imm(q_imm), .q_ctrl(q_ctrl));

    pipe_ex_wb u_p2 (.clk(clk), .rst_n(rst_n), .bubble(bubble),
        .d_valid(q_valid), .d_pc(q_pc), .d_instr(q_instr), .d_rd(5'd1), .d_reg_write(1'b1),
        .d_wb_sel(2'b00), .d_alu_y(q_rs1), .d_m_result(32'd0), .d_funct3(3'd0),
        .q_valid(w_valid), .q_pc(w_pc), .q_instr(), .q_rd(), .q_reg_write(), .q_wb_sel(),
        .q_alu_y(), .q_m_result(), .q_funct3());

    task expect(input cond, input [255:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL %0s (q_pc=%h q_valid=%b w_pc=%h w_valid=%b)",
                                                       what, q_pc, q_valid, w_pc, w_valid); end
    endtask

    initial begin
        @(negedge clk); expect(!q_valid && !w_valid, "reset clears valid");
        rst_n = 1; pc = 32'h100;
        @(negedge clk); expect(q_valid && q_pc == 32'h100, "IF/ID -> EX");
        pc = 32'h104;
        @(negedge clk); expect(q_pc == 32'h104 && w_valid && w_pc == 32'h100, "EX -> MEM/WB");
        // stall: EX holds 0x104 even though IF/ID now offers 0x108
        stall = 1; bubble = 1; pc = 32'h108;
        @(negedge clk); expect(q_pc == 32'h104 && q_valid, "stall holds EX");
        expect(!w_valid, "bubble in MEM/WB during stall");
        @(negedge clk); expect(q_pc == 32'h104, "stall holds for many cycles");
        stall = 0; bubble = 0;
        @(negedge clk); expect(q_pc == 32'h108 && w_pc == 32'h104 && w_valid, "release: both move on once");
        // flush: the instruction behind a taken branch becomes a bubble
        flush = 1; pc = 32'h10C;
        @(negedge clk); expect(!q_valid, "flush makes a bubble");
        flush = 0; pc = 32'h200;
        @(negedge clk); expect(q_valid && q_pc == 32'h200 && !w_valid, "branch target valid, bubble never retires");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
