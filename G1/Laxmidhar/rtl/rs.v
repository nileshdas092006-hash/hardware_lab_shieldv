// rs.v - reservation station (block A23, goal tier)
// Owner: Laxmidhar (G1)
//
// A waiting room in front of an execution unit. A dispatched instruction
// sits here until both of its source operands are known, then it is sent
// ("issued") to the unit, even if older instructions are still waiting.
// That is the out-of-order part of Tomasulo's algorithm.
//
// Each operand is either
//   ready (r = 1) : its value v is here, or
//   waiting       : q is the tag of the instruction that will produce it.
// Every cycle each waiting operand watches the common data bus (CDB); when
// the CDB carries its tag, it copies the value and becomes ready.
//
// Issue picks the lowest-numbered entry with both operands ready; the
// execution unit says with `take` whether it accepted it this cycle.
// PW is the width of the unit-specific payload (opcode bits, immediate, ...).
module rs #(
    parameter N     = 4,
    parameter PW    = 8,
    parameter TAG_W = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             flush,
    // dispatch
    input  wire             in_valid,
    input  wire [PW-1:0]    in_payload,
    input  wire [TAG_W-1:0] in_tag,          // ROB entry of this instruction
    input  wire             in_r1,
    input  wire [31:0]      in_v1,
    input  wire [TAG_W-1:0] in_q1,
    input  wire             in_r2,
    input  wire [31:0]      in_v2,
    input  wire [TAG_W-1:0] in_q2,
    output wire             full,
    // common data bus
    input  wire             cdb_valid,
    input  wire [TAG_W-1:0] cdb_tag,
    input  wire [31:0]      cdb_value,
    // issue
    output wire             out_valid,
    output wire [PW-1:0]    out_payload,
    output wire [TAG_W-1:0] out_tag,
    output wire [31:0]      out_v1,
    output wire [31:0]      out_v2,
    input  wire             take
);
    reg [N-1:0]     busy, r1, r2;
    reg [PW-1:0]    pay [0:N-1];
    reg [TAG_W-1:0] tag [0:N-1];
    reg [31:0]      v1  [0:N-1];
    reg [31:0]      v2  [0:N-1];
    reg [TAG_W-1:0] q1  [0:N-1];
    reg [TAG_W-1:0] q2  [0:N-1];

    // first free entry, first ready entry
    reg       have_free, have_ready;
    reg [7:0] free_i, ready_i;
    integer i;
    always @* begin
        have_free = 1'b0; free_i = 0; have_ready = 1'b0; ready_i = 0;
        for (i = N - 1; i >= 0; i = i - 1) begin
            if (!busy[i])                   begin have_free  = 1'b1; free_i  = i; end
            if (busy[i] && r1[i] && r2[i])  begin have_ready = 1'b1; ready_i = i; end
        end
    end

    assign full        = ~have_free;
    assign out_valid   = have_ready;
    assign out_payload = pay[ready_i];
    assign out_tag     = tag[ready_i];
    assign out_v1      = v1[ready_i];
    assign out_v2      = v2[ready_i];

    wire do_in = in_valid & have_free & ~flush;

    always @(posedge clk) begin
        if (!rst_n || flush) begin
            busy <= 0; r1 <= 0; r2 <= 0;
        end else begin
            // wake-up: copy results from the CDB
            for (i = 0; i < N; i = i + 1) begin
                if (busy[i] && !r1[i] && cdb_valid && q1[i] == cdb_tag) begin r1[i] <= 1'b1; v1[i] <= cdb_value; end
                if (busy[i] && !r2[i] && cdb_valid && q2[i] == cdb_tag) begin r2[i] <= 1'b1; v2[i] <= cdb_value; end
            end
            if (take && have_ready) busy[ready_i] <= 1'b0;
            if (do_in) begin
                busy[free_i] <= 1'b1;
                pay[free_i]  <= in_payload;
                tag[free_i]  <= in_tag;
                r1[free_i]   <= in_r1;  v1[free_i] <= in_v1;  q1[free_i] <= in_q1;
                r2[free_i]   <= in_r2;  v2[free_i] <= in_v2;  q2[free_i] <= in_q2;
            end
        end
    end
endmodule
