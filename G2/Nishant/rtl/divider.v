// divider.v - DIV, DIVU, REM, REMU with a 32-step restoring divider (block B2)
// Owner: Nishant (G2)
//
// Restoring division is binary long division, one quotient bit per clock:
//   1. shift the partial remainder left, bringing down the next dividend bit
//   2. try to subtract the divisor
//   3. if that did not go negative: keep it, quotient bit = 1
//      otherwise: "restore" (keep the old value), quotient bit = 0
// After 32 steps we have the quotient and remainder of |a| / |b|.
// Signed division then fixes the signs:
//   quotient is negative when exactly one input is negative,
//   remainder takes the sign of the dividend (a).
//
// The RISC-V spec fixes the special cases (no exceptions on RISC-V):
//   x / 0         -> quotient = -1 (all ones), remainder = x
//   INT_MIN / -1  -> quotient = INT_MIN,        remainder = 0
// These finish in one step instead of 32.
//
//   op  | instruction
//   00  | DIV   (signed quotient)
//   01  | DIVU  (unsigned quotient)
//   10  | REM   (signed remainder)
//   11  | REMU  (unsigned remainder)
//
// Timing: start in cycle 0, 32 iteration cycles, done=1 in cycle 33.
module divider (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [1:0]  op,          // funct3[1:0]
    input  wire [31:0] a,           // dividend
    input  wire [31:0] b,           // divisor
    output wire        busy,
    output reg         done,
    output reg  [31:0] result
);
    localparam IDLE = 2'd0;
    localparam RUN  = 2'd1;
    localparam FIN  = 2'd2;

    reg [1:0]  state;
    reg [5:0]  count;
    reg [31:0] quot;        // shifts in quotient bits; starts as |dividend|
    reg [32:0] rem;         // partial remainder (33 bits so the subtraction sign is visible)
    reg [31:0] dvsr;        // |divisor|
    reg        neg_q, neg_r, want_rem;
    reg        special;
    reg [31:0] special_val;

    wire is_signed = ~op[0];
    wire a_neg = is_signed & a[31];
    wire b_neg = is_signed & b[31];
    wire [31:0] a_abs = a_neg ? (~a + 32'd1) : a;
    wire [31:0] b_abs = b_neg ? (~b + 32'd1) : b;

    // one restoring step
    wire [32:0] shifted = {rem[31:0], quot[31]};
    wire [32:0] trial   = shifted - {1'b0, dvsr};
    wire        fits    = ~trial[32];

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE; count <= 6'd0; done <= 1'b0; result <= 32'd0;
            quot <= 32'd0; rem <= 33'd0; dvsr <= 32'd0;
            neg_q <= 1'b0; neg_r <= 1'b0; want_rem <= 1'b0;
            special <= 1'b0; special_val <= 32'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: if (start) begin
                    want_rem <= op[1];
                    if (b == 32'd0) begin
                        special <= 1'b1;
                        special_val <= op[1] ? a : 32'hFFFF_FFFF;
                        state <= FIN;
                    end else if (is_signed && a == 32'h8000_0000 && b == 32'hFFFF_FFFF) begin
                        special <= 1'b1;
                        special_val <= op[1] ? 32'd0 : 32'h8000_0000;
                        state <= FIN;
                    end else begin
                        special <= 1'b0;
                        quot  <= a_abs;
                        rem   <= 33'd0;
                        dvsr  <= b_abs;
                        neg_q <= a_neg ^ b_neg;
                        neg_r <= a_neg;
                        count <= 6'd0;
                        state <= RUN;
                    end
                end
                RUN: begin
                    rem   <= fits ? trial : shifted;
                    quot  <= {quot[30:0], fits};
                    count <= count + 6'd1;
                    if (count == 6'd31) state <= FIN;
                end
                FIN: begin
                    done  <= 1'b1;
                    state <= IDLE;
                    if (special)       result <= special_val;
                    else if (want_rem) result <= neg_r ? (~rem[31:0] + 32'd1) : rem[31:0];
                    else               result <= neg_q ? (~quot + 32'd1)      : quot;
                end
                default: state <= IDLE;
            endcase
        end
    end

    assign busy = (state != IDLE);
endmodule
