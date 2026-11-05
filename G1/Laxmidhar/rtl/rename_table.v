// rename_table.v - register alias table, RAT (block A21, goal tier)
// Owner: Laxmidhar (G1)
//
// For each architectural register x1..x31 the table says where its newest
// value will come from:
//   busy = 0 : the value is in the register file (it has committed)
//   busy = 1 : the value is still being computed by the instruction in
//              reorder-buffer entry `tag`
// This is register renaming: two instructions that both write x5 get two
// different tags, so a later reader waits for the right one, and the
// writers do not have to wait for each other (no WAR / WAW stalls).
//
//   dispatch : the new instruction writing rd claims rd     (busy=1, tag=new)
//   commit   : the committing instruction frees rd, but only if no younger
//              instruction has claimed rd since (tag still matches)
//   flush    : everything younger than the commit point is thrown away, so
//              every register reads from the register file again
// Dispatch wins over commit when both touch the same register in one cycle.
module rename_table #(
    parameter TAG_W = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             flush,
    // two read ports (the dispatching instruction's sources)
    input  wire [4:0]       ra1,
    input  wire [4:0]       ra2,
    output wire             busy1,
    output wire [TAG_W-1:0] tag1,
    output wire             busy2,
    output wire [TAG_W-1:0] tag2,
    // dispatch: rd now comes from ROB entry d_tag
    input  wire             d_we,
    input  wire [4:0]       d_rd,
    input  wire [TAG_W-1:0] d_tag,
    // commit: ROB entry c_tag wrote rd into the register file
    input  wire             c_en,
    input  wire [4:0]       c_rd,
    input  wire [TAG_W-1:0] c_tag
);
    reg             busy [0:31];
    reg [TAG_W-1:0] tag  [0:31];

    assign busy1 = (ra1 != 5'd0) && busy[ra1];
    assign busy2 = (ra2 != 5'd0) && busy[ra2];
    assign tag1  = tag[ra1];
    assign tag2  = tag[ra2];

    integer i;
    always @(posedge clk) begin
        if (!rst_n || flush) begin
            for (i = 0; i < 32; i = i + 1) busy[i] <= 1'b0;
        end else begin
            if (c_en && c_rd != 5'd0 && busy[c_rd] && tag[c_rd] == c_tag &&
                !(d_we && d_rd == c_rd))
                busy[c_rd] <= 1'b0;
            if (d_we && d_rd != 5'd0)
                busy[d_rd] <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n)                          for (i = 0; i < 32; i = i + 1) tag[i] <= {TAG_W{1'b0}};
        else if (!flush && d_we && d_rd != 5'd0) tag[d_rd] <= d_tag;
    end
endmodule
