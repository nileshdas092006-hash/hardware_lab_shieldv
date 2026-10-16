// dmem.v - data RAM, 16 KB, byte-writable (block A15)
// Owner: Avani (G1)
//
// Holds global data, constant strings and the stack. The stack starts at the
// top (sp = 0x0001_4000) and grows down; saved return addresses live here,
// which is exactly what the attack overwrites.
//
// wstrb has one bit per byte lane, so sb/sh/sw change only the bytes they own.
// Read is synchronous: rdata is valid the cycle AFTER the address is given.
module dmem #(
    parameter INIT_FILE = "",
    parameter WORDS     = 4096
) (
    input  wire        clk,
    input  wire        en,
    input  wire [3:0]  wstrb,
    input  wire [31:0] addr,      // byte address; bits [13:2] select the word
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);
    (* ram_style = "block" *) reg [31:0] mem [0:WORDS-1];

    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'd0;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
        rdata = 32'd0;
    end

    wire [11:0] widx = addr[13:2];

    always @(posedge clk) begin
        if (en) begin
            if (wstrb[0]) mem[widx][7:0]   <= wdata[7:0];
            if (wstrb[1]) mem[widx][15:8]  <= wdata[15:8];
            if (wstrb[2]) mem[widx][23:16] <= wdata[23:16];
            if (wstrb[3]) mem[widx][31:24] <= wdata[31:24];
            rdata <= mem[widx];
        end
    end
endmodule
