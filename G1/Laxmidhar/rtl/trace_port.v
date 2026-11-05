// trace_port.v - debug/trace outputs (block A14, interface IF-4)
// Owner: Laxmidhar (G1)
//
// Exports, every cycle, which instruction is in which stage and whether the
// pipeline stalled or flushed. Nothing inside the CPU uses these signals;
// they exist for
//   * the timing diagrams (WaveDrom, cut from the simulation VCD),
//   * the Vivado ILA (watching the real board),
//   * the performance counters (instret, branches, mispredictions).
// branch / mispredict were added for the branch-prediction study: one pulse
// per retired branch or jump, and one per retired control-flow instruction
// that had to redirect the front end (a misprediction).
// Registering them once keeps the ILA probes off the CPU's critical paths.
module trace_port (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] if_pc_i,
    input  wire [31:0] ex_pc_i,
    input  wire [31:0] wb_pc_i,
    input  wire        stall_i,
    input  wire        flush_i,
    input  wire        ex_valid_i,
    input  wire        retire_i,
    input  wire        branch_i,
    input  wire        mispredict_i,
    output reg  [31:0] if_pc,
    output reg  [31:0] ex_pc,
    output reg  [31:0] wb_pc,
    output reg         stall,
    output reg         flush,
    output reg         ex_valid,
    output reg         retire,
    output reg         branch,
    output reg         mispredict
);
    always @(posedge clk) begin
        if (!rst_n) begin
            if_pc <= 32'd0; ex_pc <= 32'd0; wb_pc <= 32'd0;
            stall <= 1'b0;  flush <= 1'b0;  ex_valid <= 1'b0; retire <= 1'b0;
            branch <= 1'b0; mispredict <= 1'b0;
        end else begin
            if_pc <= if_pc_i; ex_pc <= ex_pc_i; wb_pc <= wb_pc_i;
            stall <= stall_i; flush <= flush_i; ex_valid <= ex_valid_i; retire <= retire_i;
            branch <= branch_i; mispredict <= mispredict_i;
        end
    end
endmodule
