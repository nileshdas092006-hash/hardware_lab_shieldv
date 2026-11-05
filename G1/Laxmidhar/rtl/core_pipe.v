// core_pipe.v - the 3-stage pipelined RV32IM core
// Owner: Laxmidhar (G1), built from Avani's datapath blocks
//
//   Stage 1  IF/ID : PC -> instruction RAM -> decoder, immediate gen, register read
//   Stage 2  EX    : forwarding -> ALU, branch unit, M-unit start, ShieldV check,
//                    data-bus request (address computed here)
//   Stage 3  MEM/WB: data-bus answer -> load alignment -> write register
//
// Interfaces (see docs/interfaces.md):
//   IF-1 M-unit, IF-2 data bus, IF-3 ShieldV, IF-4 trace port
module core_pipe #(
    parameter IMEM_INIT = "imem.hex"
) (
    input  wire        clk,
    input  wire        rst_n,

    // IF-1: core <-> M-unit
    output wire        m_start,
    output wire [2:0]  m_op,
    output wire [31:0] m_a,
    output wire [31:0] m_b,
    input  wire        m_busy,
    input  wire        m_done,
    input  wire [31:0] m_result,

    // IF-2: core <-> data bus
    output wire [31:0] bus_addr,
    output wire [31:0] bus_wdata,
    output wire [3:0]  bus_wstrb,
    output wire        bus_we,
    output wire        bus_re,
    input  wire [31:0] bus_rdata,

    // IF-3: EX stage <-> ShieldV
    output wire        ex_valid,
    output wire [31:0] ex_instr,
    output wire [31:0] ex_pc,
    output wire [31:0] ex_target,
    output wire [31:0] ex_link,
    input  wire        sh_freeze,
    input  wire        sh_trap,
    input  wire [31:0] sh_handler_pc,

    // IF-4: trace port (registered copies)
    output wire [31:0] tr_if_pc,
    output wire [31:0] tr_ex_pc,
    output wire [31:0] tr_wb_pc,
    output wire        tr_stall,
    output wire        tr_flush,
    output wire        tr_ex_valid,
    output wire        tr_retire,
    output wire        tr_branch,       // a branch/jump left EX this cycle (registered)
    output wire        tr_mispredict    // ... and redirected the PC: static "not taken" was wrong
);
    // ------------------------------------------------------------------
    // packed control word carried from IF/ID into EX
    // ------------------------------------------------------------------
    localparam CTRL_W = 15;
    // bit positions
    localparam C_MOP    = 0;
    localparam C_JALR   = 1;
    localparam C_JAL    = 2;
    localparam C_BRANCH = 3;
    localparam C_STORE  = 4;
    localparam C_LOAD   = 5;
    localparam C_WBSEL  = 6;   // 2 bits: [7:6]
    localparam C_REGW   = 8;
    localparam C_BIMM   = 9;
    localparam C_APC    = 10;
    localparam C_ALUOP  = 11;  // 4 bits: [14:11]

    // global pipeline control (driven further down)
    wire stall;            // hold PC, IF/ID and EX
    wire wb_bubble;        // send a bubble into MEM/WB
    wire flush_ifid;       // throw away the IF/ID instruction
    wire kill_ex;          // the EX instruction must not complete (trap)
    wire ex_redirect;      // taken branch/jump leaving EX
    wire [31:0] br_target;

    // MEM/WB values needed earlier (forwarding, register write)
    wire        w_valid;
    wire [4:0]  w_rd;
    wire        w_reg_write;
    wire [31:0] w_value;

    // ==================================================================
    // Stage 1: IF/ID
    // ==================================================================
    wire [31:0] f_pc, f_pc_next, f_instr;

    pc_reg u_pc (
        .clk(clk), .rst_n(rst_n),
        .hold(stall),
        .trap(sh_trap),           .trap_pc(sh_handler_pc),
        .redirect(ex_redirect),   .target(br_target),
        .pc(f_pc),                .pc_next(f_pc_next)
    );

    imem #(.INIT_FILE(IMEM_INIT)) u_imem (
        .clk(clk), .addr(f_pc_next), .rdata(f_instr)
    );

    wire [4:0]  d_rs1, d_rs2, d_rd;
    wire [2:0]  d_funct3;
    wire [3:0]  d_alu_op;
    wire        d_a_pc, d_b_imm, d_reg_write, d_load, d_store, d_branch, d_jal, d_jalr, d_mop, d_illegal;
    wire [1:0]  d_wb_sel;
    wire [31:0] d_imm, d_rs1_val, d_rs2_val;

    decoder u_dec (
        .instr(f_instr),
        .rs1(d_rs1), .rs2(d_rs2), .rd(d_rd), .funct3(d_funct3),
        .alu_op(d_alu_op), .alu_src_a_pc(d_a_pc), .alu_src_b_imm(d_b_imm),
        .reg_write(d_reg_write), .wb_sel(d_wb_sel),
        .is_load(d_load), .is_store(d_store), .is_branch(d_branch),
        .is_jal(d_jal), .is_jalr(d_jalr), .is_mop(d_mop), .illegal(d_illegal)
    );

    imm_gen u_imm (.instr(f_instr), .imm(d_imm));

    regfile u_rf (
        .clk(clk),
        .ra1(d_rs1), .ra2(d_rs2), .rd1(d_rs1_val), .rd2(d_rs2_val),
        .we(w_valid & w_reg_write), .wa(w_rd), .wd(w_value)
    );

    wire [CTRL_W-1:0] d_ctrl = {d_alu_op, d_a_pc, d_b_imm, d_reg_write, d_wb_sel,
                                d_load, d_store, d_branch, d_jal, d_jalr, d_mop};

    // ==================================================================
    // IF/ID -> EX pipeline register
    // ==================================================================
    wire              e_valid;
    wire [31:0]       e_pc, e_instr, e_rs1_raw, e_rs2_raw, e_imm;
    wire [CTRL_W-1:0] e_ctrl;

    pipe_ifid_ex #(.CTRL_W(CTRL_W)) u_p1 (
        .clk(clk), .rst_n(rst_n), .stall(stall), .flush(flush_ifid),
        .d_valid(1'b1), .d_pc(f_pc), .d_instr(f_instr),
        .d_rs1_val(d_rs1_val), .d_rs2_val(d_rs2_val), .d_imm(d_imm), .d_ctrl(d_ctrl),
        .q_valid(e_valid), .q_pc(e_pc), .q_instr(e_instr),
        .q_rs1_val(e_rs1_raw), .q_rs2_val(e_rs2_raw), .q_imm(e_imm), .q_ctrl(e_ctrl)
    );

    // ==================================================================
    // Stage 2: EX
    // ==================================================================
    wire [4:0] e_rs1 = e_instr[19:15];
    wire [4:0] e_rs2 = e_instr[24:20];
    wire [4:0] e_rd  = e_instr[11:7];
    wire [2:0] e_funct3 = e_instr[14:12];

    wire       e_mop    = e_ctrl[C_MOP];
    wire       e_jalr   = e_ctrl[C_JALR];
    wire       e_jal    = e_ctrl[C_JAL];
    wire       e_branch = e_ctrl[C_BRANCH];
    wire       e_store  = e_ctrl[C_STORE];
    wire       e_load   = e_ctrl[C_LOAD];
    wire [1:0] e_wb_sel = e_ctrl[C_WBSEL+1:C_WBSEL];
    wire       e_regw   = e_ctrl[C_REGW];
    wire       e_b_imm  = e_ctrl[C_BIMM];
    wire       e_a_pc   = e_ctrl[C_APC];
    wire [3:0] e_alu_op = e_ctrl[C_ALUOP+3:C_ALUOP];

    // forwarding
    wire fwd_a, fwd_b;
    forward_unit u_fwd (
        .ex_rs1(e_rs1), .ex_rs2(e_rs2),
        .wb_valid(w_valid), .wb_reg_write(w_reg_write), .wb_rd(w_rd),
        .fwd_a(fwd_a), .fwd_b(fwd_b)
    );
    wire [31:0] e_rs1_val = fwd_a ? w_value : e_rs1_raw;
    wire [31:0] e_rs2_val = fwd_b ? w_value : e_rs2_raw;

    // ALU
    wire [31:0] alu_a = e_a_pc  ? e_pc  : e_rs1_val;
    wire [31:0] alu_b = e_b_imm ? e_imm : e_rs2_val;
    wire [31:0] alu_y;
    alu u_alu (.a(alu_a), .b(alu_b), .op(e_alu_op), .y(alu_y));

    // branches and jumps
    wire        br_taken;
    wire [31:0] br_link;
    branch_unit u_br (
        .pc(e_pc), .rs1_val(e_rs1_val), .rs2_val(e_rs2_val), .imm(e_imm),
        .funct3(e_funct3), .is_branch(e_branch), .is_jal(e_jal), .is_jalr(e_jalr),
        .taken(br_taken), .target(br_target), .link(br_link)
    );

    // M-unit handshake (IF-1): pulse start once, wait for done
    reg m_pending;
    wire m_wait = e_valid & e_mop & ~m_done;
    assign m_start = e_valid & e_mop & ~m_pending & ~m_done;
    assign m_op    = e_funct3;
    assign m_a     = e_rs1_val;
    assign m_b     = e_rs2_val;

    always @(posedge clk) begin
        if (!rst_n)       m_pending <= 1'b0;
        else if (m_done)  m_pending <= 1'b0;
        else if (m_start) m_pending <= 1'b1;
    end

    // stall and flush control
    hazard_unit u_hz (.m_wait(m_wait), .sh_freeze(sh_freeze), .stall(stall), .wb_bubble(wb_bubble));

    wire ex_commit = e_valid & ~stall;                   // the EX instruction finishes this cycle
    assign ex_redirect = ex_commit & br_taken & ~sh_trap;

    flush_unit u_fl (.ex_redirect(ex_redirect), .sh_trap(sh_trap),
                     .flush_ifid(flush_ifid), .kill_ex(kill_ex));

    // IF-3 to ShieldV. ex_valid ignores sh_freeze on purpose (ShieldV makes
    // sh_freeze from ex_valid, so including it would form a loop).
    assign ex_valid  = e_valid & ~m_wait;
    assign ex_instr  = e_instr;
    assign ex_pc     = e_pc;
    assign ex_target = br_target;
    assign ex_link   = br_link;

    // data bus request (IF-2); memory answers in the next cycle
    wire mem_ok = ex_commit & ~kill_ex;
    wire [3:0]  st_wstrb;
    wire [31:0] st_wdata, w_load_data;
    wire [2:0]  w_funct3;
    wire [31:0] w_alu_y, w_m_result, w_pc, w_instr;
    wire [1:0]  w_wb_sel;

    lsu u_lsu (
        .st_funct3(e_funct3), .st_offset(alu_y[1:0]), .st_data(e_rs2_val),
        .st_en(e_store), .wstrb(st_wstrb), .wdata(st_wdata),
        .ld_funct3(w_funct3), .ld_offset(w_alu_y[1:0]), .rdata(bus_rdata),
        .load_data(w_load_data)
    );

    assign bus_addr  = alu_y;
    assign bus_wdata = st_wdata;
    assign bus_wstrb = st_wstrb;
    assign bus_we    = mem_ok & e_store;
    assign bus_re    = mem_ok & e_load;

    // ==================================================================
    // EX -> MEM/WB pipeline register
    // ==================================================================
    pipe_ex_wb u_p2 (
        .clk(clk), .rst_n(rst_n), .bubble(wb_bubble | kill_ex),
        .d_valid(e_valid), .d_pc(e_pc), .d_instr(e_instr), .d_rd(e_rd),
        .d_reg_write(e_regw), .d_wb_sel(e_wb_sel), .d_alu_y(alu_y),
        .d_m_result(m_result), .d_funct3(e_funct3),
        .q_valid(w_valid), .q_pc(w_pc), .q_instr(w_instr), .q_rd(w_rd),
        .q_reg_write(w_reg_write), .q_wb_sel(w_wb_sel), .q_alu_y(w_alu_y),
        .q_m_result(w_m_result), .q_funct3(w_funct3)
    );

    // ==================================================================
    // Stage 3: MEM/WB
    // ==================================================================
    wb_mux u_wb (
        .sel(w_wb_sel), .alu_y(w_alu_y), .load_data(w_load_data),
        .link(w_pc + 32'd4), .m_result(w_m_result), .wd(w_value)
    );

    // ==================================================================
    // IF-4 trace port
    // ==================================================================
    trace_port u_tr (
        .clk(clk), .rst_n(rst_n),
        .if_pc_i(f_pc), .ex_pc_i(e_pc), .wb_pc_i(w_pc),
        .stall_i(stall), .flush_i(flush_ifid), .ex_valid_i(ex_valid & ~stall),
        .retire_i(w_valid),
        .branch_i(mem_ok & (e_branch | e_jal | e_jalr)), .mispredict_i(ex_redirect),
        .if_pc(tr_if_pc), .ex_pc(tr_ex_pc), .wb_pc(tr_wb_pc),
        .stall(tr_stall), .flush(tr_flush), .ex_valid(tr_ex_valid), .retire(tr_retire),
        .branch(tr_branch), .mispredict(tr_mispredict)
    );

    // ==================================================================
    // Commit view for the system testbench (soc_tb.v). The out-of-order core
    // has wires with the same names, so one testbench checks both cores.
    //   cm_*   : the instruction that finishes (writes back) this cycle
    //   dbg_ex_* : the instruction being executed / checked by ShieldV
    // ==================================================================
    wire        cm_valid  = w_valid;
    wire [31:0] cm_pc     = w_pc;
    wire [31:0] cm_instr  = w_instr;
    wire [4:0]  cm_rd     = w_rd;
    wire        cm_we     = w_reg_write;
    wire [31:0] cm_value  = w_value;
    wire [31:0] cm_addr   = w_alu_y;
    wire        dbg_ex_valid = e_valid;          // something is in EX (maybe stalled)
    wire        dbg_ex_go    = e_valid & ~stall; // ... and it is executing this cycle

    // m_busy is part of the IF-1 contract; the core relies on done instead.
    wire unused_ok = m_busy | d_illegal | (|w_instr);
endmodule
