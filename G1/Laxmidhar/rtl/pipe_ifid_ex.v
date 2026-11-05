// pipe_ifid_ex.v - pipeline register between IF/ID and EX (block A8, part 1)
// Owner: Laxmidhar (G1)
//
// On every rising edge this register copies what the IF/ID stage produced
// (the decoded instruction and its register values) into the EX stage.
//
//   stall = 1 : keep the old contents (the EX instruction waits)
//   flush = 1 : load a BUBBLE, i.e. valid = 0. Used when a taken branch in EX
//               proves the instruction fetched behind it was the wrong one.
//
// The valid bit is what makes bubbles harmless: an instruction with valid = 0
// never writes a register, never touches memory and never pushes or pops the
// ShieldV shadow stack.
//
// ctrl is the packed control word from the decoder (see core_pipe.v).
module pipe_ifid_ex #(
    parameter CTRL_W = 15
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              stall,
    input  wire              flush,
    input  wire              d_valid,
    input  wire [31:0]       d_pc,
    input  wire [31:0]       d_instr,
    input  wire [31:0]       d_rs1_val,
    input  wire [31:0]       d_rs2_val,
    input  wire [31:0]       d_imm,
    input  wire [CTRL_W-1:0] d_ctrl,
    output reg               q_valid,
    output reg  [31:0]       q_pc,
    output reg  [31:0]       q_instr,
    output reg  [31:0]       q_rs1_val,
    output reg  [31:0]       q_rs2_val,
    output reg  [31:0]       q_imm,
    output reg  [CTRL_W-1:0] q_ctrl
);
    always @(posedge clk) begin
        if (!rst_n) begin
            q_valid   <= 1'b0;
            q_pc      <= 32'd0;
            q_instr   <= 32'h0000_0013;      // nop
            q_rs1_val <= 32'd0;
            q_rs2_val <= 32'd0;
            q_imm     <= 32'd0;
            q_ctrl    <= {CTRL_W{1'b0}};
        end else if (!stall) begin
            q_valid   <= d_valid & ~flush;
            q_pc      <= d_pc;
            q_instr   <= d_instr;
            q_rs1_val <= d_rs1_val;
            q_rs2_val <= d_rs2_val;
            q_imm     <= d_imm;
            q_ctrl    <= d_ctrl;
        end
    end
endmodule
