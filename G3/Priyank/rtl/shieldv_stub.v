// shieldv_stub.v - stand-in ShieldV for early integration (rung I0/I1)
// Owner: Priyank (G3)
//
// Obeys IF-3 but never fires: no freeze, no trap. G1 builds and tests the
// core with this until the real shieldv.v joins at rung I4.
module shieldv_stub (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ex_valid,
    input  wire [31:0] ex_instr,
    input  wire [31:0] ex_pc,
    input  wire [31:0] ex_target,
    input  wire [31:0] ex_link,
    output wire        sh_freeze,
    output wire        sh_trap,
    output wire [31:0] sh_handler_pc
);
    assign sh_freeze     = 1'b0;
    assign sh_trap       = 1'b0;
    assign sh_handler_pc = 32'd0;
endmodule
