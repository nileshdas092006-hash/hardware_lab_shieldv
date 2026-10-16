// decoder.v - instruction decoder and control unit (block A3)
// Owner: Avani (G1)
//
// Looks at one 32-bit instruction and decides what every other block should
// do with it. This is the ONLY place where an instruction's meaning is
// decided, so a bug here silently turns one instruction into another.
//
//  field  | bits     | meaning
//  opcode | [6:0]    | instruction family (load, store, branch, ...)
//  rd     | [11:7]   | destination register
//  funct3 | [14:12]  | which operation inside the family
//  rs1    | [19:15]  | first source register
//  rs2    | [24:20]  | second source register
//  funct7 | [31:25]  | extra operation bits (sub vs add, sra vs srl, M-extension)
//
// wb_sel says what gets written into rd at the end of the pipeline:
//   00 = ALU result, 01 = load data, 10 = pc+4 (link for jal/jalr), 11 = M-unit result
module decoder (
    input  wire [31:0] instr,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output wire [2:0]  funct3,
    output reg  [3:0]  alu_op,
    output reg         alu_src_a_pc,   // 1: ALU input a = pc   (auipc)
    output reg         alu_src_b_imm,  // 1: ALU input b = imm  (I-type, loads, stores, lui, auipc)
    output reg         reg_write,
    output reg  [1:0]  wb_sel,
    output reg         is_load,
    output reg         is_store,
    output reg         is_branch,
    output reg         is_jal,
    output reg         is_jalr,
    output reg         is_mop,         // RV32M multiply/divide
    output reg         illegal
);
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_REG    = 7'b0110011;
    localparam OP_FENCE  = 7'b0001111;
    localparam OP_SYSTEM = 7'b1110011;

    localparam WB_ALU  = 2'b00;
    localparam WB_LOAD = 2'b01;
    localparam WB_LINK = 2'b10;
    localparam WB_MUL  = 2'b11;

    wire [6:0] opcode = instr[6:0];
    wire [6:0] funct7 = instr[31:25];

    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];

    always @* begin
        // defaults: a harmless "do nothing" instruction
        alu_op        = 4'b0000;
        alu_src_a_pc  = 1'b0;
        alu_src_b_imm = 1'b0;
        reg_write     = 1'b0;
        wb_sel        = WB_ALU;
        is_load       = 1'b0;
        is_store      = 1'b0;
        is_branch     = 1'b0;
        is_jal        = 1'b0;
        is_jalr       = 1'b0;
        is_mop        = 1'b0;
        illegal       = 1'b0;

        case (opcode)
            OP_LUI: begin
                alu_op = 4'b1001; alu_src_b_imm = 1'b1; reg_write = 1'b1;
            end
            OP_AUIPC: begin
                alu_op = 4'b0000; alu_src_a_pc = 1'b1; alu_src_b_imm = 1'b1; reg_write = 1'b1;
            end
            OP_JAL: begin
                is_jal = 1'b1; reg_write = 1'b1; wb_sel = WB_LINK;
            end
            OP_JALR: begin
                is_jalr = 1'b1; reg_write = 1'b1; wb_sel = WB_LINK;
                illegal = (funct3 != 3'b000);
            end
            OP_BRANCH: begin
                is_branch = 1'b1;
                illegal   = (funct3 == 3'b010) || (funct3 == 3'b011);
            end
            OP_LOAD: begin
                is_load = 1'b1; alu_src_b_imm = 1'b1; reg_write = 1'b1; wb_sel = WB_LOAD;
                illegal = (funct3 == 3'b011) || (funct3 == 3'b110) || (funct3 == 3'b111);
            end
            OP_STORE: begin
                is_store = 1'b1; alu_src_b_imm = 1'b1;
                illegal  = (funct3 > 3'b010);
            end
            OP_IMM: begin
                alu_src_b_imm = 1'b1; reg_write = 1'b1;
                // only the shift-right family uses bit 30 (srai vs srli)
                alu_op = {(funct3 == 3'b101) ? instr[30] : 1'b0, funct3};
            end
            OP_REG: begin
                reg_write = 1'b1;
                if (funct7 == 7'b0000001) begin
                    is_mop = 1'b1; wb_sel = WB_MUL;
                end else begin
                    alu_op  = {instr[30], funct3};
                    illegal = !((funct7 == 7'b0000000) ||
                                (funct7 == 7'b0100000 && (funct3 == 3'b000 || funct3 == 3'b101)));
                end
            end
            OP_FENCE, OP_SYSTEM: begin
                // fence, ecall, ebreak, csr*: treated as no-ops on this bare-metal core
            end
            default: illegal = 1'b1;
        endcase

        if (illegal) begin
            // an unknown instruction must not change anything
            reg_write = 1'b0; is_load = 1'b0; is_store = 1'b0; is_branch = 1'b0;
            is_jal = 1'b0; is_jalr = 1'b0; is_mop = 1'b0;
        end
    end
endmodule
