// rst_sync.v - reset synchroniser (part of block B10)
// Owner: Nilesh (G2)
//
// The reset button can be pressed or released at any moment. If reset is
// released close to a clock edge, some flip-flops might leave reset one cycle
// before others and the CPU starts in a broken state.
//
// This block makes reset go ON immediately (asynchronously, so it always works)
// but go OFF only on a clock edge, after passing through 2 flip-flops.
// Everything downstream then uses a clean, synchronous, active-low rst_n.
module rst_sync (
    input  wire clk,
    input  wire arst_n,     // raw: button AND clock-locked
    output wire rst_n
);
    reg [1:0] sync;
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) sync <= 2'b00;
        else         sync <= {sync[0], 1'b1};
    end
    assign rst_n = sync[1];
endmodule
