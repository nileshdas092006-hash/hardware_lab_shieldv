// clk_rst.v - clock and reset generation (block B10)
// Owner: Nilesh (G2)
//
// The Nexys A7 has a 100 MHz oscillator. Our CPU runs at 50 MHz, which gives
// every path 20 ns instead of 10 ns, a safe margin for a first FPGA design.
//
// An MMCM (mixed-mode clock manager, a clock-making block inside the FPGA)
// multiplies 100 MHz up to 1000 MHz internally and divides by 20 -> 50 MHz.
// Its "locked" output says the new clock is stable; we keep the CPU in reset
// until then.
//
// Uses Xilinx primitives (MMCME2_BASE, BUFG): FPGA builds only. Simulations
// drive clk and rst_n of soc_top directly.
module clk_rst #(
    parameter real CLKOUT_DIVIDE = 20.0      // 1000 MHz / 20 = 50 MHz
) (
    input  wire clk100,
    input  wire btn_rst_n,                   // CPU_RESETN button, active low
    output wire clk,
    output wire rst_n
);
    wire clk_fb, clk_fb_buf, clk_mmcm, locked;

    MMCME2_BASE #(
        .CLKIN1_PERIOD    (10.0),
        .DIVCLK_DIVIDE    (1),
        .CLKFBOUT_MULT_F  (10.0),
        .CLKOUT0_DIVIDE_F (CLKOUT_DIVIDE)
    ) u_mmcm (
        .CLKIN1   (clk100),
        .CLKFBIN  (clk_fb_buf),
        .CLKFBOUT (clk_fb),
        .CLKOUT0  (clk_mmcm),
        .LOCKED   (locked),
        .RST      (1'b0),
        .PWRDWN   (1'b0),
        .CLKFBOUTB(), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(), .CLKOUT2(), .CLKOUT2B(),
        .CLKOUT3(), .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6()
    );

    BUFG u_bufg_fb  (.I(clk_fb),   .O(clk_fb_buf));
    BUFG u_bufg_clk (.I(clk_mmcm), .O(clk));

    rst_sync u_rst (.clk(clk), .arst_n(btn_rst_n & locked), .rst_n(rst_n));
endmodule
