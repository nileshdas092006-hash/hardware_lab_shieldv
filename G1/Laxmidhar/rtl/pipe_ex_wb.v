// pipe_ex_wb.v - pipeline register between EX and MEM/WB (block A8, part 2)
// Owner: Laxmidhar (G1)
//
// Carries everything the last stage needs to finish an instruction:
// where to write (rd), what to write (ALU result, M-unit result, or the link
// value pc+4) and, for loads, how to cut the word the bus returns.
//
//   bubble = 1 : load valid = 0. Used while EX is stalled, so the stalled
//                instruction is not written back twice.
module pipe_ex_wb (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bubble,
    input  wire        d_valid,
    input  wire [31:0] d_pc,
    input  wire [31:0] d_instr,
    input  wire [4:0]  d_rd,
    input  wire        d_reg_write,
    input  wire [1:0]  d_wb_sel,
    input  wire [31:0] d_alu_y,
    input  wire [31:0] d_m_result,
    input  wire [2:0]  d_funct3,
    output reg         q_valid,
    output reg  [31:0] q_pc,
    output reg  [31:0] q_instr,
    output reg  [4:0]  q_rd,
    output reg         q_reg_write,
    output reg  [1:0]  q_wb_sel,
    output reg  [31:0] q_alu_y,
    output reg  [31:0] q_m_result,
    output reg  [2:0]  q_funct3
);
    always @(posedge clk) begin
        if (!rst_n) begin
            q_valid     <= 1'b0;
            q_pc        <= 32'd0;
            q_instr     <= 32'h0000_0013;
            q_rd        <= 5'd0;
            q_reg_write <= 1'b0;
            q_wb_sel    <= 2'b00;
            q_alu_y     <= 32'd0;
            q_m_result  <= 32'd0;
            q_funct3    <= 3'd0;
        end else begin
            q_valid     <= d_valid & ~bubble;
            q_pc        <= d_pc;
            q_instr     <= d_instr;
            q_rd        <= d_rd;
            q_reg_write <= d_reg_write;
            q_wb_sel    <= d_wb_sel;
            q_alu_y     <= d_alu_y;
            q_m_result  <= d_m_result;
            q_funct3    <= d_funct3;
        end
    end
endmodule
