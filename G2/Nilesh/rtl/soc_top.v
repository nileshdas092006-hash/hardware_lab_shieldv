// soc_top.v - the whole ShieldV system-on-chip, without board-specific parts
// Owner: Nilesh (G2)
//
//   core_pipe (G1) ── IF-1 ── munit (G2, Nishant)
//        │  └────── IF-3 ── shieldv (G3, Priyank)
//        └── IF-2 ── bus_decoder ──┬── dmem (data RAM)
//                                  └── I/O: LEDs, 7-seg, switches, UART,
//                                      perf counters, ShieldV registers
//
// The simulation testbench drives clk/rst_n directly; fpga_top.v adds the
// clock manager and the board pins.
//
// USE_MUNIT_STUB / USE_SHIELD_STUB swap in the stand-in modules, which is how
// the integration ladder (rungs I1..I4) is climbed one block at a time.
//
// Build option: which core? Both cores have exactly the same ports, so the
// rest of the SoC does not change.
//   default                : core_pipe, the 3-stage in-order core (baseline)
//   `define SHIELDV_OOO    : core_ooo, the out-of-order Tomasulo core (goal)
// (scripts: --core ooo; Vivado: -verilog_define SHIELDV_OOO). The in-order
// core sends each instruction to ShieldV from EX, the out-of-order core from
// the head of its reorder buffer at commit, over the same IF-3 wires.
module soc_top #(
    parameter IMEM_INIT       = "imem.hex",
    parameter DMEM_INIT       = "dmem.hex",
    parameter CLK_HZ          = 50_000_000,
    parameter BAUD            = 115_200,
    parameter REFRESH_BITS    = 16,
    parameter USE_MUNIT_STUB  = 0,
    parameter USE_SHIELD_STUB = 0
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sw_raw,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [7:0]  an,
    output wire        uart_txd,
    output wire        alarm_led,
    output wire        ok_led,
    // trace port (IF-4), for the ILA and testbenches
    output wire [31:0] tr_if_pc,
    output wire [31:0] tr_ex_pc,
    output wire [31:0] tr_wb_pc,
    output wire        tr_stall,
    output wire        tr_flush,
    output wire        tr_ex_valid,
    output wire        tr_retire
);
    // ---------------- core ----------------
    wire        m_start, m_busy, m_done;
    wire [2:0]  m_op;
    wire [31:0] m_a, m_b, m_result;
    wire [31:0] bus_addr, bus_wdata, bus_rdata;
    wire [3:0]  bus_wstrb;
    wire        bus_we, bus_re;
    wire        ex_valid, sh_freeze, sh_trap;
    wire [31:0] ex_instr, ex_pc, ex_target, ex_link, sh_handler_pc;
    wire        tr_branch, tr_mispredict;

`ifdef SHIELDV_OOO
    localparam [31:0] CORE_ID = 32'd1;
    core_ooo #(.IMEM_INIT(IMEM_INIT)) u_core (
`else
    localparam [31:0] CORE_ID = 32'd0;
    core_pipe #(.IMEM_INIT(IMEM_INIT)) u_core (
`endif
        .clk(clk), .rst_n(rst_n),
        .m_start(m_start), .m_op(m_op), .m_a(m_a), .m_b(m_b),
        .m_busy(m_busy), .m_done(m_done), .m_result(m_result),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_wstrb(bus_wstrb),
        .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(bus_rdata),
        .ex_valid(ex_valid), .ex_instr(ex_instr), .ex_pc(ex_pc),
        .ex_target(ex_target), .ex_link(ex_link),
        .sh_freeze(sh_freeze), .sh_trap(sh_trap), .sh_handler_pc(sh_handler_pc),
        .tr_if_pc(tr_if_pc), .tr_ex_pc(tr_ex_pc), .tr_wb_pc(tr_wb_pc),
        .tr_stall(tr_stall), .tr_flush(tr_flush), .tr_ex_valid(tr_ex_valid), .tr_retire(tr_retire),
        .tr_branch(tr_branch), .tr_mispredict(tr_mispredict)
    );

    // ---------------- M-unit ----------------
    generate
        if (USE_MUNIT_STUB) begin : g_mstub
            munit_stub u_m (.clk(clk), .rst_n(rst_n), .start(m_start), .op(m_op), .a(m_a), .b(m_b),
                            .busy(m_busy), .done(m_done), .result(m_result));
        end else begin : g_munit
            munit u_m (.clk(clk), .rst_n(rst_n), .start(m_start), .op(m_op), .a(m_a), .b(m_b),
                       .busy(m_busy), .done(m_done), .result(m_result));
        end
    endgenerate

    // ---------------- switches ----------------
    wire [15:0] sw;
    switch_sync #(.W(16)) u_sw (.clk(clk), .sw_raw(sw_raw), .sw(sw));

    // ---------------- bus ----------------
    wire        dmem_en, io_we;
    wire [3:0]  dmem_wstrb;
    wire [31:0] dmem_rdata, io_wdata;
    wire [7:0]  io_addr;
    reg  [31:0] io_rdata;

    bus_decoder u_bus (
        .clk(clk), .rst_n(rst_n),
        .addr(bus_addr), .wdata(bus_wdata), .wstrb(bus_wstrb), .we(bus_we), .re(bus_re),
        .rdata(bus_rdata),
        .dmem_en(dmem_en), .dmem_wstrb(dmem_wstrb), .dmem_rdata(dmem_rdata),
        .io_we(io_we), .io_addr(io_addr), .io_wdata(io_wdata), .io_rdata(io_rdata)
    );

    dmem #(.INIT_FILE(DMEM_INIT)) u_dmem (
        .clk(clk), .en(dmem_en), .wstrb(dmem_wstrb), .addr(bus_addr),
        .wdata(bus_wdata), .rdata(dmem_rdata)
    );

    // ---------------- ShieldV ----------------
    wire        alarm, ev_call, ev_ret, ev_violation;
    wire [31:0] fault_pc, shield_rdata;

    generate
        if (USE_SHIELD_STUB) begin : g_sstub
            shieldv_stub u_sh (.clk(clk), .rst_n(rst_n), .ex_valid(ex_valid), .ex_instr(ex_instr),
                .ex_pc(ex_pc), .ex_target(ex_target), .ex_link(ex_link),
                .sh_freeze(sh_freeze), .sh_trap(sh_trap), .sh_handler_pc(sh_handler_pc));
            assign alarm = 1'b0; assign fault_pc = 32'd0; assign shield_rdata = 32'd0;
            assign ev_call = 1'b0; assign ev_ret = 1'b0; assign ev_violation = 1'b0;
        end else begin : g_shield
            shieldv u_sh (
                .clk(clk), .rst_n(rst_n),
                .ex_valid(ex_valid), .ex_instr(ex_instr), .ex_pc(ex_pc),
                .ex_target(ex_target), .ex_link(ex_link),
                .sh_freeze(sh_freeze), .sh_trap(sh_trap), .sh_handler_pc(sh_handler_pc),
                .sw_enable(sw[0]),
                .reg_we(io_we), .reg_addr(io_addr), .reg_wdata(io_wdata), .reg_rdata(shield_rdata),
                .alarm(alarm), .fault_pc(fault_pc),
                .ev_call(ev_call), .ev_ret(ev_ret), .ev_violation(ev_violation)
            );
        end
    endgenerate

    // ---------------- peripherals ----------------
    led_reg u_led (.clk(clk), .rst_n(rst_n), .we(io_we && io_addr == 8'h00), .wdata(io_wdata), .led(led));

    reg [31:0] seg_value;
    always @(posedge clk) begin
        if (!rst_n)                      seg_value <= 32'd0;
        else if (io_we && io_addr == 8'h04) seg_value <= io_wdata;
    end
    // while frozen, the display shows the faulting PC instead
    seg7_driver #(.REFRESH_BITS(REFRESH_BITS)) u_seg (
        .clk(clk), .rst_n(rst_n), .value(alarm ? fault_pc : seg_value),
        .seg(seg), .dp(dp), .an(an)
    );

    wire uart_busy;
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart (
        .clk(clk), .rst_n(rst_n), .start(io_we && io_addr == 8'h10), .data(io_wdata[7:0]),
        .tx(uart_txd), .busy(uart_busy)
    );

    wire [31:0] perf_rdata;
    perf_counters #(.CORE_ID(CORE_ID)) u_perf (
        .clk(clk), .rst_n(rst_n), .frozen(alarm), .retire(tr_retire),
        .ev_call(ev_call), .ev_ret(ev_ret),
        .ev_branch(tr_branch), .ev_mispredict(tr_mispredict), .ev_violation(ev_violation),
        .rd_addr(io_addr), .rd_data(perf_rdata)
    );

    // I/O read mux (the bus decoder registers it)
    always @* begin
        case (io_addr)
            8'h00: io_rdata = {16'd0, led};
            8'h04: io_rdata = seg_value;
            8'h08: io_rdata = {16'd0, sw};
            8'h14: io_rdata = {31'd0, uart_busy};
            8'h20, 8'h24, 8'h28, 8'h2C,
            8'h50, 8'h54, 8'h58, 8'h5C: io_rdata = perf_rdata;
            8'h30, 8'h34, 8'h38, 8'h3C, 8'h40, 8'h44: io_rdata = shield_rdata;
            default: io_rdata = 32'd0;
        endcase
    end

    assign alarm_led = alarm;
    assign ok_led    = rst_n & ~alarm & sw[0];   // green: protection armed
endmodule
