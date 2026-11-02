// bp_tournament.v - tournament branch predictor (block A18, goal tier)
// Owner: Avani (G1)
//
// Two predictors race; a third table learns which one to trust per branch.
//
//   pred_pc --+--> bp_bimodal -------- b_taken --+
//             |                                  +--> MUX --> pred_taken
//             +--> bp_gshare  -------- g_taken --+     ^
//   spec_ghr ----^                                      |
//   pred_pc -----> chooser[pc] (2-bit counters) --------+   1x = trust gshare
//
// Global history register (GHR), two copies:
//   spec_ghr   : shifted at fetch with each PREDICTED direction, so the next
//                branch fetched right behind sees the history it will have
//   commit_ghr : shifted at commit with the REAL direction
// On a misprediction or trap the pipeline is flushed and spec_ghr is
// restored from commit_ghr (restore = 1).
//
// Training at commit: both tables learn the real outcome; the chooser moves
// toward whichever table was right, only when they disagreed.
module bp_tournament #(
    parameter HIST_W = 8,
    parameter BIM_W  = 6,
    parameter CH_W   = 6
) (
    input  wire              clk,
    input  wire              rst_n,
    // predict (fetch)
    input  wire [31:0]       pred_pc,
    output wire              pred_taken,
    output wire [HIST_W-1:0] pred_hist,     // history to keep with the branch
    input  wire              spec_shift,    // a conditional branch was fetched
    input  wire              spec_taken,    // ... with this predicted direction
    // train (commit)
    input  wire              upd_en,
    input  wire [31:0]       upd_pc,
    input  wire [HIST_W-1:0] upd_hist,
    input  wire              upd_taken,
    // flush
    input  wire              restore
);
    reg [HIST_W-1:0] spec_ghr, commit_ghr;
    wire b_taken, g_taken, ub_taken, ug_taken;

    bp_bimodal #(.IDX_W(BIM_W)) u_bim (
        .clk(clk), .rst_n(rst_n), .pred_pc(pred_pc), .pred_taken(b_taken),
        .upd_en(upd_en), .upd_pc(upd_pc), .upd_taken(upd_taken), .upd_pred(ub_taken)
    );
    bp_gshare #(.IDX_W(HIST_W)) u_gsh (
        .clk(clk), .rst_n(rst_n), .pred_pc(pred_pc), .pred_hist(spec_ghr), .pred_taken(g_taken),
        .upd_en(upd_en), .upd_pc(upd_pc), .upd_hist(upd_hist), .upd_taken(upd_taken), .upd_pred(ug_taken)
    );

    reg [1:0] choose [0:(1<<CH_W)-1];
    wire [CH_W-1:0] ci = pred_pc[CH_W+1:2];
    wire [CH_W-1:0] cu = upd_pc[CH_W+1:2];

    assign pred_taken = choose[ci][1] ? g_taken : b_taken;
    assign pred_hist  = spec_ghr;

    wire [HIST_W-1:0] commit_next = upd_en ? {commit_ghr[HIST_W-2:0], upd_taken} : commit_ghr;

    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            spec_ghr   <= {HIST_W{1'b0}};
            commit_ghr <= {HIST_W{1'b0}};
            for (i = 0; i < (1<<CH_W); i = i + 1) choose[i] <= 2'b01;   // start with bimodal
        end else begin
            commit_ghr <= commit_next;
            if (restore)         spec_ghr <= commit_next;
            else if (spec_shift) spec_ghr <= {spec_ghr[HIST_W-2:0], spec_taken};
            if (upd_en && ub_taken != ug_taken) begin
                if (ug_taken == upd_taken && choose[cu] != 2'b11) choose[cu] <= choose[cu] + 2'b01;
                if (ub_taken == upd_taken && choose[cu] != 2'b00) choose[cu] <= choose[cu] - 2'b01;
            end
        end
    end
endmodule
