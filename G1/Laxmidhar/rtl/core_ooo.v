// core_ooo.v - the out-of-order RV32IM core (Tomasulo), goal tier
// Owner: Laxmidhar (G1), front-end predictors by Avani (G1)
//
// Same ports as core_pipe.v, so soc_top picks either one with a build option.
// Same datapath blocks too (decoder, imm_gen, regfile, alu, branch_unit, lsu,
// pc_reg, imem); what is new is how instructions flow:
//
//   FETCH + DISPATCH (1 stage)
//     pc_reg -> imem -> decoder / imm_gen
//     predict the next PC: tournament predictor (branches), BTB (indirect
//       jalr), return-address stack (returns), jal target computed directly
//     rename: look up rs1/rs2 in the rename table -> value (register file or
//       reorder buffer or CDB this cycle) or the tag of the producer
//     allocate a reorder-buffer entry, then one of
//       ALU reservation station (4)  : ALU ops, branches, jalr
//       MUL reservation station (2)  : MUL/DIV (Nishant's munit, IF-1)
//       load/store queue (8)         : loads, stores
//       nothing                      : jal, lui, auipc, fence/ecall (done at once)
//   ISSUE + EXECUTE (out of order)
//     a station sends the first instruction whose operands are ready
//     ALU 1 cycle, M-unit 2 / 34 cycles, loads 1 cycle on the data bus
//   COMPLETE: the result is broadcast on the common data bus (cdb_arbiter);
//     loads and M-unit results wait in a holding register for their turn,
//     an ALU result goes on the bus in the same cycle if it is free. The
//     broadcast wakes up waiting instructions and marks the reorder-buffer
//     entry done
//   COMMIT (in order, 1 per cycle): the oldest entry, once done, is shown to
//     ShieldV on IF-3 exactly like the in-order core's EX stage. If ShieldV
//     does not freeze or trap: write the register file, send a store to
//     memory, train the predictors. A mispredicted branch/jump flushes
//     everything younger and restarts fetch at the right address.
//
// Nothing becomes visible (register file, memory, I/O, shadow stack) before
// commit, so wrong-path instructions leave no trace and ShieldV checks
// returns in program order, at the same point the program would.
//
// Simplifications (on purpose, to keep it explainable):
//   * mispredictions are repaired at commit, not at execute
//   * no store-to-load forwarding (a load waits for an older store to the
//     same word to commit)
//   * single issue: at most one instruction dispatched and one committed per cycle
module core_ooo #(
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

    // IF-3: commit (reorder-buffer head) <-> ShieldV
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
    output wire        tr_branch,
    output wire        tr_mispredict
);
    localparam TAG_W  = 4;
    localparam HIST_W = 8;

    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_REG    = 7'b0110011;

    // ---------------- global control (driven further down) ----------------
    wire        disp;               // the fetched instruction enters the back end
    wire        commit;             // the reorder-buffer head retires
    wire        flush;              // throw away everything not committed
    wire        mispredict_flush;   // ... because the head was mispredicted
    wire [31:0] head_npc;           // where the head really goes next

    // common data bus
    wire             cdb_valid, cdb_taken, cdb_mispred;
    wire [TAG_W-1:0] cdb_tag;
    wire [31:0]      cdb_value, cdb_aux;

    // ==================================================================
    // FETCH + PREDICT
    // ==================================================================
    wire [31:0] f_pc, f_pc_next, f_instr;
    wire [31:0] pred_npc;

    pc_reg u_pc (
        .clk(clk), .rst_n(rst_n),
        .hold(~disp & ~flush),
        .trap(sh_trap),                       .trap_pc(sh_handler_pc),
        .redirect(mispredict_flush | disp),   .target(mispredict_flush ? head_npc : pred_npc),
        .pc(f_pc),                            .pc_next(f_pc_next)
    );

    imem #(.INIT_FILE(IMEM_INIT)) u_imem (.clk(clk), .addr(f_pc_next), .rdata(f_instr));

    wire [4:0]  d_rs1, d_rs2, d_rd;
    wire [2:0]  d_funct3;
    wire [3:0]  d_alu_op;
    wire        d_a_pc, d_b_imm, d_reg_write, d_load, d_store, d_branch, d_jal, d_jalr, d_mop, d_illegal;
    wire [1:0]  d_wb_sel;
    wire [31:0] d_imm;

    decoder u_dec (
        .instr(f_instr),
        .rs1(d_rs1), .rs2(d_rs2), .rd(d_rd), .funct3(d_funct3),
        .alu_op(d_alu_op), .alu_src_a_pc(d_a_pc), .alu_src_b_imm(d_b_imm),
        .reg_write(d_reg_write), .wb_sel(d_wb_sel),
        .is_load(d_load), .is_store(d_store), .is_branch(d_branch),
        .is_jal(d_jal), .is_jalr(d_jalr), .is_mop(d_mop), .illegal(d_illegal)
    );
    imm_gen u_imm (.instr(f_instr), .imm(d_imm));

    wire [6:0]  d_opcode   = f_instr[6:0];
    wire [31:0] f_pc4      = f_pc + 32'd4;
    wire [31:0] f_pc_imm   = f_pc + d_imm;

    // call / return, same rules as ShieldV (x1 and x5 are link registers)
    wire d_rd_link  = (d_rd == 5'd1)  || (d_rd == 5'd5);
    wire d_rs1_link = (d_rs1 == 5'd1) || (d_rs1 == 5'd5);
    wire d_call     = (d_jal | d_jalr) & d_rd_link;
    wire d_ret      = d_jalr & d_rs1_link & (~d_rd_link | (d_rd != d_rs1));

    // predictors (Avani)
    wire              bp_taken, btb_hit, ras_empty;
    wire [HIST_W-1:0] bp_hist;
    wire [31:0]       btb_target, ras_top;

    // commit-side training signals (driven in the COMMIT section)
    wire              tr_cond_en, btb_upd_en, ras_c_push, ras_c_pop;
    wire [31:0]       h_pc, h_aux;
    wire [HIST_W-1:0] h_hist;
    wire              h_taken;

    bp_tournament #(.HIST_W(HIST_W)) u_bp (
        .clk(clk), .rst_n(rst_n),
        .pred_pc(f_pc), .pred_taken(bp_taken), .pred_hist(bp_hist),
        .spec_shift(disp & d_branch), .spec_taken(bp_taken),
        .upd_en(tr_cond_en), .upd_pc(h_pc), .upd_hist(h_hist), .upd_taken(h_taken),
        .restore(flush)
    );
    btb u_btb (
        .clk(clk), .rst_n(rst_n), .pc(f_pc), .hit(btb_hit), .target(btb_target),
        .upd_en(btb_upd_en), .upd_pc(h_pc), .upd_target(h_aux)
    );
    ras u_ras (
        .clk(clk), .rst_n(rst_n),
        .push(disp & d_call), .pop(disp & d_ret), .push_addr(f_pc4),
        .top(ras_top), .empty(ras_empty),
        .c_push(ras_c_push), .c_pop(ras_c_pop), .c_push_addr(h_pc + 32'd4),
        .restore(flush)
    );

    assign pred_npc = d_jal    ? f_pc_imm :
                      d_jalr   ? (d_ret ? (ras_empty ? f_pc4 : ras_top) : (btb_hit ? btb_target : f_pc4)) :
                      d_branch ? (bp_taken ? f_pc_imm : f_pc4) :
                                 f_pc4;

    // ==================================================================
    // RENAME + DISPATCH
    // ==================================================================
    // which part of the back end does this instruction need?
    wire need_alu = (d_branch | d_jalr | (d_opcode == OP_IMM) | (d_opcode == OP_REG & ~d_mop)) & ~d_illegal;
    wire need_mul = d_mop;
    wire need_mem = d_load | d_store;
    wire done_now = ~need_alu & ~need_mul & ~need_mem;     // jal, lui, auipc, fence, ecall, illegal

    wire uses_rs1 = ~((d_opcode == OP_LUI) | (d_opcode == OP_AUIPC) | d_jal);
    wire uses_rs2 = (d_opcode == OP_REG) | (d_opcode == OP_BRANCH) | (d_opcode == OP_STORE);

    wire [31:0] now_value = d_jal                    ? f_pc4 :
                            (d_opcode == OP_LUI)     ? d_imm :
                            (d_opcode == OP_AUIPC)   ? f_pc_imm : 32'd0;

    // structures
    wire             rob_full, alu_full, mul_full, lsq_full;
    wire [TAG_W-1:0] alloc_tag;

    wire res_ok = ~rob_full & ~(need_alu & alu_full) & ~(need_mul & mul_full) & ~(need_mem & lsq_full);
    assign disp = rst_n & res_ok & ~flush & ~sh_freeze;

    // operand lookup: register file, or the reorder buffer, or the CDB right now
    wire             rat_busy1, rat_busy2;
    wire [TAG_W-1:0] rat_tag1, rat_tag2;
    wire             rob_done1, rob_done2;
    wire [31:0]      rob_val1, rob_val2, arf1, arf2;

    // commit-side register write (driven in the COMMIT section)
    wire        arf_we;
    wire [4:0]  h_rd;
    wire [31:0] h_value;
    wire [TAG_W-1:0] h_tag;

    rename_table #(.TAG_W(TAG_W)) u_rat (
        .clk(clk), .rst_n(rst_n), .flush(flush),
        .ra1(d_rs1), .ra2(d_rs2),
        .busy1(rat_busy1), .tag1(rat_tag1), .busy2(rat_busy2), .tag2(rat_tag2),
        .d_we(disp & d_reg_write), .d_rd(d_rd), .d_tag(alloc_tag),
        .c_en(arf_we), .c_rd(h_rd), .c_tag(h_tag)
    );

    regfile u_rf (
        .clk(clk),
        .ra1(d_rs1), .ra2(d_rs2), .rd1(arf1), .rd2(arf2),
        .we(arf_we), .wa(h_rd), .wd(h_value)
    );

    wire cdb_hit1 = cdb_valid & (cdb_tag == rat_tag1);
    wire cdb_hit2 = cdb_valid & (cdb_tag == rat_tag2);
    wire        op1_r = ~uses_rs1 | ~rat_busy1 | rob_done1 | cdb_hit1;
    wire        op2_r = ~uses_rs2 | ~rat_busy2 | rob_done2 | cdb_hit2;
    wire [31:0] op1_v = ~rat_busy1 ? arf1 : cdb_hit1 ? cdb_value : rob_val1;
    wire [31:0] op2_v = ~rat_busy2 ? arf2 : cdb_hit2 ? cdb_value : rob_val2;

    // ---- reorder buffer ----
    wire             rob_head_valid, rob_head_done, rob_head_regw, rob_head_mem, rob_head_store;
    wire             rob_head_ctrl, rob_head_cond, rob_head_taken, rob_head_mispred;
    wire [31:0]      rob_head_pc, rob_head_instr, rob_head_value, rob_head_aux;
    wire [4:0]       rob_head_rd;
    wire [HIST_W-1:0] rob_head_hist;
    wire [TAG_W-1:0] rob_head_tag;
    wire             sr_valid;
    wire [TAG_W-1:0] sr_tag;
    wire [31:0]      sr_addr;

    rob #(.TAG_W(TAG_W), .N(16), .HIST_W(HIST_W)) u_rob (
        .clk(clk), .rst_n(rst_n), .flush(flush),
        .alloc(disp), .a_pc(f_pc), .a_instr(f_instr), .a_rd(d_rd),
        .a_regw(d_reg_write & (d_rd != 5'd0)), .a_mem(need_mem), .a_store(d_store),
        .a_ctrl(d_branch | d_jal | d_jalr), .a_cond(d_branch), .a_hist(bp_hist),
        .a_done(done_now), .a_value(now_value), .a_aux(d_jal ? f_pc_imm : 32'd0), .a_taken(d_jal),
        .alloc_tag(alloc_tag), .full(rob_full),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value), .cdb_aux(cdb_aux),
        .cdb_taken(cdb_taken), .cdb_mispred(cdb_mispred),
        .st_valid(sr_valid), .st_tag(sr_tag), .st_addr(sr_addr),
        .rd_tag1(rat_tag1), .rd_done1(rob_done1), .rd_value1(rob_val1),
        .rd_tag2(rat_tag2), .rd_done2(rob_done2), .rd_value2(rob_val2),
        .head_valid(rob_head_valid), .head_tag(rob_head_tag), .head_done(rob_head_done),
        .head_pc(rob_head_pc), .head_instr(rob_head_instr), .head_rd(rob_head_rd),
        .head_regw(rob_head_regw), .head_mem(rob_head_mem), .head_store(rob_head_store),
        .head_ctrl(rob_head_ctrl), .head_cond(rob_head_cond), .head_hist(rob_head_hist),
        .head_value(rob_head_value), .head_aux(rob_head_aux), .head_taken(rob_head_taken),
        .head_mispred(rob_head_mispred),
        .commit(commit)
    );

    // ---- ALU reservation station ----
    // payload: predicted next PC, pc, imm, alu op, operand selects, funct3, branch / jalr
    localparam ALU_PW = 32 + 32 + 32 + 4 + 1 + 1 + 3 + 1 + 1;
    wire [ALU_PW-1:0] alu_in_pay = {pred_npc, f_pc, d_imm, d_alu_op, d_a_pc, d_b_imm, d_funct3, d_branch, d_jalr};
    wire              x_valid, alu_go;
    wire [ALU_PW-1:0] x_pay;
    wire [TAG_W-1:0]  x_tag;
    wire [31:0]       x_v1, x_v2;

    rs #(.N(4), .PW(ALU_PW), .TAG_W(TAG_W)) u_rs_alu (
        .clk(clk), .rst_n(rst_n), .flush(flush),
        .in_valid(disp & need_alu), .in_payload(alu_in_pay), .in_tag(alloc_tag),
        .in_r1(op1_r), .in_v1(op1_v), .in_q1(rat_tag1),
        .in_r2(op2_r), .in_v2(op2_v), .in_q2(rat_tag2),
        .full(alu_full),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .out_valid(x_valid), .out_payload(x_pay), .out_tag(x_tag), .out_v1(x_v1), .out_v2(x_v2),
        .take(alu_go)
    );

    // ---- MUL/DIV reservation station ----
    wire             mx_valid, mul_go;
    wire [2:0]       mx_op;
    wire [TAG_W-1:0] mx_tag;
    wire [31:0]      mx_v1, mx_v2;

    rs #(.N(2), .PW(3), .TAG_W(TAG_W)) u_rs_mul (
        .clk(clk), .rst_n(rst_n), .flush(flush),
        .in_valid(disp & need_mul), .in_payload(d_funct3), .in_tag(alloc_tag),
        .in_r1(op1_r), .in_v1(op1_v), .in_q1(rat_tag1),
        .in_r2(op2_r), .in_v2(op2_v), .in_q2(rat_tag2),
        .full(mul_full),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .out_valid(mx_valid), .out_payload(mx_op), .out_tag(mx_tag), .out_v1(mx_v1), .out_v2(mx_v2),
        .take(mul_go)
    );

    // ---- load/store queue ----
    wire             ld_req, ld_go;
    wire [31:0]      ld_addr;
    wire [2:0]       ld_funct3;
    wire [TAG_W-1:0] ld_tag;
    wire             lsq_head_valid, lsq_head_store;
    wire [31:0]      lsq_head_addr, lsq_head_data;
    wire [2:0]       lsq_head_funct3;

    lsq #(.N(8), .PTR_W(3), .TAG_W(TAG_W)) u_lsq (
        .clk(clk), .rst_n(rst_n), .flush(flush),
        .in_valid(disp & need_mem), .in_store(d_store), .in_funct3(d_funct3), .in_imm(d_imm),
        .in_tag(alloc_tag),
        .in_rb(op1_r), .in_vb(op1_v), .in_qb(rat_tag1),
        .in_rd(op2_r), .in_vd(op2_v), .in_qd(rat_tag2),
        .full(lsq_full),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .sr_valid(sr_valid), .sr_tag(sr_tag), .sr_addr(sr_addr),
        .rob_head_tag(rob_head_tag),
        .ld_req(ld_req), .ld_addr(ld_addr), .ld_funct3(ld_funct3), .ld_tag(ld_tag), .ld_go(ld_go),
        .head_valid(lsq_head_valid), .head_store(lsq_head_store), .head_addr(lsq_head_addr),
        .head_data(lsq_head_data), .head_funct3(lsq_head_funct3),
        .pop(commit & rob_head_mem)
    );

    // ==================================================================
    // EXECUTE
    // ==================================================================
    // ---- ALU / branch unit ----
    wire [31:0] x_pred_npc = x_pay[ALU_PW-1 -: 32];
    wire [31:0] x_pc       = x_pay[ALU_PW-33 -: 32];
    wire [31:0] x_imm      = x_pay[ALU_PW-65 -: 32];
    wire [3:0]  x_alu_op   = x_pay[10:7];
    wire        x_a_pc     = x_pay[6];
    wire        x_b_imm    = x_pay[5];
    wire [2:0]  x_funct3   = x_pay[4:2];
    wire        x_branch   = x_pay[1];
    wire        x_jalr     = x_pay[0];

    wire [31:0] x_alu_y, x_target, x_link;
    wire        x_taken;
    alu u_alu (.a(x_a_pc ? x_pc : x_v1), .b(x_b_imm ? x_imm : x_v2), .op(x_alu_op), .y(x_alu_y));
    branch_unit u_br (
        .pc(x_pc), .rs1_val(x_v1), .rs2_val(x_v2), .imm(x_imm), .funct3(x_funct3),
        .is_branch(x_branch), .is_jal(1'b0), .is_jalr(x_jalr),
        .taken(x_taken), .target(x_target), .link(x_link)
    );
    wire [31:0] x_npc     = x_taken ? x_target : x_pc + 32'd4;
    wire        x_mispred = (x_branch | x_jalr) & (x_npc != x_pred_npc);

    // holding registers in front of the CDB
    reg              a_valid, a_taken, a_mispred;
    reg [TAG_W-1:0]  a_tag;
    reg [31:0]       a_value, a_aux;
    reg              mh_valid;
    reg [TAG_W-1:0]  mh_tag;
    reg [31:0]       mh_value;
    reg              l_valid;
    reg [TAG_W-1:0]  l_tag;
    reg [31:0]       l_value, l_aux;
    wire             l_grant, m_grant, a_grant;

    // The ALU result goes straight onto the CDB in the same cycle when the bus is
    // free (no parked load, M-unit or ALU result); otherwise it waits in the
    // holding register. The parked result's grant is worked out here from the
    // registers themselves, so alu_go does not depend on the arbiter (no loop).
    wire a_reg_grant = a_valid & ~l_valid & ~mh_valid;
    assign alu_go    = x_valid & (~a_valid | a_reg_grant) & ~flush;
    wire a_direct    = alu_go & ~a_valid & ~l_valid & ~mh_valid;

    always @(posedge clk) begin
        if (!rst_n || flush) begin
            a_valid <= 1'b0;
        end else if (alu_go && !a_direct) begin
            a_valid   <= 1'b1;
            a_tag     <= x_tag;
            a_value   <= x_jalr ? x_link : x_alu_y;
            a_aux     <= x_target;
            a_taken   <= x_taken;
            a_mispred <= x_mispred;
        end else if (a_grant) begin
            a_valid <= 1'b0;
        end
    end

    // ---- M-unit (IF-1), one operation at a time ----
    reg             m_inflight, m_discard;
    reg [TAG_W-1:0] m_tag;
    assign mul_go  = mx_valid & ~m_inflight & ~mh_valid & ~flush;
    assign m_start = mul_go;
    assign m_op    = mx_op;
    assign m_a     = mx_v1;
    assign m_b     = mx_v2;

    always @(posedge clk) begin
        if (!rst_n) begin
            m_inflight <= 1'b0; m_discard <= 1'b0; mh_valid <= 1'b0;
        end else begin
            if (mul_go) begin
                m_inflight <= 1'b1; m_tag <= mx_tag;
            end else if (m_done) begin
                m_inflight <= 1'b0; m_discard <= 1'b0;
            end
            // a flush cannot stop the M-unit; remember to drop its answer
            if (flush && m_inflight && !m_done) m_discard <= 1'b1;

            if (flush)                                   mh_valid <= 1'b0;
            else if (m_done && m_inflight && !m_discard) begin
                mh_valid <= 1'b1; mh_tag <= m_tag; mh_value <= m_result;
            end else if (m_grant)                        mh_valid <= 1'b0;
        end
    end

    // ---- loads: request this cycle, data next cycle (IF-2) ----
    wire store_head_ready = rob_head_valid & rob_head_done & rob_head_store;
    assign ld_go = ld_req & ~store_head_ready & ~flush;   // a committing store owns the bus

    reg              li_valid;
    reg [TAG_W-1:0]  li_tag;
    reg [2:0]        li_funct3;
    reg [31:0]       li_addr;
    always @(posedge clk) begin
        if (!rst_n || flush) li_valid <= 1'b0;
        else begin
            li_valid  <= ld_go;
            li_tag    <= ld_tag;
            li_funct3 <= ld_funct3;
            li_addr   <= ld_addr;
        end
    end

    wire [3:0]  st_wstrb;
    wire [31:0] st_wdata, ld_data;
    lsu u_lsu (
        .st_funct3(lsq_head_funct3), .st_offset(lsq_head_addr[1:0]), .st_data(lsq_head_data),
        .st_en(lsq_head_store), .wstrb(st_wstrb), .wdata(st_wdata),
        .ld_funct3(li_funct3), .ld_offset(li_addr[1:0]), .rdata(bus_rdata), .load_data(ld_data)
    );

    // the load holding register always wins the CDB, so it empties every cycle
    always @(posedge clk) begin
        if (!rst_n || flush) l_valid <= 1'b0;
        else begin
            l_valid <= li_valid;
            l_tag   <= li_tag;
            l_value <= ld_data;
            l_aux   <= li_addr;
        end
    end

    assign bus_addr  = store_head_ready ? lsq_head_addr : ld_addr;
    assign bus_wdata = st_wdata;
    assign bus_wstrb = st_wstrb;
    assign bus_we    = commit & rob_head_store;
    assign bus_re    = ld_go;

    // ---- common data bus ----
    cdb_arbiter #(.TAG_W(TAG_W)) u_cdb (
        .l_valid(l_valid), .l_tag(l_tag), .l_value(l_value), .l_aux(l_aux),
        .m_valid(mh_valid), .m_tag(mh_tag), .m_value(mh_value),
        .a_valid(a_valid | a_direct),
        .a_tag(a_valid ? a_tag : x_tag),
        .a_value(a_valid ? a_value : (x_jalr ? x_link : x_alu_y)),
        .a_aux(a_valid ? a_aux : x_target),
        .a_taken(a_valid ? a_taken : x_taken),
        .a_mispred(a_valid ? a_mispred : x_mispred),
        .l_grant(l_grant), .m_grant(m_grant), .a_grant(a_grant),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value), .cdb_aux(cdb_aux),
        .cdb_taken(cdb_taken), .cdb_mispred(cdb_mispred)
    );

    // ==================================================================
    // COMMIT (in order) and the ShieldV check
    // ==================================================================
    wire head_ready = rob_head_valid & rob_head_done;

    // IF-3: the same five wires the in-order core drives from EX
    assign ex_valid  = head_ready;
    assign ex_instr  = rob_head_instr;
    assign ex_pc     = rob_head_pc;
    assign ex_target = rob_head_aux;
    assign ex_link   = rob_head_pc + 32'd4;

    assign commit           = head_ready & ~sh_freeze & ~sh_trap;
    assign head_npc         = rob_head_taken ? rob_head_aux : rob_head_pc + 32'd4;
    assign mispredict_flush = commit & rob_head_mispred;
    assign flush            = mispredict_flush | sh_trap;   // trap: the head itself is dropped

    assign arf_we  = commit & rob_head_regw;
    assign h_rd    = rob_head_rd;
    assign h_value = rob_head_value;
    assign h_tag   = rob_head_tag;

    // predictor training with the real outcome
    wire [4:0] h_rdf  = rob_head_instr[11:7];
    wire [4:0] h_rs1f = rob_head_instr[19:15];
    wire h_jal   = (rob_head_instr[6:0] == 7'b1101111);
    wire h_jalr  = (rob_head_instr[6:0] == 7'b1100111) && (rob_head_instr[14:12] == 3'b000);
    wire h_rdl   = (h_rdf == 5'd1)  || (h_rdf == 5'd5);
    wire h_rs1l  = (h_rs1f == 5'd1) || (h_rs1f == 5'd5);
    wire h_call  = (h_jal | h_jalr) & h_rdl;
    wire h_ret   = h_jalr & h_rs1l & (~h_rdl | (h_rdf != h_rs1f));

    assign h_pc       = rob_head_pc;
    assign h_aux      = rob_head_aux;
    assign h_hist     = rob_head_hist;
    assign h_taken    = rob_head_taken;
    assign tr_cond_en = commit & rob_head_cond;
    assign btb_upd_en = commit & h_jalr & ~h_ret;
    assign ras_c_push = commit & h_call;
    assign ras_c_pop  = commit & h_ret;

    // ==================================================================
    // IF-4 trace port
    // ==================================================================
    trace_port u_tr (
        .clk(clk), .rst_n(rst_n),
        .if_pc_i(f_pc), .ex_pc_i(rob_head_pc), .wb_pc_i(rob_head_pc),
        .stall_i(~disp), .flush_i(flush), .ex_valid_i(commit),
        .retire_i(commit),
        .branch_i(commit & rob_head_ctrl), .mispredict_i(mispredict_flush),
        .if_pc(tr_if_pc), .ex_pc(tr_ex_pc), .wb_pc(tr_wb_pc),
        .stall(tr_stall), .flush(tr_flush), .ex_valid(tr_ex_valid), .retire(tr_retire),
        .branch(tr_branch), .mispredict(tr_mispredict)
    );

    // commit view for soc_tb.v (same names as in core_pipe.v)
    wire        cm_valid  = commit;
    wire [31:0] cm_pc     = rob_head_pc;
    wire [31:0] cm_instr  = rob_head_instr;
    wire [4:0]  cm_rd     = rob_head_rd;
    wire        cm_we     = rob_head_regw;
    wire [31:0] cm_value  = rob_head_value;
    wire [31:0] cm_addr   = rob_head_aux;
    wire        dbg_ex_valid = head_ready;
    wire        dbg_ex_go    = commit;

    wire unused_ok = m_busy | (|d_wb_sel) | lsq_head_valid | l_grant;
endmodule
