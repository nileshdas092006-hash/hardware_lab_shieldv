// fault_regs.v - what ShieldV remembers about the attack (block C9)
// Owner: Priyank (G3)
//
// When a violation is caught, these registers keep a snapshot so the display
// and the handler software can explain the attack:
//   FAULT_PC  (0x1000_0038) : address of the instruction that was caught (the bad ret)
//   EXPECTED  (0x1000_003C) : the return address ShieldV saved at the call
//   ACTUAL    (0x1000_0040) : where the program tried to go (attacker's choice)
//   cause                   : 1 return mismatch, 2 underflow, 3 overflow, 4 landing pad
//   violations              : how many violations so far (saturates at 255)
module fault_regs (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        capture,
    input  wire        count,
    input  wire [31:0] pc,
    input  wire [31:0] expected,
    input  wire [31:0] actual,
    input  wire [3:0]  cause_in,
    output reg  [31:0] fault_pc,
    output reg  [31:0] fault_expected,
    output reg  [31:0] fault_actual,
    output reg  [3:0]  cause,
    output reg  [7:0]  violations
);
    always @(posedge clk) begin
        if (!rst_n) begin
            fault_pc <= 32'd0; fault_expected <= 32'd0; fault_actual <= 32'd0;
            cause <= 4'd0; violations <= 8'd0;
        end else begin
            if (capture) begin
                fault_pc       <= pc;
                fault_expected <= expected;
                fault_actual   <= actual;
                cause          <= cause_in;
            end
            if (count && violations != 8'hFF)
                violations <= violations + 8'd1;
        end
    end
endmodule
