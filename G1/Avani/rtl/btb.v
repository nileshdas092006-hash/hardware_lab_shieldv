// btb.v - branch target buffer for indirect jumps (block A19, goal tier)
// Owner: Avani (G1)
//
// A jalr's target comes from a register, so the front end cannot compute it
// while fetching. The BTB remembers, per jalr PC, where it jumped last time:
//   lookup : hit = an entry for this PC exists, target = its last target
//   update : at commit, write (PC, real target)
// Direct-mapped: entry = PC[IDX_W+1:2], the rest of the PC is the tag.
// Returns do not use the BTB; the return-address stack predicts them better.
// Conditional branches and jal compute their target from the instruction
// itself in the fetch cycle (our instruction RAM delivers the instruction in
// the same cycle as its PC), so they do not need the BTB.
module btb #(
    parameter IDX_W = 4                      // 16 entries
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] pc,
    output wire        hit,
    output wire [31:0] target,
    input  wire        upd_en,
    input  wire [31:0] upd_pc,
    input  wire [31:0] upd_target
);
    localparam N     = 1 << IDX_W;
    localparam TAG_W = 30 - IDX_W;

    reg             valid [0:N-1];
    reg [TAG_W-1:0] tag   [0:N-1];
    reg [31:0]      tgt   [0:N-1];

    wire [IDX_W-1:0] i_l = pc[IDX_W+1:2];
    wire [IDX_W-1:0] i_u = upd_pc[IDX_W+1:2];

    assign hit    = valid[i_l] && tag[i_l] == pc[31:IDX_W+2];
    assign target = tgt[i_l];

    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < N; i = i + 1) begin valid[i] <= 1'b0; tag[i] <= {TAG_W{1'b0}}; tgt[i] <= 32'd0; end
        end else if (upd_en) begin
            valid[i_u] <= 1'b1;
            tag[i_u]   <= upd_pc[31:IDX_W+2];
            tgt[i_u]   <= upd_target;
        end
    end
endmodule
