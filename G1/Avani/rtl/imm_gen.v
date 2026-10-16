// imm_gen.v - immediate generator (block A4)
// Owner: Avani (G1)
//
// RISC-V hides a constant ("immediate") inside many instructions. Its bits are
// scattered differently for each format so that the sign bit is ALWAYS
// instr[31] and the register fields never move. This block gathers the bits
// back together and sign-extends to 32 bits.
//
//   format | used by                      | value
//   I      | addi, loads, jalr            | instr[31:20]
//   S      | stores                       | instr[31:25] , instr[11:7]
//   B      | branches (always even)       | instr[31], instr[7], instr[30:25], instr[11:8], 0
//   U      | lui, auipc                   | instr[31:12], 12 zeros
//   J      | jal (always even)            | instr[31], instr[19:12], instr[20], instr[30:21], 0
module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;

    wire [6:0] opcode = instr[6:0];

    always @* begin
        imm = 32'd0;
        case (opcode)
            OP_IMM, OP_LOAD, OP_JALR:
                imm = {{20{instr[31]}}, instr[31:20]};
            OP_STORE:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            OP_BRANCH:
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            OP_LUI, OP_AUIPC:
                imm = {instr[31:12], 12'd0};
            OP_JAL:
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            default:
                imm = 32'd0;
        endcase
    end
endmodule
