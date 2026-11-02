// bp_bimodal.v - bimodal branch history table (block A16, goal tier)
// Owner: Avani (G1)
//
// A table of 2-bit saturating counters indexed by the branch's PC.
//   00 strongly not taken, 01 weakly not taken, 10 weakly taken, 11 strongly taken
// Predict: taken = counter[1]. Train (when the branch commits): count up if
// it was taken, down if not. Two wrong guesses in a row are needed to flip a
// strong prediction, so one odd loop exit does not ruin the next loop.
//
// The index is PC bits [IDX_W+1:2] (bits 1..0 are always 0 for 32-bit code).
// rd_pc / rd_taken is a second read port, used when training the tournament
// chooser ("what would this table have said for the branch now committing?").
module bp_bimodal #(
    parameter IDX_W = 6                      // 64 counters
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] pred_pc,
    output wire        pred_taken,
    input  wire        upd_en,
    input  wire [31:0] upd_pc,
    input  wire        upd_taken,
    output wire        upd_pred              // current prediction for upd_pc
);
    reg [1:0] cnt [0:(1<<IDX_W)-1];

    wire [IDX_W-1:0] pi = pred_pc[IDX_W+1:2];
    wire [IDX_W-1:0] ui = upd_pc[IDX_W+1:2];

    assign pred_taken = cnt[pi][1];
    assign upd_pred   = cnt[ui][1];

    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < (1<<IDX_W); i = i + 1) cnt[i] <= 2'b01;   // weakly not taken
        end else if (upd_en) begin
            if (upd_taken && cnt[ui] != 2'b11)       cnt[ui] <= cnt[ui] + 2'b01;
            else if (!upd_taken && cnt[ui] != 2'b00) cnt[ui] <= cnt[ui] - 2'b01;
        end
    end
endmodule
