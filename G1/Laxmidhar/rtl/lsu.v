// lsu.v - load/store unit (block A12)
// Owner: Laxmidhar (G1)
//
// Memory is organised in 32-bit words, but RISC-V can store and load single
// bytes (sb/lb/lbu) and half-words (sh/lh/lhu) too. This block does the byte
// shuffling in both directions. It is purely combinational.
//
// STORE side (used in EX, before the bus):
//   addr[1:0] says which byte inside the word is addressed.
//   sb at offset 2 -> wstrb = 0100, the byte is copied into lane 2 of wdata
//   sh at offset 2 -> wstrb = 1100
//   sw             -> wstrb = 1111
//
// LOAD side (used in MEM/WB, after the bus returns the whole word):
//   shift the addressed byte/half-word down to bit 0, then
//   lb/lh  : sign-extend (copy the top bit into the upper bits)
//   lbu/lhu: zero-extend
//
// Misaligned accesses (e.g. lw at an address that is not a multiple of 4) are
// not supported; the compiler never produces them for normal C code.
module lsu (
    // store side
    input  wire [2:0]  st_funct3,     // 000 sb, 001 sh, 010 sw
    input  wire [1:0]  st_offset,     // addr[1:0]
    input  wire [31:0] st_data,       // rs2 value
    input  wire        st_en,
    output reg  [3:0]  wstrb,
    output reg  [31:0] wdata,
    // load side
    input  wire [2:0]  ld_funct3,     // 000 lb, 001 lh, 010 lw, 100 lbu, 101 lhu
    input  wire [1:0]  ld_offset,
    input  wire [31:0] rdata,
    output reg  [31:0] load_data
);
    // ---------------- store ----------------
    always @* begin
        wstrb = 4'b0000;
        wdata = 32'd0;
        if (st_en) begin
            case (st_funct3[1:0])
                2'b00: begin                                  // sb
                    wdata = {4{st_data[7:0]}};
                    wstrb = 4'b0001 << st_offset;
                end
                2'b01: begin                                  // sh
                    wdata = {2{st_data[15:0]}};
                    wstrb = st_offset[1] ? 4'b1100 : 4'b0011;
                end
                default: begin                                // sw
                    wdata = st_data;
                    wstrb = 4'b1111;
                end
            endcase
        end
    end

    // ---------------- load ----------------
    wire [31:0] shifted = rdata >> {ld_offset, 3'b000};       // move addressed byte to bit 0

    always @* begin
        case (ld_funct3)
            3'b000:  load_data = {{24{shifted[7]}},  shifted[7:0]};   // lb
            3'b001:  load_data = {{16{shifted[15]}}, shifted[15:0]};  // lh
            3'b100:  load_data = {24'd0, shifted[7:0]};               // lbu
            3'b101:  load_data = {16'd0, shifted[15:0]};              // lhu
            default: load_data = rdata;                               // lw
        endcase
    end
endmodule
