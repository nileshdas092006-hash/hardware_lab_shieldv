// rob.v - reorder buffer, 16 entries (block A22, goal tier)
// Owner: Laxmidhar (G1)
//
// The out-of-order core executes instructions in whatever order their
// operands become ready, but the program must still SEE them finish in
// program order. The reorder buffer is a circular queue that restores order:
//
//   dispatch (tail) : every instruction gets the next entry, in program order
//   complete (CDB)  : when its result is ready, the entry is marked done
//   commit (head)   : only the OLDEST entry may finish, and only when done.
//                     Only then is the register file written, the store sent
//                     to memory, and ShieldV shown the call or return.
//
// Because nothing becomes permanent before commit, a wrong guess (a
// mispredicted branch, or a return ShieldV traps) is undone by simply
// throwing away every entry behind the head (flush).
//
// Per entry: pc, instruction, destination rd, result value, aux (jump/branch
// target, or the memory address of a load/store), and flags.
// The entry index is the instruction's "tag": the name its result is known
// by on the common data bus.
module rob #(
    parameter TAG_W  = 4,
    parameter N      = 16,
    parameter HIST_W = 8
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              flush,         // drop every entry (after this cycle's commit)
    // dispatch
    input  wire              alloc,
    input  wire [31:0]       a_pc,
    input  wire [31:0]       a_instr,
    input  wire [4:0]        a_rd,
    input  wire              a_regw,
    input  wire              a_mem,
    input  wire              a_store,
    input  wire              a_ctrl,        // branch, jal or jalr
    input  wire              a_cond,        // conditional branch
    input  wire [HIST_W-1:0] a_hist,        // branch history used to predict it
    input  wire              a_done,        // already complete (jal, lui, auipc, nop)
    input  wire [31:0]       a_value,
    input  wire [31:0]       a_aux,
    input  wire              a_taken,
    output wire [TAG_W-1:0]  alloc_tag,
    output wire              full,
    // completion from the common data bus
    input  wire              cdb_valid,
    input  wire [TAG_W-1:0]  cdb_tag,
    input  wire [31:0]       cdb_value,
    input  wire [31:0]       cdb_aux,
    input  wire              cdb_taken,
    input  wire              cdb_mispred,
    // completion of a store (address and data known; no register result)
    input  wire              st_valid,
    input  wire [TAG_W-1:0]  st_tag,
    input  wire [31:0]       st_addr,
    // operand read ports (dispatch looks up results not yet committed)
    input  wire [TAG_W-1:0]  rd_tag1,
    output wire              rd_done1,
    output wire [31:0]       rd_value1,
    input  wire [TAG_W-1:0]  rd_tag2,
    output wire              rd_done2,
    output wire [31:0]       rd_value2,
    // head (oldest instruction)
    output wire              head_valid,
    output wire [TAG_W-1:0]  head_tag,
    output wire              head_done,
    output wire [31:0]       head_pc,
    output wire [31:0]       head_instr,
    output wire [4:0]        head_rd,
    output wire              head_regw,
    output wire              head_mem,
    output wire              head_store,
    output wire              head_ctrl,
    output wire              head_cond,
    output wire [HIST_W-1:0] head_hist,
    output wire [31:0]       head_value,
    output wire [31:0]       head_aux,
    output wire              head_taken,
    output wire              head_mispred,
    input  wire              commit         // retire the head this cycle
);
    reg [31:0]       pc    [0:N-1];
    reg [31:0]       instr [0:N-1];
    reg [4:0]        rd    [0:N-1];
    reg [31:0]       value [0:N-1];
    reg [31:0]       aux   [0:N-1];
    reg [HIST_W-1:0] hist  [0:N-1];
    reg [N-1:0]      done, regw, mem, store, ctrl, cond, taken, mispred;

    reg [TAG_W-1:0] head, tail;
    reg [TAG_W:0]   count;

    assign alloc_tag  = tail;
    assign full       = (count == N);
    assign head_valid = (count != 0);
    assign head_tag   = head;

    assign head_done    = done[head];
    assign head_pc      = pc[head];
    assign head_instr   = instr[head];
    assign head_rd      = rd[head];
    assign head_regw    = regw[head];
    assign head_mem     = mem[head];
    assign head_store   = store[head];
    assign head_ctrl    = ctrl[head];
    assign head_cond    = cond[head];
    assign head_hist    = hist[head];
    assign head_value   = value[head];
    assign head_aux     = aux[head];
    assign head_taken   = taken[head];
    assign head_mispred = mispred[head];

    assign rd_done1  = done[rd_tag1];
    assign rd_value1 = value[rd_tag1];
    assign rd_done2  = done[rd_tag2];
    assign rd_value2 = value[rd_tag2];

    wire do_alloc  = alloc & ~full & ~flush;
    wire do_commit = commit & head_valid;

    always @(posedge clk) begin
        if (!rst_n) begin
            head <= 0; tail <= 0; count <= 0;
        end else if (flush) begin
            head  <= head + do_commit;
            tail  <= head + do_commit;
            count <= 0;
        end else begin
            head  <= head + do_commit;
            tail  <= tail + do_alloc;
            count <= count + do_alloc - do_commit;
        end
    end

    // entry contents (no reset needed: an entry is only read while it is valid)
    always @(posedge clk) begin
        if (do_alloc) begin
            pc[tail]    <= a_pc;
            instr[tail] <= a_instr;
            rd[tail]    <= a_rd;
            hist[tail]  <= a_hist;
            value[tail] <= a_value;
            aux[tail]   <= a_aux;
        end
        if (cdb_valid) begin
            value[cdb_tag] <= cdb_value;
            aux[cdb_tag]   <= cdb_aux;
        end
        if (st_valid)
            aux[st_tag] <= st_addr;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            done <= 0; regw <= 0; mem <= 0; store <= 0; ctrl <= 0; cond <= 0; taken <= 0; mispred <= 0;
        end else begin
            if (do_alloc) begin
                done[tail]    <= a_done;
                regw[tail]    <= a_regw;
                mem[tail]     <= a_mem;
                store[tail]   <= a_store;
                ctrl[tail]    <= a_ctrl;
                cond[tail]    <= a_cond;
                taken[tail]   <= a_taken;
                mispred[tail] <= 1'b0;
            end
            if (cdb_valid) begin
                done[cdb_tag]    <= 1'b1;
                taken[cdb_tag]   <= cdb_taken;
                mispred[cdb_tag] <= cdb_mispred;
            end
            if (st_valid)
                done[st_tag] <= 1'b1;
            if (do_commit)
                done[head] <= 1'b0;
            if (flush)
                done <= 0;
        end
    end
endmodule
