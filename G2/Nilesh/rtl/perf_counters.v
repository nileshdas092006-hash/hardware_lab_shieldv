// perf_counters.v - hardware performance counters (block B9, goal tier)
// Owner: Nilesh (G2)
//
// 32-bit counters the software can read like memory:
//   0x1000_0020 CYCLE    clock cycles since reset
//   0x1000_0024 INSTRET  instructions that finished (retired)
//   0x1000_0028 CALLS    calls seen by ShieldV (pushes)
//   0x1000_002C RETS     returns seen by ShieldV (pops)
//   0x1000_0050 BRANCHES branches and jumps retired
//   0x1000_0054 MISPRED  of those, how many redirected the front end
//   0x1000_0058 VIOL     ShieldV violations seen
//   0x1000_005C CORE_ID  which core this bitstream has (0 in-order, 1 out-of-order)
// CPI (cycles per instruction) = delta CYCLE / delta INSTRET.
// Prediction accuracy = 1 - delta MISPRED / delta BRANCHES.
// Overhead of protection = cycles(protection on) - cycles(protection off)
// for the same program; the design goal is 0.
// Counters stop while the CPU is frozen so the numbers describe the program.
module perf_counters #(
    parameter [31:0] CORE_ID = 32'd0
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frozen,
    input  wire        retire,
    input  wire        ev_call,
    input  wire        ev_ret,
    input  wire        ev_branch,
    input  wire        ev_mispredict,
    input  wire        ev_violation,
    input  wire [7:0]  rd_addr,
    output reg  [31:0] rd_data
);
    reg [31:0] cycles, instret, calls, rets, branches, mispred, viol;

    always @(posedge clk) begin
        if (!rst_n) begin
            cycles <= 32'd0; instret <= 32'd0; calls <= 32'd0; rets <= 32'd0;
            branches <= 32'd0; mispred <= 32'd0;
        end else if (!frozen) begin
            cycles <= cycles + 32'd1;
            if (retire)        instret  <= instret + 32'd1;
            if (ev_call)       calls    <= calls + 32'd1;
            if (ev_ret)        rets     <= rets + 32'd1;
            if (ev_branch)     branches <= branches + 32'd1;
            if (ev_mispredict) mispred  <= mispred + 32'd1;
        end
    end

    // violations count even while frozen: the catch itself freezes the CPU
    always @(posedge clk) begin
        if (!rst_n)            viol <= 32'd0;
        else if (ev_violation) viol <= viol + 32'd1;
    end

    always @* begin
        case (rd_addr)
            8'h20:   rd_data = cycles;
            8'h24:   rd_data = instret;
            8'h28:   rd_data = calls;
            8'h2C:   rd_data = rets;
            8'h50:   rd_data = branches;
            8'h54:   rd_data = mispred;
            8'h58:   rd_data = viol;
            8'h5C:   rd_data = CORE_ID;
            default: rd_data = 32'd0;
        endcase
    end
endmodule
