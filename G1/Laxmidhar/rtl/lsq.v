// lsq.v - load/store queue, 8 entries (block A24, goal tier)
// Owner: Laxmidhar (G1)
//
// Every load and store gets an entry in program order (a circular queue, like
// the reorder buffer). The queue enforces the memory rules of an
// out-of-order core:
//
//   stores : write memory only at COMMIT (the core takes the head entry), so
//            a store on a wrong path can never change memory. As soon as the
//            address and data are known the store reports "done" to the ROB.
//   loads  : may go early, out of order, but only when it is safe:
//            * every OLDER store already knows its address, and
//            * none of those older stores writes the same 32-bit word.
//            If an older store does, the load waits until that store has
//            committed and left the queue (no store-to-load forwarding:
//            simpler, and still correct).
//            Loads from I/O (address 0x1xxx_xxxx: UART status, counters,
//            switches) wait until they are the oldest instruction in the
//            whole machine, so they read the device exactly when the
//            in-order program would.
//
// Entries leave from the head when the ROB commits them (pop).
// Addresses are base + offset, computed in each entry (one adder each).
module lsq #(
    parameter N     = 8,
    parameter PTR_W = 3,
    parameter TAG_W = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             flush,
    // dispatch
    input  wire             in_valid,
    input  wire             in_store,
    input  wire [2:0]       in_funct3,
    input  wire [31:0]      in_imm,
    input  wire [TAG_W-1:0] in_tag,
    input  wire             in_rb,          // base register (rs1) ready / value / tag
    input  wire [31:0]      in_vb,
    input  wire [TAG_W-1:0] in_qb,
    input  wire             in_rd,          // store data (rs2) ready / value / tag
    input  wire [31:0]      in_vd,
    input  wire [TAG_W-1:0] in_qd,
    output wire             full,
    // common data bus
    input  wire             cdb_valid,
    input  wire [TAG_W-1:0] cdb_tag,
    input  wire [31:0]      cdb_value,
    // a store became complete (to the ROB)
    output wire             sr_valid,
    output wire [TAG_W-1:0] sr_tag,
    output wire [31:0]      sr_addr,
    // load issue (to the data bus); the core answers ld_go when the bus is free
    input  wire [TAG_W-1:0] rob_head_tag,
    output wire             ld_req,
    output wire [31:0]      ld_addr,
    output wire [2:0]       ld_funct3,
    output wire [TAG_W-1:0] ld_tag,
    input  wire             ld_go,
    // head (oldest memory instruction), written to memory at commit if a store
    output wire             head_valid,
    output wire             head_store,
    output wire [31:0]      head_addr,
    output wire [31:0]      head_data,
    output wire [2:0]       head_funct3,
    input  wire             pop
);
    reg [N-1:0]     busy, st, rb, rdy_d, issued, sdone;
    reg [2:0]       f3   [0:N-1];
    reg [31:0]      imm  [0:N-1];
    reg [31:0]      vb   [0:N-1];
    reg [31:0]      vd   [0:N-1];
    reg [TAG_W-1:0] qb   [0:N-1];
    reg [TAG_W-1:0] qd   [0:N-1];
    reg [TAG_W-1:0] tag  [0:N-1];

    reg [PTR_W-1:0] head, tail;
    reg [PTR_W:0]   count;

    wire [31:0] addr [0:N-1];
    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : g_addr
            assign addr[g] = vb[g] + imm[g];
        end
    endgenerate

    assign full        = (count == N);
    assign head_valid  = (count != 0);
    assign head_store  = st[head];
    assign head_addr   = addr[head];
    assign head_data   = vd[head];
    assign head_funct3 = f3[head];

    // ---- a store whose address and data are known ----
    reg             sr_found;
    reg [PTR_W-1:0] sr_i;
    integer i, k, j;
    always @* begin
        sr_found = 1'b0; sr_i = 0;
        for (i = N - 1; i >= 0; i = i - 1)
            if (busy[i] && st[i] && rb[i] && rdy_d[i] && !sdone[i]) begin sr_found = 1'b1; sr_i = i; end
    end
    assign sr_valid = sr_found & ~flush;
    assign sr_tag   = tag[sr_i];
    assign sr_addr  = addr[sr_i];

    // ---- the oldest load that may safely go now ----
    reg             ld_found, blocked;
    reg [PTR_W-1:0] ld_i, idx, idx2;
    always @* begin
        ld_found = 1'b0; ld_i = 0;
        for (k = N - 1; k >= 0; k = k - 1) begin
            idx = head + k;
            if (busy[idx] && !st[idx] && !issued[idx] && rb[idx]) begin
                blocked = 1'b0;
                for (j = 0; j < N; j = j + 1) begin
                    idx2 = head + j;
                    if (j < k && busy[idx2] && st[idx2] &&
                        (!rb[idx2] || addr[idx2][31:2] == addr[idx][31:2]))
                        blocked = 1'b1;
                end
                if (addr[idx][31:28] != 4'h0 && !(k == 0 && tag[idx] == rob_head_tag))
                    blocked = 1'b1;                       // I/O: only as the oldest instruction
                if (!blocked) begin ld_found = 1'b1; ld_i = idx; end
            end
        end
    end
    assign ld_req    = ld_found & ~flush;
    assign ld_addr   = addr[ld_i];
    assign ld_funct3 = f3[ld_i];
    assign ld_tag    = tag[ld_i];

    wire do_in  = in_valid & ~full & ~flush;
    wire do_pop = pop & head_valid;

    always @(posedge clk) begin
        if (!rst_n || flush) begin
            busy <= 0; issued <= 0; sdone <= 0; rb <= 0; rdy_d <= 0;
            head <= 0; tail <= 0; count <= 0;
        end else begin
            for (i = 0; i < N; i = i + 1) begin
                if (busy[i] && !rb[i]    && cdb_valid && qb[i] == cdb_tag) begin rb[i]    <= 1'b1; vb[i] <= cdb_value; end
                if (busy[i] && !rdy_d[i] && cdb_valid && qd[i] == cdb_tag) begin rdy_d[i] <= 1'b1; vd[i] <= cdb_value; end
            end
            if (sr_found)          sdone[sr_i]  <= 1'b1;
            if (ld_found && ld_go) issued[ld_i] <= 1'b1;
            if (do_pop) begin
                busy[head] <= 1'b0;
                head <= head + 1'b1;
            end
            if (do_in) begin
                busy[tail] <= 1'b1;  st[tail] <= in_store;  f3[tail] <= in_funct3;
                imm[tail]  <= in_imm; tag[tail] <= in_tag;
                rb[tail]   <= in_rb;  vb[tail] <= in_vb;  qb[tail] <= in_qb;
                rdy_d[tail]<= in_rd;  vd[tail] <= in_vd;  qd[tail] <= in_qd;
                issued[tail] <= 1'b0; sdone[tail] <= 1'b0;
                tail <= tail + 1'b1;
            end
            count <= count + do_in - do_pop;
        end
    end
endmodule
