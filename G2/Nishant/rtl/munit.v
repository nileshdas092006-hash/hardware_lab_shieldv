// munit.v - RV32M unit with the start/busy/done handshake (block B3, interface IF-1)
// Owner: Nishant (G2)
//
// The core only ever sees this one contract:
//   pulse start with op/a/b -> wait while busy -> take result when done = 1
// It does not know (or care) that a multiply takes 2 cycles and a divide 34.
// Because of this, G1 could build the core against munit_stub.v long before
// this real unit existed.
//
//   op[2] = 0 -> multiplier (MUL, MULH, MULHSU, MULHU)
//   op[2] = 1 -> divider    (DIV, DIVU, REM, REMU)
module munit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [2:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire        busy,
    output wire        done,
    output wire [31:0] result
);
    wire        mul_busy, mul_done, div_busy, div_done;
    wire [31:0] mul_res, div_res;

    multiplier u_mul (
        .clk(clk), .rst_n(rst_n), .start(start & ~op[2]), .op(op[1:0]),
        .a(a), .b(b), .busy(mul_busy), .done(mul_done), .result(mul_res)
    );

    divider u_div (
        .clk(clk), .rst_n(rst_n), .start(start & op[2]), .op(op[1:0]),
        .a(a), .b(b), .busy(div_busy), .done(div_done), .result(div_res)
    );

    assign busy   = mul_busy | div_busy;
    assign done   = mul_done | div_done;
    assign result = div_done ? div_res : mul_res;
endmodule
