// bus_decoder.v - address decoder for the data bus (block B4, interface IF-2)
// Owner: Nilesh (G2)
//
// Every load or store from the core carries an address. This block looks at
// the address and sends the access to exactly one place (the memory map):
//
//   0x0001_0000 - 0x0001_3FFF  data RAM (16 KB)
//   0x1000_0000 - 0x1000_00FF  I/O registers (LEDs, display, switches, UART,
//                              counters, ShieldV); io_addr = low byte
//   anything else              ignored on write, reads return 0
//
// Read data must arrive in the NEXT cycle (IF-2). The data RAM already
// behaves like that; for I/O we register the value here. sel_q remembers
// where last cycle's read went, so the right answer is chosen.
module bus_decoder (
    input  wire        clk,
    input  wire        rst_n,
    // from the core
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    input  wire        we,
    input  wire        re,
    output wire [31:0] rdata,
    // data RAM
    output wire        dmem_en,
    output wire [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_rdata,
    // I/O
    output wire        io_we,
    output wire [7:0]  io_addr,
    output wire [31:0] io_wdata,
    input  wire [31:0] io_rdata          // combinational read of io_addr
);
    wire hit_dmem = (addr[31:14] == 18'h00004);     // 0x0001_0000 .. 0x0001_3FFF
    wire hit_io   = (addr[31:8]  == 24'h100000);    // 0x1000_0000 .. 0x1000_00FF

    assign dmem_en    = hit_dmem & (we | re);
    assign dmem_wstrb = (hit_dmem & we) ? wstrb : 4'b0000;

    assign io_we    = hit_io & we;
    assign io_addr  = addr[7:0];
    assign io_wdata = wdata;

    localparam SEL_NONE = 2'd0;
    localparam SEL_DMEM = 2'd1;
    localparam SEL_IO   = 2'd2;

    reg [1:0]  sel_q;
    reg [31:0] io_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            sel_q <= SEL_NONE;
            io_q  <= 32'd0;
        end else begin
            sel_q <= !re ? SEL_NONE : hit_dmem ? SEL_DMEM : hit_io ? SEL_IO : SEL_NONE;
            io_q  <= io_rdata;
        end
    end

    assign rdata = (sel_q == SEL_DMEM) ? dmem_rdata :
                   (sel_q == SEL_IO)   ? io_q       : 32'd0;
endmodule
