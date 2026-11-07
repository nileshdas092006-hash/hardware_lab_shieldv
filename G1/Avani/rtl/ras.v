// ras.v - return-address stack predictor (block A20, goal tier)
// Owner: Avani (G1)
//
// Predicts where a return will go: a call pushes pc+4, a return pops it.
// This is a PREDICTOR inside the out-of-order core's front end. It is not
// ShieldV's shadow stack: it can be wrong (it is overwritten when it
// overflows, and it guesses ahead of execution), and a wrong guess only costs
// time. ShieldV's shadow stack is the security check.
//
// Two copies, like the branch history:
//   spec   : changed at fetch (the front end runs ahead)
//   commit : changed when the call / return really commits
// On a flush, spec is restored from commit (restore = 1), including the
// commit that happens in that same cycle.
// Circular: when more than DEPTH calls are nested, the oldest entry is
// overwritten (the prediction for that deep return will simply miss).
module ras #(
    parameter DEPTH = 8,
    parameter PTR_W = 3
) (
    input  wire        clk,
    input  wire        rst_n,
    // fetch side
    input  wire        push,
    input  wire        pop,                  // push + pop = replace the top (coroutine swap)
    input  wire [31:0] push_addr,
    output wire [31:0] top,
    output wire        empty,
    // commit side
    input  wire        c_push,
    input  wire        c_pop,
    input  wire [31:0] c_push_addr,
    input  wire        restore
);
    reg [31:0]      s_mem [0:DEPTH-1];
    reg [31:0]      c_mem [0:DEPTH-1];
    reg [PTR_W-1:0] s_ptr, c_ptr;            // points at the next free slot
    reg [PTR_W:0]   s_cnt, c_cnt;            // entries held (saturates at DEPTH)

    // Index of the newest entry. It is a named PTR_W-bit wire on purpose: after
    // 8 nested calls s_ptr wraps to 0, and 0 - 1 must wrap to DEPTH-1. Written
    // inline as s_mem[s_ptr - 1'b1], some simulators (Icarus 11) work the index
    // out in 32 bits, get -1, read outside the array and the predicted PC is X.
    wire [PTR_W-1:0] s_top_i = s_ptr - 1'b1;

    assign top   = s_mem[s_top_i];
    assign empty = (s_cnt == 0);

    // next state of the commit copy (restore must include this cycle's commit)
    reg [PTR_W-1:0] c_ptr_n, c_wi;
    reg [PTR_W:0]   c_cnt_n;
    reg             c_wr;
    always @* begin
        c_ptr_n = c_ptr; c_cnt_n = c_cnt; c_wr = 1'b0; c_wi = c_ptr;
        if (c_push && c_pop) begin                       // replace the top
            c_wr = 1'b1; c_wi = c_ptr - 1'b1;
            if (c_cnt == 0) begin c_wi = c_ptr; c_ptr_n = c_ptr + 1'b1; c_cnt_n = 1; end
        end else if (c_push) begin
            c_wr = 1'b1; c_wi = c_ptr; c_ptr_n = c_ptr + 1'b1;
            if (c_cnt != DEPTH) c_cnt_n = c_cnt + 1'b1;
        end else if (c_pop && c_cnt != 0) begin
            c_ptr_n = c_ptr - 1'b1; c_cnt_n = c_cnt - 1'b1;
        end
    end

    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            s_ptr <= 0; s_cnt <= 0; c_ptr <= 0; c_cnt <= 0;
            for (i = 0; i < DEPTH; i = i + 1) begin s_mem[i] <= 32'd0; c_mem[i] <= 32'd0; end
        end else begin
            // commit copy
            if (c_wr) c_mem[c_wi] <= c_push_addr;
            c_ptr <= c_ptr_n; c_cnt <= c_cnt_n;
            // speculative copy
            if (restore) begin
                for (i = 0; i < DEPTH; i = i + 1) s_mem[i] <= c_mem[i];
                if (c_wr) s_mem[c_wi] <= c_push_addr;
                s_ptr <= c_ptr_n; s_cnt <= c_cnt_n;
            end else if (push && pop) begin
                if (s_cnt == 0) begin s_mem[s_ptr] <= push_addr; s_ptr <= s_ptr + 1'b1; s_cnt <= 1; end
                else            s_mem[s_top_i] <= push_addr;
            end else if (push) begin
                s_mem[s_ptr] <= push_addr; s_ptr <= s_ptr + 1'b1;
                if (s_cnt != DEPTH) s_cnt <= s_cnt + 1'b1;
            end else if (pop && s_cnt != 0) begin
                s_ptr <= s_ptr - 1'b1; s_cnt <= s_cnt - 1'b1;
            end
        end
    end
endmodule
