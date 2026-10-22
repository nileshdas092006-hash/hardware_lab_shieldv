// munit_stub.v - stand-in M-unit for early integration (rung I0/I1)
// Owner: Nishant (G2)
//
// Obeys IF-1 exactly like the real munit.v, but computes with Verilog's own
// * and / operators and fakes the waiting with a counter. G1 uses it so the
// core can run MUL/DIV programs before the real unit is finished.
// SIMULATION ONLY (behavioural division does not synthesise well).
module munit_stub #(
    parameter DELAY = 3
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [2:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire        busy,
    output reg         done,
    output reg  [31:0] result
);
    reg [7:0]  count;
    reg [31:0] value;

    wire signed [63:0] p_ss = $signed(a) * $signed(b);
    wire        [63:0] p_uu = a * b;
    wire signed [63:0] p_su = $signed({{32{a[31]}}, a}) * $signed({32'd0, b});
    // signed quotient/remainder computed on their own: inside a ?: with
    // unsigned operands Verilog would silently do an UNSIGNED division
    // (b_safe avoids x/0 and INT_MIN/-1, which crash some simulators; those
    //  cases are answered by the spec rules below anyway)
    wire        [31:0] b_safe = (b == 0 || (a == 32'h8000_0000 && b == 32'hFFFF_FFFF)) ? 32'd1 : b;
    wire        [31:0] b_nz   = (b == 0) ? 32'd1 : b;
    wire signed [31:0] q_s = $signed(a) / $signed(b_safe);
    wire signed [31:0] r_s = $signed(a) % $signed(b_safe);

    always @* begin
        case (op)
            3'd0: value = p_ss[31:0];
            3'd1: value = p_ss[63:32];
            3'd2: value = p_su[63:32];
            3'd3: value = p_uu[63:32];
            3'd4: value = (b == 0) ? 32'hFFFF_FFFF :
                          (a == 32'h8000_0000 && b == 32'hFFFF_FFFF) ? 32'h8000_0000 :
                          q_s;
            3'd5: value = (b == 0) ? 32'hFFFF_FFFF : a / b_nz;
            3'd6: value = (b == 0) ? a :
                          (a == 32'h8000_0000 && b == 32'hFFFF_FFFF) ? 32'd0 :
                          r_s;
            default: value = (b == 0) ? a : a % b_nz;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            count <= 8'd0; done <= 1'b0; result <= 32'd0;
        end else begin
            done <= 1'b0;
            if (start) begin
                count  <= DELAY;
                result <= value;
            end else if (count != 8'd0) begin
                count <= count - 8'd1;
                if (count == 8'd1) done <= 1'b1;
            end
        end
    end

    assign busy = (count != 8'd0);
endmodule
