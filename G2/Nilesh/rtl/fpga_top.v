// fpga_top.v - top module for the Nexys A7-100T (block B11)
// Owner: Nilesh (G2)
//
// Connects soc_top to the real pins. Port names match the Digilent master
// constraints file (fpga/nexys_a7.xdc), so the pin map is easy to check.
//
//   CLK100MHZ    100 MHz oscillator -> clk_rst -> 50 MHz system clock
//   CPU_RESETN   red reset button (active low)
//   SW[15:0]     slide switches; SW0 = ShieldV protection on/off
//   LED[15:0]    green LEDs, written by software
//   LED17_R      red RGB LED: ShieldV alarm (CPU frozen)
//   LED16_G      green RGB LED: protection armed
//   CA..CG, DP, AN[7:0]  8-digit display; shows the fault PC while frozen
//   UART_RXD_OUT serial output to the laptop (115200 baud, 8N1)
module fpga_top #(
    // program images; build.tcl copies them next to the run, the Vivado
    // project (create_project.tcl) passes full paths instead
    parameter IMEM_INIT = "imem.hex",
    parameter DMEM_INIT = "dmem.hex",
    // 1 = build without ShieldV (stub), only to measure ShieldV's own cost
    parameter USE_SHIELD_STUB = 0
) (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire [15:0] SW,
    output wire [15:0] LED,
    output wire        LED16_G,
    output wire        LED17_R,
    output wire        CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0]  AN,
    output wire        UART_RXD_OUT
);
    wire clk, rst_n;
    clk_rst u_clk (.clk100(CLK100MHZ), .btn_rst_n(CPU_RESETN), .clk(clk), .rst_n(rst_n));

    wire [6:0] seg;
    (* mark_debug = "true" *) wire [31:0] tr_if_pc, tr_ex_pc, tr_wb_pc;
    (* mark_debug = "true" *) wire        tr_stall, tr_flush, tr_ex_valid, tr_retire;
    (* mark_debug = "true" *) wire        alarm;

    soc_top #(
        .IMEM_INIT(IMEM_INIT),
        .DMEM_INIT(DMEM_INIT),
        .CLK_HZ(50_000_000),
        .BAUD(115_200),
        .REFRESH_BITS(16),
        .USE_SHIELD_STUB(USE_SHIELD_STUB)
    ) u_soc (
        .clk(clk), .rst_n(rst_n), .sw_raw(SW),
        .led(LED), .seg(seg), .dp(DP), .an(AN), .uart_txd(UART_RXD_OUT),
        .alarm_led(alarm), .ok_led(LED16_G),
        .tr_if_pc(tr_if_pc), .tr_ex_pc(tr_ex_pc), .tr_wb_pc(tr_wb_pc),
        .tr_stall(tr_stall), .tr_flush(tr_flush), .tr_ex_valid(tr_ex_valid), .tr_retire(tr_retire)
    );

    assign {CG, CF, CE, CD, CC, CB, CA} = seg;
    assign LED17_R = alarm;
endmodule
