// shield_ctrl.v - enable / mode register (block C7)
// Owner: Priyank (G3)
//
// SHIELD_CTRL (0x1000_0030), written by software, reset value 0x1:
//   bit 0  enable      protection on (AND-ed with switch SW0)
//   bit 1  trap mode   on a violation, jump to the handler instead of freezing
//   bit 2  count-only  never stop the CPU, just count violations
//   bit 3  lpad enable landing-pad check for indirect jumps (goal tier)
//   bit 4  lock        once written as 1, CTRL and HANDLER ignore every
//                      later write until reset (minimum system, new)
// SHIELD_HANDLER (0x1000_0044): address of the security handler (trap mode)
//
// Why a lock? Boot code turns protection on, then sets the lock in the same
// or a later write. After that, an attacker who gains a memory write (the
// same bug that overwrites a return address) cannot store 0 to SHIELD_CTRL
// to switch ShieldV off, or point SHIELD_HANDLER at their own code.
// Only reset clears the lock. The physical switch SW0 still works: it is not
// a memory write, it is the demo's "protection off" control.
//
// The switch makes the live demo possible: same program, flip SW0, see the
// attack succeed (off) or get caught (on).
module shield_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sw_enable,        // synchronised SW0
    input  wire        we_ctrl,
    input  wire        we_handler,
    input  wire [31:0] wdata,
    output reg  [4:0]  ctrl,
    output reg  [31:0] handler_pc,
    output wire        locked,
    output wire        enabled,
    output wire        trap_mode,
    output wire        count_only,
    output wire        lpad_en
);
    always @(posedge clk) begin
        if (!rst_n) begin
            ctrl       <= 5'b00001;
            handler_pc <= 32'd0;
        end else if (!locked) begin
            if (we_ctrl)    ctrl       <= wdata[4:0];
            if (we_handler) handler_pc <= {wdata[31:2], 2'b00};
        end
    end

    assign locked     = ctrl[4];

    assign enabled    = ctrl[0] & sw_enable;
    assign trap_mode  = ctrl[1];
    assign count_only = ctrl[2];
    assign lpad_en    = ctrl[3];
endmodule
