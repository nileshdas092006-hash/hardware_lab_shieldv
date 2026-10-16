// wb_mux.v - writeback multiplexer (block A13)
// Owner: Avani (G1)
//
// Chooses the value written into rd at the end of the pipeline:
//   00 ALU result    (add, lui, slt, ...)
//   01 load data     (lw, lb, ...; already aligned and sign-extended by the LSU)
//   10 pc + 4        (link value of jal/jalr: the return address)
//   11 M-unit result (mul, div, rem, ...)
module wb_mux (
    input  wire [1:0]  sel,
    input  wire [31:0] alu_y,
    input  wire [31:0] load_data,
    input  wire [31:0] link,
    input  wire [31:0] m_result,
    output reg  [31:0] wd
);
    always @* begin
        case (sel)
            2'b00:   wd = alu_y;
            2'b01:   wd = load_data;
            2'b10:   wd = link;
            default: wd = m_result;
        endcase
    end
endmodule
