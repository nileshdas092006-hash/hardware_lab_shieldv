// shieldv.v - the ShieldV security unit (top of G3 hardware)
// Owner: Priyank (G3)
//
// Watches every instruction that commits in EX (interface IF-3):
//   call   -> push ex_link (pc+4) onto the shadow stack
//   return -> compare ex_target with the top of the shadow stack
//             equal: pop and carry on; different: freeze (or trap)
//
//            ex_instr ──► callret_detect ──► is_call / is_ret / needs_lpad
//                                │
//   ex_valid ──► commit_ctrl ────┴──► push / pop ──► shadow_stack ──► top
//                                                                  │
//   ex_target ─────────────────────────► ret_compare ◄─────────────┘
//                                          │ mismatch / underflow / overflow
//   lpad_check (goal) ──── fail ───────────┤
//                                          ▼
//                 shield_ctrl ──► violation_fsm ──► sh_freeze / sh_trap
//                                          │
//                                          └──► fault_regs (PC, expected, actual)
//
// Register block on the data bus, base 0x1000_0030 (see docs/interfaces.md):
//   +0x00 CTRL      rw  bit0 enable, bit1 trap mode, bit2 count-only, bit3 lpad,
//                       bit4 lock (after it is set, CTRL and HANDLER ignore writes)
//   +0x04 STAT      r   [7:0] violations, [13:8] depth, [19:16] cause, [30] locked, [31] alarm
//   +0x08 FAULT_PC  r
//   +0x0C EXPECTED  r
//   +0x10 ACTUAL    r
//   +0x14 HANDLER   rw  security handler address (trap mode)
module shieldv #(
    parameter DEPTH = 32
) (
    input  wire        clk,
    input  wire        rst_n,

    // IF-3 from the core
    input  wire        ex_valid,
    input  wire [31:0] ex_instr,
    input  wire [31:0] ex_pc,
    input  wire [31:0] ex_target,
    input  wire [31:0] ex_link,
    output wire        sh_freeze,
    output wire        sh_trap,
    output wire [31:0] sh_handler_pc,

    // protection switch (already synchronised)
    input  wire        sw_enable,

    // register block (from the bus decoder)
    input  wire        reg_we,
    input  wire [7:0]  reg_addr,       // low byte of the address
    input  wire [31:0] reg_wdata,
    output reg  [31:0] reg_rdata,

    // status for LEDs, display and performance counters
    output wire        alarm,
    output wire [31:0] fault_pc,
    output wire        ev_call,
    output wire        ev_ret,
    output wire        ev_violation
);
    localparam CAUSE_MISMATCH  = 4'd1;
    localparam CAUSE_UNDERFLOW = 4'd2;
    localparam CAUSE_OVERFLOW  = 4'd3;
    localparam CAUSE_LPAD      = 4'd4;

    // ---- control register ----
    wire [4:0] ctrl;
    wire       enabled, trap_mode, count_only, lpad_en, locked;
    shield_ctrl u_ctrl (
        .clk(clk), .rst_n(rst_n), .sw_enable(sw_enable),
        .we_ctrl(reg_we && reg_addr == 8'h30),
        .we_handler(reg_we && reg_addr == 8'h44),
        .wdata(reg_wdata), .ctrl(ctrl), .handler_pc(sh_handler_pc), .locked(locked),
        .enabled(enabled), .trap_mode(trap_mode), .count_only(count_only), .lpad_en(lpad_en)
    );

    // ---- C1: what kind of instruction is in EX? ----
    wire is_call, is_ret, needs_lpad;
    callret_detect u_det (.instr(ex_instr), .is_call(is_call), .is_ret(is_ret), .needs_lpad(needs_lpad));

    // ---- C2/C3: the shadow stack ----
    wire [31:0] top;
    wire        empty, full;
    wire [5:0]  depth;
    wire        do_push, do_pop;
    shadow_stack #(.DEPTH(DEPTH)) u_ss (
        .clk(clk), .rst_n(rst_n), .push(do_push), .pop(do_pop), .push_data(ex_link),
        .top(top), .empty(empty), .full(full), .depth(depth)
    );

    // ---- C5: compare ----
    wire mismatch, underflow, overflow;
    ret_compare u_cmp (
        .is_ret(is_ret), .is_call(is_call), .actual(ex_target), .expected(top),
        .empty(empty), .full(full),
        .mismatch(mismatch), .underflow(underflow), .overflow(overflow)
    );

    // ---- C8: landing pads (goal) ----
    wire lpad_fail;
    lpad_check u_lp (
        .clk(clk), .rst_n(rst_n), .enable(lpad_en), .ex_valid(ex_valid), .ex_instr(ex_instr),
        .needs_lpad(needs_lpad), .freeze(sh_freeze), .trap(sh_trap), .fail(lpad_fail)
    );

    wire violation = ex_valid & (mismatch | underflow | overflow | lpad_fail);

    // ---- C6: react ----
    wire capture;
    violation_fsm u_fsm (
        .clk(clk), .rst_n(rst_n), .violation(violation), .enabled(enabled),
        .count_only(count_only), .trap_mode(trap_mode),
        .freeze(sh_freeze), .trap(sh_trap), .alarm(alarm), .capture(capture)
    );

    // ---- C4: only real, unblocked instructions change the stack ----
    commit_ctrl u_cc (
        .ex_valid(ex_valid), .is_call(is_call), .is_ret(is_ret),
        .block(sh_freeze | sh_trap), .do_push(do_push), .do_pop(do_pop)
    );

    // ---- C9: remember the attack ----
    reg [3:0]  cause_now;
    reg [31:0] expected_now, actual_now;
    always @* begin
        if (lpad_fail) begin
            cause_now = CAUSE_LPAD;      expected_now = 32'd0;   actual_now = ex_pc;
        end else if (underflow) begin
            cause_now = CAUSE_UNDERFLOW; expected_now = 32'd0;   actual_now = ex_target;
        end else if (overflow) begin
            cause_now = CAUSE_OVERFLOW;  expected_now = ex_link; actual_now = ex_target;
        end else begin
            cause_now = CAUSE_MISMATCH;  expected_now = top;     actual_now = ex_target;
        end
    end

    wire [31:0] f_expected, f_actual;
    wire [3:0]  f_cause;
    wire [7:0]  f_count;
    fault_regs u_fault (
        .clk(clk), .rst_n(rst_n), .capture(capture), .count(capture),
        .pc(ex_pc), .expected(expected_now), .actual(actual_now), .cause_in(cause_now),
        .fault_pc(fault_pc), .fault_expected(f_expected), .fault_actual(f_actual),
        .cause(f_cause), .violations(f_count)
    );

    // ---- register reads ----
    always @* begin
        case (reg_addr)
            8'h30:   reg_rdata = {27'd0, ctrl};
            8'h34:   reg_rdata = {alarm, locked, 10'd0, f_cause, 2'b00, depth, f_count};
            8'h38:   reg_rdata = fault_pc;
            8'h3C:   reg_rdata = f_expected;
            8'h40:   reg_rdata = f_actual;
            8'h44:   reg_rdata = sh_handler_pc;
            default: reg_rdata = 32'd0;
        endcase
    end

    assign ev_call      = do_push;
    assign ev_ret       = do_pop;
    assign ev_violation = capture;
endmodule
