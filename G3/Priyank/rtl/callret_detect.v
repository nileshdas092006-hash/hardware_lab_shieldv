// callret_detect.v - call / return / indirect-jump detector (block C1)
// Owner: Priyank (G3)
//
// Classifies the instruction in EX using the same rules as the ratified RISC-V
// shadow-stack extension (Zicfiss). "Link registers" are x1 (ra) and x5 (t0).
//
//   instruction          | rd    | rs1   | meaning          | shadow stack
//   jal                  | link  |  -    | call             | push
//   jal                  | other |  -    | plain jump       | -
//   jalr                 | link  | other | indirect call    | push
//   jalr                 | other | link  | return           | pop + check
//   jalr                 | link  | link, rd != rs1 | coroutine swap | pop + check, then push
//   jalr                 | link  | link, rd == rs1 | call     | push
//   jalr                 | other | other | indirect jump    | -
//
// Indirect calls/jumps whose rs1 is not x1/x5/x7 must land on an `lpad`
// instruction when the landing-pad check (C8, goal tier) is enabled.
// x7 (t2) is exempt, as in the Zicfilp spec (it is used for software checks).
module callret_detect (
    input  wire [31:0] instr,
    output wire        is_call,      // push pc+4
    output wire        is_ret,       // pop and compare
    output wire        needs_lpad    // the target must be an lpad
);
    localparam OP_JAL  = 7'b1101111;
    localparam OP_JALR = 7'b1100111;

    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [4:0] rs1    = instr[19:15];

    wire is_jal  = (opcode == OP_JAL);
    wire is_jalr = (opcode == OP_JALR) && (instr[14:12] == 3'b000);

    wire rd_link  = (rd  == 5'd1) || (rd  == 5'd5);
    wire rs1_link = (rs1 == 5'd1) || (rs1 == 5'd5);

    assign is_call    = (is_jal & rd_link) | (is_jalr & rd_link);
    assign is_ret     = is_jalr & rs1_link & (~rd_link | (rd != rs1));
    assign needs_lpad = is_jalr & ~rs1_link & (rs1 != 5'd7);
endmodule
