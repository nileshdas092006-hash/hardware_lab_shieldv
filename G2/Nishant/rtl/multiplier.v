// multiplier.v - MUL, MULH, MULHSU, MULHU (block B1)
// Owner: Nishant (G2)
//
// The trick: extend both 32-bit inputs to 33 bits.
//   signed input   -> copy its sign bit into bit 32
//   unsigned input -> put a 0 into bit 32
// Then ONE signed 33 x 33 multiply gives the correct 66-bit product for all
// four instructions; we just pick the low or high 32 bits.
//
//   op  | instruction | a      | b        | result
//   000 | MUL         | either | either   | product[31:0]
//   001 | MULH        | signed | signed   | product[63:32]
//   010 | MULHSU      | signed | unsigned | product[63:32]
//   011 | MULHU       | unsign.| unsigned | product[63:32]
//
// Timing (2 cycles, fits the DSP48 blocks' internal registers):
//   cycle 0: start=1, operands captured
//   cycle 1: multiply, product registered
//   cycle 2: done=1, result valid
module multiplier (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [1:0]  op,          // funct3[1:0]
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire        busy,
    output reg         done,
    output wire [31:0] result
);
    reg signed [32:0] a_r, b_r;
    reg        [1:0]  op_r, op_r2;
    reg               s1;               // a multiply is in flight
    reg signed [65:0] prod;

    wire a_signed = (op == 2'b01) || (op == 2'b10);
    wire b_signed = (op == 2'b01);

    always @(posedge clk) begin
        if (!rst_n) begin
            s1 <= 1'b0; done <= 1'b0; op_r <= 2'b00; op_r2 <= 2'b00;
            a_r <= 33'sd0; b_r <= 33'sd0; prod <= 66'sd0;
        end else begin
            // stage 1: capture operands with their 33rd bit
            s1 <= start;
            if (start) begin
                a_r  <= {a_signed & a[31], a};
                b_r  <= {b_signed & b[31], b};
                op_r <= op;
            end
            // stage 2: multiply (maps onto DSP48E1 slices)
            done <= s1;
            if (s1) begin
                prod  <= a_r * b_r;
                op_r2 <= op_r;
            end
        end
    end

    assign busy   = s1;
    assign result = (op_r2 == 2'b00) ? prod[31:0] : prod[63:32];
endmodule
