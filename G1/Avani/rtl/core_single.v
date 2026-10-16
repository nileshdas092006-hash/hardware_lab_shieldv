// core_single.v - single-cycle RV32IM core (Avani's week-1 milestone)
// Owner: Avani (G1)
//
// Every instruction is fetched, decoded, executed and written back in ONE
// clock cycle. It is slow (the clock must wait for the longest instruction)
// but simple, so it is the first working CPU of the project. Laxmidhar's
// core_pipe.v reuses the same blocks and cuts them into 3 stages.
//
// SIMULATION ONLY: the memories here answer instantly (asynchronous read),
// which a single-cycle CPU needs. The FPGA version is the pipelined core.
// Multiply/divide use Verilog * and / directly, like the M-unit stub.
module core_single #(
    parameter IMEM_INIT = "imem.hex",
    parameter DMEM_INIT = ""
) (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] pc_out,
    output wire        io_we,          // store to the I/O region (0x1000_xxxx)
    output wire [31:0] io_addr,
    output wire [31:0] io_wdata
);
    reg [31:0] imem [0:4095];
    reg [31:0] dmem [0:4095];
    integer i;
    initial begin
        for (i = 0; i < 4096; i = i + 1) begin imem[i] = 32'h13; dmem[i] = 32'd0; end
        if (IMEM_INIT != "") $readmemh(IMEM_INIT, imem);
        if (DMEM_INIT != "") $readmemh(DMEM_INIT, dmem);
    end

    // ---- fetch ----
    reg  [31:0] pc;
    wire [31:0] instr = imem[pc[13:2]];

    // ---- decode ----
    wire [4:0]  rs1, rs2, rd;
    wire [2:0]  funct3;
    wire [3:0]  alu_op;
    wire        a_pc, b_imm, reg_write, is_load, is_store, is_branch, is_jal, is_jalr, is_mop, illegal;
    wire [1:0]  wb_sel;
    wire [31:0] imm, rs1_val, rs2_val, wd;

    decoder u_dec (.instr(instr), .rs1(rs1), .rs2(rs2), .rd(rd), .funct3(funct3),
        .alu_op(alu_op), .alu_src_a_pc(a_pc), .alu_src_b_imm(b_imm), .reg_write(reg_write),
        .wb_sel(wb_sel), .is_load(is_load), .is_store(is_store), .is_branch(is_branch),
        .is_jal(is_jal), .is_jalr(is_jalr), .is_mop(is_mop), .illegal(illegal));
    imm_gen u_imm (.instr(instr), .imm(imm));
    regfile #(.WRITE_THROUGH(0)) u_rf (.clk(clk), .ra1(rs1), .ra2(rs2), .rd1(rs1_val), .rd2(rs2_val),
                  .we(reg_write & rst_n), .wa(rd), .wd(wd));

    // ---- execute ----
    wire [31:0] alu_y, target, link;
    wire        taken;
    alu u_alu (.a(a_pc ? pc : rs1_val), .b(b_imm ? imm : rs2_val), .op(alu_op), .y(alu_y));
    branch_unit u_br (.pc(pc), .rs1_val(rs1_val), .rs2_val(rs2_val), .imm(imm), .funct3(funct3),
        .is_branch(is_branch), .is_jal(is_jal), .is_jalr(is_jalr),
        .taken(taken), .target(target), .link(link));

    // behavioural RV32M (same results as the real M-unit, without the waiting)
    reg [31:0] m_res;
    wire signed [63:0] p_ss = $signed(rs1_val) * $signed(rs2_val);
    wire        [63:0] p_uu = rs1_val * rs2_val;
    wire signed [63:0] p_su = $signed({{32{rs1_val[31]}}, rs1_val}) * $signed({32'd0, rs2_val});
    // computed separately: inside ?: with unsigned operands the division would be unsigned
    wire        [31:0] d_safe = (rs2_val == 0 || (rs1_val == 32'h8000_0000 && rs2_val == 32'hFFFF_FFFF))
                                ? 32'd1 : rs2_val;          // avoid x/0 and overflow inside the simulator
    wire        [31:0] d_nz   = (rs2_val == 0) ? 32'd1 : rs2_val;
    wire signed [31:0] q_s = $signed(rs1_val) / $signed(d_safe);
    wire signed [31:0] r_s = $signed(rs1_val) % $signed(d_safe);
    always @* begin
        case (funct3)
            3'd0: m_res = p_ss[31:0];
            3'd1: m_res = p_ss[63:32];
            3'd2: m_res = p_su[63:32];
            3'd3: m_res = p_uu[63:32];
            3'd4: m_res = (rs2_val == 0) ? 32'hFFFF_FFFF :
                          (rs1_val == 32'h8000_0000 && rs2_val == 32'hFFFF_FFFF) ? 32'h8000_0000 :
                          q_s;
            3'd5: m_res = (rs2_val == 0) ? 32'hFFFF_FFFF : rs1_val / d_nz;
            3'd6: m_res = (rs2_val == 0) ? rs1_val :
                          (rs1_val == 32'h8000_0000 && rs2_val == 32'hFFFF_FFFF) ? 32'd0 :
                          r_s;
            default: m_res = (rs2_val == 0) ? rs1_val : rs1_val % d_nz;
        endcase
    end

    // ---- memory ----
    wire        is_io = (alu_y[31:28] == 4'h1);
    wire [31:0] word  = dmem[alu_y[13:2]];
    wire [1:0]  off   = alu_y[1:0];
    wire [31:0] sh    = word >> {off, 3'b000};
    reg  [31:0] load_data;
    always @* begin
        case (funct3)
            3'b000:  load_data = {{24{sh[7]}}, sh[7:0]};
            3'b001:  load_data = {{16{sh[15]}}, sh[15:0]};
            3'b100:  load_data = {24'd0, sh[7:0]};
            3'b101:  load_data = {16'd0, sh[15:0]};
            default: load_data = word;
        endcase
    end

    always @(posedge clk) begin
        if (rst_n && is_store && !is_io) begin
            case (funct3[1:0])
                2'b00: case (off)
                         2'd0: dmem[alu_y[13:2]][7:0]   <= rs2_val[7:0];
                         2'd1: dmem[alu_y[13:2]][15:8]  <= rs2_val[7:0];
                         2'd2: dmem[alu_y[13:2]][23:16] <= rs2_val[7:0];
                         2'd3: dmem[alu_y[13:2]][31:24] <= rs2_val[7:0];
                       endcase
                2'b01: if (off[1]) dmem[alu_y[13:2]][31:16] <= rs2_val[15:0];
                       else        dmem[alu_y[13:2]][15:0]  <= rs2_val[15:0];
                default: dmem[alu_y[13:2]] <= rs2_val;
            endcase
        end
    end

    assign io_we    = rst_n & is_store & is_io;
    assign io_addr  = alu_y;
    assign io_wdata = rs2_val;

    // ---- writeback ----
    wb_mux u_wb (.sel(wb_sel), .alu_y(alu_y), .load_data(is_io ? 32'd0 : load_data),
                 .link(link), .m_result(m_res), .wd(wd));

    // ---- next PC ----
    always @(posedge clk) begin
        if (!rst_n)     pc <= 32'd0;
        else if (taken) pc <= target;
        else            pc <= pc + 32'd4;
    end

    assign pc_out = pc;
    wire unused_ok = is_mop | illegal;
endmodule
