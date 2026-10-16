// alu.v - RV32I arithmetic and logic unit (block A6)
// Owner: Avani (G1)
//
// Purely combinational: y changes as soon as a, b or op change.
// op encoding = {funct7[5], funct3} for R-type instructions, so the decoder
// can pass the instruction bits straight through most of the time.
//
//   op    | operation            | used by
//   0000  | a + b                | add, addi, loads/stores (address), auipc, jal/jalr
//   1000  | a - b                | sub
//   0001  | a << b[4:0]          | sll, slli
//   0010  | signed   a < b       | slt, slti
//   0011  | unsigned a < b       | sltu, sltiu
//   0100  | a ^ b                | xor, xori
//   0101  | a >> b[4:0] logical  | srl, srli
//   1101  | a >> b[4:0] arith.   | sra, srai (copies the sign bit in from the left)
//   0110  | a | b                | or, ori
//   0111  | a & b                | and, andi
//   1001  | b                    | lui (pass the immediate through)
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] y
);
    localparam OP_ADD  = 4'b0000;
    localparam OP_SUB  = 4'b1000;
    localparam OP_SLL  = 4'b0001;
    localparam OP_SLT  = 4'b0010;
    localparam OP_SLTU = 4'b0011;
    localparam OP_XOR  = 4'b0100;
    localparam OP_SRL  = 4'b0101;
    localparam OP_SRA  = 4'b1101;
    localparam OP_OR   = 4'b0110;
    localparam OP_AND  = 4'b0111;
    localparam OP_PASSB= 4'b1001;

    always @* begin
        y = 32'd0;                                   // default: no latch
        case (op)
            OP_ADD:   y = a + b;
            OP_SUB:   y = a - b;
            OP_SLL:   y = a << b[4:0];
            OP_SLT:   y = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            OP_SLTU:  y = (a < b) ? 32'd1 : 32'd0;
            OP_XOR:   y = a ^ b;
            OP_SRL:   y = a >> b[4:0];
            OP_SRA:   y = $signed(a) >>> b[4:0];
            OP_OR:    y = a | b;
            OP_AND:   y = a & b;
            OP_PASSB: y = b;
            default:  y = 32'd0;
        endcase
    end
endmodule
