// forward_unit.v - data forwarding (block A9)
// Owner: Laxmidhar (G1)
//
// Problem: in
//     add x5, x1, x2      <- now in MEM/WB, about to write x5
//     sub x6, x5, x3      <- now in EX, read x5 one cycle ago (old value!)
// the sub read the register file before the add wrote it.
//
// Fix: if the instruction in MEM/WB is valid, writes a register, that register
// is not x0, and it is the one EX wants, use MEM/WB's fresh value instead.
// This also covers loads (lw then add): our data memory answers in the
// MEM/WB stage, right behind EX, so load data can be forwarded the same way
// and the pipeline needs no load-use stall.
//
// Instructions further ahead have already written the register file, and the
// register file's write-through handles the one being written this cycle.
module forward_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,
    input  wire       wb_valid,
    input  wire       wb_reg_write,
    input  wire [4:0] wb_rd,
    output wire       fwd_a,          // 1: EX operand a takes the MEM/WB value
    output wire       fwd_b           // 1: EX operand b takes the MEM/WB value
);
    wire wb_writes = wb_valid & wb_reg_write & (wb_rd != 5'd0);

    assign fwd_a = wb_writes & (wb_rd == ex_rs1);
    assign fwd_b = wb_writes & (wb_rd == ex_rs2);
endmodule
