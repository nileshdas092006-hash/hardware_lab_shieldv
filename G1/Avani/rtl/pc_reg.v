// pc_reg.v - program counter and next-PC mux (block A1)
// Owner: Avani (G1)
//
// The PC holds the address of the instruction being fetched. Every cycle the
// next PC is chosen, highest priority first:
//   1. hold     : a stall or a ShieldV freeze -> stay on the same instruction
//   2. trap     : ShieldV trap mode            -> jump to the security handler
//   3. redirect : taken branch / jal / jalr    -> jump to target
//   4. otherwise: pc + 4
//
// pc_next is exported because the instruction RAM is synchronous: we give it
// the address we are ABOUT to fetch, so the instruction is ready exactly when
// the PC register takes that value. That is how fetch and decode share one stage.
module pc_reg #(
    parameter [31:0] RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        hold,
    input  wire        trap,
    input  wire [31:0] trap_pc,
    input  wire        redirect,
    input  wire [31:0] target,
    output reg  [31:0] pc,
    output reg  [31:0] pc_next
);
    always @* begin
        if (!rst_n)        pc_next = RESET_PC;
        else if (hold)     pc_next = pc;
        else if (trap)     pc_next = trap_pc;
        else if (redirect) pc_next = target;
        else               pc_next = pc + 32'd4;
    end

    always @(posedge clk) begin
        if (!rst_n) pc <= RESET_PC;
        else        pc <= pc_next;
    end
endmodule
