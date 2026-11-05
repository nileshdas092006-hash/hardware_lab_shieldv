// cdb_arbiter.v - common data bus arbiter (block A25, goal tier)
// Owner: Laxmidhar (G1)
//
// The common data bus (CDB) is the one broadcast wire bundle on which a
// finished result is announced: "the instruction with tag T produced value V".
// Every reservation station, the load/store queue, the reorder buffer and
// the dispatch logic listen to it at the same time.
//
// Only one result fits on the bus per cycle. Each execution unit parks its
// result in a holding register; this arbiter picks one per cycle, fixed
// priority:
//   1. load unit  (L)  - loads are the most likely to have instructions
//                        waiting on them
//   2. M-unit     (M)  - MUL / DIV results
//   3. ALU/branch (A)
// A unit whose result was not granted keeps it and does not start new work
// until it has been granted (the core checks the grant).
// aux carries a branch/jump target (ALU) or a load address (L);
// taken / mispred are only meaningful for branches and jumps.
module cdb_arbiter #(
    parameter TAG_W = 4
) (
    input  wire             l_valid,
    input  wire [TAG_W-1:0] l_tag,
    input  wire [31:0]      l_value,
    input  wire [31:0]      l_aux,
    input  wire             m_valid,
    input  wire [TAG_W-1:0] m_tag,
    input  wire [31:0]      m_value,
    input  wire             a_valid,
    input  wire [TAG_W-1:0] a_tag,
    input  wire [31:0]      a_value,
    input  wire [31:0]      a_aux,
    input  wire             a_taken,
    input  wire             a_mispred,
    output wire             l_grant,
    output wire             m_grant,
    output wire             a_grant,
    output wire             cdb_valid,
    output wire [TAG_W-1:0] cdb_tag,
    output wire [31:0]      cdb_value,
    output wire [31:0]      cdb_aux,
    output wire             cdb_taken,
    output wire             cdb_mispred
);
    assign l_grant = l_valid;
    assign m_grant = m_valid & ~l_valid;
    assign a_grant = a_valid & ~l_valid & ~m_valid;

    assign cdb_valid   = l_valid | m_valid | a_valid;
    assign cdb_tag     = l_grant ? l_tag   : m_grant ? m_tag   : a_tag;
    assign cdb_value   = l_grant ? l_value : m_grant ? m_value : a_value;
    assign cdb_aux     = l_grant ? l_aux   : m_grant ? 32'd0   : a_aux;
    assign cdb_taken   = a_grant & a_taken;
    assign cdb_mispred = a_grant & a_mispred;
endmodule
