// switch_sync.v - two-flip-flop synchroniser for the 16 slide switches (block B6)
// Owner: Nilesh (G2)
//
// A switch can flip at any instant, even exactly on a clock edge. A flip-flop
// that samples a changing input can hang "half way" for a moment
// (metastability) and different gates may read it differently. Passing the
// signal through two flip-flops gives it a full clock cycle to settle, so
// the rest of the design only ever sees a clean 0 or 1.
//
// SW0 is the ShieldV protection switch, so this matters for the demo.
// Slide switches bounce for a few milliseconds, but the CPU only reads the
// level, so no debouncer is needed here.
module switch_sync #(
    parameter W = 16
) (
    input  wire         clk,
    input  wire [W-1:0] sw_raw,
    output wire [W-1:0] sw
);
    (* ASYNC_REG = "TRUE" *) reg [W-1:0] s1, s2;
    always @(posedge clk) begin
        s1 <= sw_raw;
        s2 <= s1;
    end
    assign sw = s2;
endmodule
