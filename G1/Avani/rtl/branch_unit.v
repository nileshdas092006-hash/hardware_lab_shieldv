// branch_unit.v - branch compare, jump targets and link value (block A7)
// Owner: Avani (G1)
//
// Decides whether control flow leaves the straight line pc, pc+4, pc+8 ...
//   beq/bne/blt/bge/bltu/bgeu : compare rs1 and rs2, target = pc + imm
//   jal                       : always taken,          target = pc + imm
//   jalr                      : always taken,          target = (rs1 + imm) with bit 0 cleared
// link = pc + 4 is the return address a call saves in rd. ShieldV pushes this
// same value, and later checks a return's target against it.
module branch_unit (
    input  wire [31:0] pc,
    input  wire [31:0] rs1_val,
    input  wire [31:0] rs2_val,
    input  wire [31:0] imm,
    input  wire [2:0]  funct3,
    input  wire        is_branch,
    input  wire        is_jal,
    input  wire        is_jalr,
    output reg         taken,
    output wire [31:0] target,
    output wire [31:0] link
);
    reg cond;
    always @* begin
        cond = 1'b0;
        case (funct3)
            3'b000: cond = (rs1_val == rs2_val);                     // beq
            3'b001: cond = (rs1_val != rs2_val);                     // bne
            3'b100: cond = ($signed(rs1_val) <  $signed(rs2_val));   // blt
            3'b101: cond = ($signed(rs1_val) >= $signed(rs2_val));   // bge
            3'b110: cond = (rs1_val <  rs2_val);                     // bltu
            3'b111: cond = (rs1_val >= rs2_val);                     // bgeu
            default: cond = 1'b0;
        endcase
        taken = is_jal | is_jalr | (is_branch & cond);
    end

    wire [31:0] jalr_sum = rs1_val + imm;
    assign target = is_jalr ? {jalr_sum[31:1], 1'b0} : (pc + imm);
    assign link   = pc + 32'd4;
endmodule
