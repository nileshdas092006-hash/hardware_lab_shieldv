// bp_gshare.v - gshare branch predictor (block A17, goal tier)
// Owner: Avani (G1)
//
// Like the bimodal table, but the index mixes the PC with the global history
// register (GHR): the taken / not-taken outcomes of the last IDX_W branches.
//   index = PC[IDX_W+1:2] XOR GHR
// This lets one branch get different predictions depending on the path that
// led to it (e.g. "the inner loop exits every 4th time").
//
// The history used to predict is kept with the branch (in the reorder
// buffer) and handed back at commit, so training updates the same counter
// that made the prediction.
module bp_gshare #(
    parameter IDX_W = 8                      // 256 counters, 8 bits of history
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [31:0]      pred_pc,
    input  wire [IDX_W-1:0] pred_hist,
    output wire             pred_taken,
    input  wire             upd_en,
    input  wire [31:0]      upd_pc,
    input  wire [IDX_W-1:0] upd_hist,
    input  wire             upd_taken,
    output wire             upd_pred         // current prediction for (upd_pc, upd_hist)
);
    reg [1:0] cnt [0:(1<<IDX_W)-1];

    wire [IDX_W-1:0] pi = pred_pc[IDX_W+1:2] ^ pred_hist;
    wire [IDX_W-1:0] ui = upd_pc[IDX_W+1:2]  ^ upd_hist;

    assign pred_taken = cnt[pi][1];
    assign upd_pred   = cnt[ui][1];

    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < (1<<IDX_W); i = i + 1) cnt[i] <= 2'b01;
        end else if (upd_en) begin
            if (upd_taken && cnt[ui] != 2'b11)       cnt[ui] <= cnt[ui] + 2'b01;
            else if (!upd_taken && cnt[ui] != 2'b00) cnt[ui] <= cnt[ui] - 2'b01;
        end
    end
endmodule
