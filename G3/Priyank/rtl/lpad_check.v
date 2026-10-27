// lpad_check.v - landing-pad check for indirect jumps (block C8, goal tier)
// Owner: Priyank (G3)
//
// The shadow stack protects RETURNS (backward edges). Function pointers are
// the other way to hijack a program (forward edges): if an attacker changes a
// function pointer, an indirect jump goes somewhere the programmer never meant.
//
// Zicfilp's idea: every legal target of an indirect jump starts with a marker
// instruction, `lpad`, encoded as `auipc x0, label` (it does nothing). After an
// indirect jump, the NEXT instruction executed must be an lpad, otherwise it
// is a violation.
//
//   expect  : set when an indirect jump/call commits, cleared by the next
//             real instruction
//   fail    : that next instruction is not an lpad
module lpad_check (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        ex_valid,
    input  wire [31:0] ex_instr,
    input  wire        needs_lpad,     // from callret_detect
    input  wire        freeze,         // ShieldV is freezing this cycle: keep state
    input  wire        trap,           // ShieldV traps to the handler: start fresh
    output wire        fail
);
    reg expect_lpad;

    wire is_lpad = (ex_instr[6:0] == 7'b0010111) && (ex_instr[11:7] == 5'd0);

    assign fail = enable & ex_valid & expect_lpad & ~is_lpad;

    always @(posedge clk) begin
        if (!rst_n)                   expect_lpad <= 1'b0;
        else if (trap)                expect_lpad <= 1'b0;
        else if (ex_valid && !freeze) expect_lpad <= needs_lpad;
    end
endmodule
