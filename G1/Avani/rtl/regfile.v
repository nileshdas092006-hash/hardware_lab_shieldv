// regfile.v - 32 x 32-bit register file (block A5)
// Owner: Avani (G1)
//
// Two read ports (rs1, rs2) that answer immediately (asynchronous read),
// one write port that writes on the rising clock edge.
//   * x0 always reads as zero and can never be written.
//   * "Write-through": if the instruction in MEM/WB writes register r in the
//     same cycle that the instruction in IF/ID reads r, the reader gets the
//     NEW value. Without this, an instruction two places behind a writer would
//     read a stale value.
// The array is not reset: it maps to LUTRAM, which has no reset input, and the
// RISC-V spec leaves registers undefined at reset anyway (crt0 sets sp itself).
//
// WRITE_THROUGH must be 0 in the single-cycle core: there the writer and the
// reader are the SAME instruction (addi x1, x1, 1), and write-through would
// feed the result straight back into its own input, a combinational loop.
module regfile #(
    parameter WRITE_THROUGH = 1
) (
    input  wire        clk,
    input  wire [4:0]  ra1,
    input  wire [4:0]  ra2,
    output wire [31:0] rd1,
    output wire [31:0] rd2,
    input  wire        we,
    input  wire [4:0]  wa,
    input  wire [31:0] wd
);
    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0;   // clean waveforms in simulation
    end

    always @(posedge clk) begin
        if (we && (wa != 5'd0))
            regs[wa] <= wd;
    end

    wire bypass1 = (WRITE_THROUGH != 0) && we && (wa == ra1);
    wire bypass2 = (WRITE_THROUGH != 0) && we && (wa == ra2);

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : bypass1 ? wd : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : bypass2 ? wd : regs[ra2];
endmodule
