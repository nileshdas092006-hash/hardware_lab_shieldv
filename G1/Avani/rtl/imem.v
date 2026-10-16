// imem.v - instruction RAM, 16 KB (block A2)
// Owner: Avani (G1)
//
// 4096 words of 32 bits, filled from a hex file (one 8-digit word per line)
// when the bitstream is built or the simulation starts. Synchronous read: the
// word at addr appears on rdata after the next rising edge. Vivado maps this
// to block RAM, which behaves identically in simulation and on the FPGA.
module imem #(
    parameter INIT_FILE = "imem.hex",
    parameter WORDS     = 4096
) (
    input  wire        clk,
    input  wire [31:0] addr,      // byte address; the low 2 bits are ignored
    output reg  [31:0] rdata
);
    (* ram_style = "block" *) reg [31:0] mem [0:WORDS-1];

    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'h0000_0013;  // nop (addi x0,x0,0)
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
        rdata = 32'h0000_0013;
    end

    always @(posedge clk) begin
        rdata <= mem[addr[13:2]];
    end
endmodule
