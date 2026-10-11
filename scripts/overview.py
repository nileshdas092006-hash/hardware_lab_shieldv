#!/usr/bin/env python3
"""overview.py - the top-level block diagram (diagrams/top_block_diagram.svg), checked against the RTL.

    python scripts/diagrams.py block    # writes diagrams/top_block_diagram.svg and .png

The LAYOUT (where each box sits) is chosen by hand, so the picture reads like a textbook
diagram. Everything WRITTEN on it is checked against the Verilog before the SVG is written:

  * a box names an instance:  (parent module, instance name, module type) must exist in the
    RTL, e.g. ("core_ooo", "u_rob", "rob"). Boxes for logic written directly inside a module
    (no instance, e.g. the commit logic in core_ooo.v) are marked "logic in <module>.v" and
    every signal they list must be declared in that module.
  * a wire names nets: every (module, net) must be a port, wire or reg of that module, and
    the width printed on the wire, e.g. [31:0], is computed from the declaration.
If anything does not exist, the script stops with an error instead of drawing it.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diagrams as D  # noqa: E402
import sim            # noqa: E402

W, H = 2000, 1160
MODS = D.load_modules()
MODS_O = D.load_modules(("SHIELDV_OOO",))

# instances per parent module (both builds together)
INST = {}
for mods in (MODS, MODS_O):
    for name, m in mods.items():
        for mname, iname in D.list_instances(m, mods):
            INST.setdefault(name, set()).add((iname, mname))

COL = {"Avani": "#dbe6fb", "Laxmidhar": "#d4efe9", "Nishant": "#fbefd9", "Nilesh": "#fde3cf",
       "Priynk": "#fbe0e4", "glue": "#f4f4f4"}
errors = []


def owner(mod):
    return D.OWNER.get(mod, ("", "", ""))[1]


def width(mod, net):
    mm = MODS.get(mod) or MODS_O.get(mod)
    m = MODS_O[mod] if mod == "soc_top" else mm
    if net not in m.decl:
        errors.append(f"net {net} is not declared in {mod}.v")
        return None
    params = dict(m.params)
    for k, v in list(params.items()):
        r = D.safe_eval(v, {kk: vv for kk, vv in params.items() if kk != k})
        if r is not None:
            params[k] = str(r)
    return D.range_width(m.decl[net], params)


BOX = {}
OUT = []


def esc(s):
    return D.esc(s)


def box(key, x, y, w, h, parent, inst=None, mod=None, title=None, lines=(), glue_sigs=()):
    """an instance box (parent, inst, mod) or, with inst=None, logic written inside `parent`"""
    if inst:
        if (inst, mod) not in INST.get(parent, set()):
            errors.append(f"{parent}.v has no instance {inst} : {mod}")
        fill, click = COL.get(owner(mod), "#ffffff"), mod
        head = f"{inst} : {mod}"
    else:
        for s in glue_sigs:
            width(parent, s)
        fill, click = COL["glue"], parent
        head = title
    BOX[key] = (x, y, w, h)
    OUT.append(f'<g class="ob" data-mod="{click}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" '
               f'fill="{fill}" stroke="#2b3440" stroke-width="1.2"{" stroke-dasharray=\"4 3\"" if not inst else ""}/>')
    sub = list(lines) + ([f"logic in {parent}.v"] if not inst else [])
    if inst and len(head) * 6.4 > w - 10:          # narrow box: module name on the next line
        head, sub = inst, [": " + mod] + sub
    OUT.append(f'<text x="{x + 6}" y="{y + 14}" class="oh">{esc(head)}</text>')
    yy = y + 27
    for ln in sub:
        if yy > y + h - 3:
            break
        OUT.append(f'<text x="{x + 6}" y="{yy}" class="ol">{esc(ln)}</text>')
        yy += 11.5
    OUT.append("</g>")


def frame(x, y, w, h, title, color, dash=False):
    OUT.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{color}" fill-opacity="0.35" '
               f'stroke="#55606e" stroke-width="1.4"{" stroke-dasharray=\"6 4\"" if dash else ""}/>')
    OUT.append(f'<text x="{x + 10}" y="{y + 17}" class="of">{esc(title)}</text>')


def side(key, s, t=0.5):
    x, y, w, h = BOX[key]
    return {"l": (x, y + h * t), "r": (x + w, y + h * t), "t": (x + w * t, y), "b": (x + w * t, y + h)}[s]


def wire(a, b, mod, nets, ctl=None, lab_at=0.5, label=None, mid=None, via=None, seg=None):
    """a, b: (x, y) points or (box, side, t). nets checked in `mod`."""
    pa = side(*a) if isinstance(a[0], str) else a
    pb = side(*b) if isinstance(b[0], str) else b
    ws = [width(mod, n) for n in nets]
    one_bit = all(w == 1 for w in ws)
    ctl = one_bit if ctl is None else ctl
    if label is None:
        parts = []
        for n, w in zip(nets, ws):
            parts.append(n + (f"[{w - 1}:0]" if w and w > 1 else ""))
        label = ", ".join(parts)
    # orthogonal route: horizontal first if the start is on a left/right side
    horiz = isinstance(a[0], str) and a[1] in "lr" or (not isinstance(a[0], str) and abs(pb[0] - pa[0]) > abs(pb[1] - pa[1]))
    if via:
        pts = [pa] + list(via) + [pb]
    elif horiz:
        mx = mid if mid is not None else (pa[0] + pb[0]) / 2
        pts = [pa, (mx, pa[1]), (mx, pb[1]), pb]
    else:
        my = mid if mid is not None else (pa[1] + pb[1]) / 2
        pts = [pa, (pa[0], my), (pb[0], my), pb]
    d = "M" + " L".join(f"{p[0]:.1f},{p[1]:.1f}" for p in pts)
    cls = "ow c" if ctl else "ow"
    OUT.append(f'<path d="{d}" class="{cls}" marker-end="url(#oa{"c" if ctl else ""})"><title>{esc(label)} ({mod}.v)</title></path>')
    # label on the longest segment
    segs = [(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    s0, s1 = segs[seg] if seg is not None else max(segs, key=lambda s: abs(s[0][0] - s[1][0]) + abs(s[0][1] - s[1][1]))
    lx, ly = s0[0] + (s1[0] - s0[0]) * lab_at, s0[1] + (s1[1] - s0[1]) * lab_at
    if abs(s0[0] - s1[0]) >= abs(s0[1] - s1[1]):
        OUT.append(f'<text x="{lx:.1f}" y="{ly - 3:.1f}" text-anchor="middle" class="{"olc" if ctl else "old"}">{esc(label)}</text>')
    else:
        OUT.append(f'<text x="{lx + 3:.1f}" y="{ly:.1f}" class="{"olc" if ctl else "old"}">{esc(label)}</text>')


def text(x, y, s, cls="ol", anchor="start"):
    OUT.append(f'<text x="{x}" y="{y}" class="{cls}" text-anchor="{anchor}">{esc(s)}</text>')


def mux(key, x, y, w, h, parent, out, sel, inputs, title="MUX"):
    """a multiplexer written inside `parent` (trapezoid). out, sel and every input must exist there."""
    for s_ in [out, sel] + list(inputs):
        width(parent, s_)
    BOX[key] = (x, y, w, h)
    OUT.append(f'<g class="ob" data-mod="{parent}"><polygon points="{x},{y} {x + w},{y + h * 0.18} {x + w},{y + h * 0.82} {x},{y + h}" '
               f'fill="#fff7d6" stroke="#2b3440" stroke-width="1.2"/>')
    OUT.append(f'<text x="{x + w / 2}" y="{y + h / 2 + 4}" text-anchor="middle" class="oh">{esc(title)}</text></g>')


def build():
    OUT.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="#ffffff"/>')
    OUT.append(f'<rect x="10" y="8" width="{W - 20}" height="50" rx="6" fill="#e8eef7" stroke="#55606e"/>')
    text(W / 2, 30, "ShieldV: RV32IM processor with a hardware shadow stack (Nexys A7-100T) · top-level block diagram", "ot", "middle")
    text(W / 2, 49, "Every box is a real instance (or logic written inside a module, dashed) and every signal name and width is checked "
         "against the Verilog by scripts/overview.py", "ol", "middle")

    # ======================= G1: the 3-stage in-order core (default build) =======================
    P = "core_pipe"
    frame(10, 66, 1390, 690, "G1 · core_pipe.v · 3-stage in-order RV32IM pipeline (Avani: datapath · Laxmidhar: pipeline control)", "#dbe6fb")
    text(150, 98, "STAGE 1 · IF / ID", "os")
    text(780, 98, "STAGE 2 · EX", "os")
    text(1230, 98, "STAGE 3 · MEM / WB", "os")

    box("pc", 30, 130, 150, 76, P, "u_pc", "pc_reg", lines=["next-PC + PC logic", "hold > trap > redirect > pc+4", "pc register"])
    box("imem", 30, 260, 150, 66, P, "u_imem", "imem", lines=["instruction memory", "16 KB BRAM, sync read"])
    box("dec", 215, 330, 170, 92, P, "u_dec", "decoder", lines=["decode + control unit", "alu_op, a_pc, b_imm, reg_write,", "wb_sel, load, store, branch,", "jal, jalr, mop, illegal"])
    box("imm", 215, 432, 170, 40, P, "u_imm", "imm_gen", lines=["I / S / B / U / J immediates"])
    box("rf", 405, 150, 150, 120, P, "u_rf", "regfile", lines=["register file", "32 x 32", "2 read ports (async)", "1 write port", "write-through, x0 = 0"])
    box("fwd", 215, 560, 170, 48, P, "u_fwd", "forward_unit", lines=["MEM/WB -> EX forwarding"])
    box("hz", 215, 620, 170, 46, P, "u_hz", "hazard_unit", lines=["stall: M-unit wait, ShieldV freeze"])
    box("fl", 215, 678, 170, 46, P, "u_fl", "flush_unit", lines=["flush after taken branch / trap"])
    box("p1", 585, 120, 46, 610, P, "u_p1", "pipe_ifid_ex", lines=["", "IF/ID", "-> EX", "pipeline", "register", "", "valid,", "pc,", "instr,", "rs1, rs2,", "imm,", "ctrl"])

    mux("mfa", 660, 160, 30, 70, P, "e_rs1_val", "fwd_a", ["w_value", "e_rs1_raw"], "F")
    mux("mfb", 660, 270, 30, 70, P, "e_rs2_val", "fwd_b", ["w_value", "e_rs2_raw"], "F")
    mux("maa", 730, 160, 30, 70, P, "alu_a", "e_a_pc", ["e_pc", "e_rs1_val"], "A")
    mux("mab", 730, 270, 30, 70, P, "alu_b", "e_b_imm", ["e_imm", "e_rs2_val"], "B")
    box("alu", 800, 180, 110, 140, P, "u_alu", "alu", lines=["ALU (RV32I)", "add sub sll slt", "sltu xor srl sra", "or and pass-b", "", "op = e_alu_op[3:0]"])
    box("br", 800, 380, 150, 84, P, "u_br", "branch_unit", lines=["branch and jump unit", "beq..bgeu compare", "target = pc+imm or rs1+imm", "link = pc + 4"])
    box("redir", 980, 380, 150, 64, P, None, title="redirect logic", lines=["ex_commit = e_valid & ~stall", "ex_redirect = ex_commit", "  & br_taken & ~sh_trap"],
        glue_sigs=["ex_commit", "ex_redirect", "br_taken"])
    box("mh", 800, 500, 150, 70, P, None, title="M-unit handshake", lines=["m_start pulse, m_pending reg", "m_wait = e_valid & mop", "  & ~m_done -> stall"],
        glue_sigs=["m_start", "m_pending", "m_wait"])
    box("lsu", 980, 500, 160, 82, P, "u_lsu", "lsu", lines=["load/store unit", "EX: byte enables, store data", "MEM/WB: load align,", "sign / zero extend"])
    box("p2", 1160, 120, 46, 610, P, "u_p2", "pipe_ex_wb", lines=["", "EX ->", "MEM/WB", "pipeline", "register", "", "valid,", "pc, rd,", "alu_y,", "m_result,", "wb_sel"])
    mux("mwb", 1260, 220, 40, 150, P, "w_value", "w_wb_sel", ["w_alu_y", "w_load_data", "w_m_result", "w_pc"], "WB")
    box("tr", 1240, 640, 140, 64, P, "u_tr", "trace_port", lines=["IF-4 trace (registered):", "pcs, stall, flush, retire,", "branch, mispredict"])

    # IF / ID
    wire(("pc", "b", 0.5), ("imem", "t", 0.5), P, ["f_pc_next"])
    wire(("imem", "r", 0.4), ("dec", "l", 0.3), P, ["f_instr"], via=[(197, 286), (197, 358)], seg=1)
    wire(("dec", "t", 0.3), ("rf", "l", 0.6), P, ["d_rs1", "d_rs2"], via=[(266, 222)], seg=1)
    wire(("dec", "r", 0.5), ("p1", "l", 0.42), P, ["d_ctrl"], label="d_ctrl[14:0] (control word)")
    wire(("imm", "r", 0.5), ("p1", "l", 0.58), P, ["d_imm"])
    wire(("rf", "r", 0.35), ("p1", "l", 0.08), P, ["d_rs1_val", "d_rs2_val"], label="d_rs1_val, d_rs2_val [31:0]", via=[(570, 192), (570, 168)], seg=0)
    wire(("pc", "r", 0.25), ("p1", "l", 0.02), P, ["f_pc"], via=[(300, 149), (300, 132)], seg=0)
    # EX
    wire(("p1", "r", 0.10), ("mfa", "l", 0.7), P, ["e_rs1_raw"], label="e_rs1_raw")
    wire(("p1", "r", 0.28), ("mfb", "l", 0.7), P, ["e_rs2_raw"], label="e_rs2_raw")
    wire(("mfa", "r", 0.5), ("maa", "l", 0.7), P, ["e_rs1_val"], label="")
    wire(("mfb", "r", 0.5), ("mab", "l", 0.7), P, ["e_rs2_val"], label="")
    wire(("p1", "r", 0.05), ("maa", "l", 0.25), P, ["e_pc"], via=[(645, 150.5), (715, 150.5), (715, 177.5)], seg=1)
    wire(("p1", "r", 0.40), ("mab", "l", 0.3), P, ["e_imm"], via=[(712, 364), (712, 291)], seg=0)
    wire(("maa", "r", 0.5), ("alu", "l", 0.25), P, ["alu_a"])
    wire(("mab", "r", 0.5), ("alu", "l", 0.75), P, ["alu_b"])
    wire(("alu", "r", 0.4), ("p2", "l", 0.18), P, ["alu_y"])
    wire(("mfb", "b", 0.5), ("br", "l", 0.4), P, ["e_rs1_val", "e_rs2_val"], label="e_rs1_val, e_rs2_val", via=[(675, 414)], seg=1)
    wire(("br", "r", 0.3), ("redir", "l", 0.3), P, ["br_taken"])
    wire(("br", "b", 0.8), ("pc", "b", 0.8), P, ["br_target"], via=[(920, 486), (150, 486)], seg=1, lab_at=0.3)
    wire(("redir", "b", 0.5), ("pc", "l", 0.85), P, ["ex_redirect"], via=[(1055, 740), (20, 740), (20, 194.6)], seg=1, lab_at=0.75)
    wire(("redir", "b", 0.2), ("fl", "r", 0.5), P, ["ex_redirect"], via=[(1010, 470), (960, 470), (960, 701)], seg=2, label="")
    wire(("mh", "l", 0.6), ("hz", "r", 0.4), P, ["m_wait"], via=[(560, 542), (560, 638)], seg=0)
    wire(("hz", "l", 0.5), ("pc", "l", 0.5), P, ["stall"], via=[(200, 643), (200, 600), (12, 600), (12, 168)], seg=2, lab_at=0.3)
    wire(("hz", "r", 0.8), ("p1", "b", 0.5), P, ["stall"], via=[(608, 657)], seg=0, label="stall (hold)")
    wire(("fl", "r", 0.3), ("p1", "l", 0.98), P, ["flush_ifid"], via=[(500, 692), (500, 718)], seg=0)
    wire(("p2", "r", 0.9), ("fwd", "b", 0.5), P, ["w_rd", "w_reg_write", "w_valid"], via=[(1230, 669), (1230, 748), (300, 748)], seg=2, lab_at=0.7)
    wire(("fwd", "t", 0.8), ("mfa", "b", 0.5), P, ["fwd_a", "fwd_b"], via=[(351, 545), (675, 545)], seg=1, lab_at=0.3)
    wire(("p1", "r", 0.30 + 0.24), ("lsu", "l", 0.5), P, ["e_rs2_val"], label="st_data = e_rs2_val", via=[(645, 449), (645, 590), (965, 590), (965, 541)], seg=2)
    wire(("p2", "r", 0.17), ("mwb", "l", 0.12), P, ["w_alu_y"])
    wire(("p2", "r", 0.30), ("mwb", "l", 0.37), P, ["w_m_result"])
    wire(("lsu", "t", 0.9), ("mwb", "l", 0.62), P, ["w_load_data"], via=[(1124, 470), (1235, 470), (1235, 313)], seg=1)
    wire(("p2", "r", 0.42), ("mwb", "l", 0.88), P, ["w_pc"], label="w_pc (+4 = link)")
    wire(("p2", "t", 0.5), ("mwb", "t", 0.5), P, ["w_wb_sel"], via=[(1183, 108), (1280, 108)], seg=1)
    wire(("mwb", "r", 0.5), ("rf", "t", 0.5), P, ["w_value"], label="w_value[31:0] -> register file write (we = w_valid & w_reg_write, wa = w_rd)",
         via=[(1330, 295), (1330, 112), (480, 112)], seg=1)
    wire((1330, 160), ("mfa", "t", 0.3), P, ["w_value"], via=[(1330, 140), (669, 140)], seg=1, label="w_value (forwarded to EX)", lab_at=0.75)

    # ======================= G3: ShieldV =======================
    S3 = "shieldv"
    frame(1420, 66, 570, 690, "G3 · ShieldV security unit · soc_top.g_shield.u_sh : shieldv.v (Priyank)", "#fbe0e4")
    box("det", 1440, 140, 170, 74, S3, "u_det", "callret_detect", lines=["call / return detector", "call: jal/jalr rd = x1/x5", "return: jalr rs1 = x1/x5", "indirect: needs lpad"])
    box("lp", 1640, 140, 160, 74, S3, "u_lp", "lpad_check", lines=["landing-pad check", "next instruction must", "be lpad (auipc x0)"])
    box("rd", 1820, 140, 160, 90, S3, None, title="register read mux", lines=["0x30 CTRL  0x34 STAT", "0x38 FAULT_PC", "0x3C EXPECTED 0x40 ACTUAL", "0x44 HANDLER"], glue_sigs=["reg_rdata", "reg_addr"])
    box("cc", 1440, 250, 170, 64, S3, "u_cc", "commit_ctrl", lines=["shadow stack controller", "push / pop only when ex_valid", "and not freeze / trap"])
    box("viol", 1640, 250, 160, 64, S3, None, title="violation", lines=["ex_valid & (mismatch |", "underflow | overflow |", "lpad_fail)"], glue_sigs=["violation"])
    box("ss", 1440, 350, 170, 92, S3, "u_ss", "shadow_stack", lines=["shadow stack RAM", "32 x 32 LUTRAM", "pointer sp, full, empty", "no path from the data bus"])
    box("cmp", 1640, 350, 160, 74, S3, "u_cmp", "ret_compare", lines=["return comparator", "actual != expected", "underflow / overflow"])
    box("cause", 1820, 350, 160, 64, S3, None, title="cause select", lines=["cause, expected, actual", "for the fault registers"], glue_sigs=["cause_now", "expected_now", "actual_now"])
    box("ctrl", 1440, 480, 170, 100, S3, "u_ctrl", "shield_ctrl", lines=["enable / mode register", "bit0 enable  bit1 trap", "bit2 count-only  bit3 lpad", "bit4 LOCK: writes ignored", "until reset; HANDLER reg"])
    box("fsm", 1640, 480, 160, 80, S3, "u_fsm", "violation_fsm", lines=["violation FSM", "NORMAL -> ALARM", "freeze or trap in the", "same cycle"])
    box("fault", 1820, 480, 160, 90, S3, "u_fault", "fault_regs", lines=["fault registers", "FAULT_PC, EXPECTED,", "ACTUAL, cause,", "violation count"])
    wire(("det", "b", 0.4), ("cc", "t", 0.4), S3, ["is_call", "is_ret"])
    wire(("det", "r", 0.5), ("lp", "l", 0.5), S3, ["needs_lpad"])
    wire(("cc", "b", 0.4), ("ss", "t", 0.4), S3, ["do_push", "do_pop"])
    wire(("ss", "r", 0.4), ("cmp", "l", 0.4), S3, ["top", "empty", "full"], label="top[31:0], empty, full")
    wire(("cmp", "t", 0.5), ("viol", "b", 0.5), S3, ["mismatch", "underflow", "overflow"], lab_at=0.5)
    wire(("lp", "b", 0.5), ("viol", "t", 0.5), S3, ["lpad_fail"])
    wire(("viol", "r", 0.5), ("fsm", "t", 0.8), S3, ["violation"], via=[(1810, 282), (1810, 470), (1768, 470)], seg=0)
    wire(("ctrl", "r", 0.3), ("fsm", "l", 0.3), S3, ["enabled", "trap_mode", "count_only"], label="enabled, trap_mode, count_only")
    wire(("fsm", "r", 0.3), ("fault", "l", 0.3), S3, ["capture"])
    wire(("cause", "b", 0.5), ("fault", "t", 0.5), S3, ["cause_now", "expected_now", "actual_now"], label="cause, expected, actual")
    wire(("fault", "r", 0.2), ("rd", "r", 0.8), S3, ["f_expected", "f_actual", "f_cause"], label="", via=[(1986, 498), (1986, 212)], seg=1)

    # IF-3 and back (soc_top nets)
    S = "soc_top"
    wire((1400, 162.2), ("det", "l", 0.3), S, ["ex_valid", "ex_instr", "ex_pc", "ex_target", "ex_link"], label="")
    text(1440, 100, "IF-3 core -> ShieldV (from EX): ex_valid, ex_instr[31:0], ex_pc[31:0],", "old")
    text(1440, 113, "ex_target[31:0] (= br_target), ex_link[31:0] (= pc + 4)", "old")
    wire(("fsm", "b", 0.5), (1400, 700), S, ["sh_freeze", "sh_trap", "sh_handler_pc"], via=[(1720, 700)], seg=1,
         label="IF-3 ShieldV -> core: sh_freeze (to hazard_unit), sh_trap + sh_handler_pc[31:0] (to pc_reg, flush_unit)")

    # ======================= G2: M-unit, SoC, I/O =======================
    frame(10, 772, 1980, 260, "G2 · soc_top.v · M-unit (Nishant) · bus decoder, memory and memory-mapped I/O (Nilesh)", "#fbefd9")
    box("m", 800, 840, 190, 84, S, "u_m", "munit", lines=["multiplier / divider", "u_mul : multiplier (2 cycles)", "u_div : divider (34 cycles)", "start / busy / done (IF-1)"])
    box("bus", 30, 840, 200, 90, S, "u_bus", "bus_decoder", lines=["bus and address decoder", "0x0001_xxxx -> data memory", "0x1000_00xx -> I/O registers", "read data next cycle"])
    box("dmem", 290, 840, 160, 70, S, "u_dmem", "dmem", lines=["data memory (DMEM)", "16 KB BRAM, byte enables"])
    box("led", 1040, 860, 120, 56, S, "u_led", "led_reg", lines=["LED register", "0x1000_0000"])
    box("segv", 1180, 860, 120, 64, S, None, title="7-seg value", lines=["seg_value reg 0x...04", "shows fault_pc", "during an alarm"], glue_sigs=["seg_value", "alarm", "fault_pc"])
    box("seg", 1320, 860, 120, 56, S, "u_seg", "seg7_driver", lines=["7-segment driver", "8 digits"])
    box("uart", 1460, 860, 120, 56, S, "u_uart", "uart_tx", lines=["UART TX", "0x1000_0010"])
    box("sw", 1600, 860, 120, 56, S, "u_sw", "switch_sync", lines=["switch synchroniser", "SW0 = protection"])
    box("perf", 1740, 860, 150, 70, S, "u_perf", "perf_counters", lines=["performance counters", "cycles, instret, calls,", "rets, branches, violations"])
    box("iord", 500, 840, 150, 60, S, None, title="I/O read mux", lines=["io_rdata by io_addr", "(LED, SW, UART, counters,", "ShieldV registers)"], glue_sigs=["io_rdata", "io_addr"])
    box("ooo", 30, 960, 700, 64, S, "u_core", "core_ooo", lines=["build option `define SHIELDV_OOO: replaces core_pipe with the out-of-order core", "(rename table, 16-entry ROB, reservation stations, LSQ, CDB, tournament predictor, BTB, RAS)", "same IF-1 / IF-2 / IF-3 ports; ShieldV checks at the reorder-buffer head"])
    wire(("mh", "b", 0.4), ("m", "t", 0.32), S, ["m_start", "m_op", "m_a", "m_b"], label="IF-1: m_start, m_op[2:0], m_a, m_b [31:0]", lab_at=0.82)
    wire(("m", "t", 0.8), ("mh", "b", 0.8), S, ["m_busy", "m_done", "m_result"], label="m_busy, m_done, m_result[31:0]", lab_at=0.9)
    wire(("lsu", "b", 0.2), ("bus", "t", 0.3), S, ["bus_addr", "bus_wdata", "bus_wstrb", "bus_we", "bus_re"], via=[(1012, 760), (90, 760)], seg=1,
         label="IF-2: bus_addr (= alu_y), bus_wdata, bus_wstrb[3:0], bus_we, bus_re", lab_at=0.35)
    wire(("bus", "t", 0.8), ("lsu", "b", 0.7), S, ["bus_rdata"], via=[(190, 767), (1092, 767)], seg=1, label="bus_rdata[31:0] -> lsu (load side)", lab_at=0.86)
    wire(("bus", "r", 0.3), ("dmem", "l", 0.3), S, ["dmem_en", "dmem_wstrb"])
    wire(("dmem", "b", 0.5), ("bus", "b", 0.6), S, ["dmem_rdata"], via=[(370, 938), (150, 938)], seg=1)
    wire(("bus", "b", 0.2), ("perf", "b", 0.5), S, ["io_we", "io_addr", "io_wdata"], via=[(70, 950), (1815, 950)], seg=1, lab_at=0.55,
         label="io_we, io_addr[7:0], io_wdata[31:0] -> LED, 7-seg, UART, counters and the ShieldV registers (reg_we / reg_addr / reg_wdata)")
    for k in ("led", "segv", "uart"):
        x0 = BOX[k][0] + BOX[k][2] / 2
        OUT.append(f'<path d="M{x0},950 L{x0},{BOX[k][1] + BOX[k][3]}" class="ow" marker-end="url(#oa)"/>')
    wire(("iord", "l", 0.5), ("bus", "r", 0.8), S, ["io_rdata"])
    wire(("fault", "b", 0.5), ("segv", "t", 0.5), S, ["alarm", "fault_pc"], via=[(1900, 790), (1240, 790)], seg=1, lab_at=0.6)
    wire(("segv", "r", 0.4), ("seg", "l", 0.4), S, ["seg_value"], label="")
    wire(("sw", "t", 0.5), ("ctrl", "l", 0.85), S, ["sw"], label="sw[0] -> sw_enable", ctl=True, via=[(1660, 780), (1428, 780), (1428, 565)], seg=2)
    wire(("rd", "r", 0.5), ("iord", "t", 0.5), S, ["shield_rdata"], via=[(1994, 185), (1994, 812), (575, 812)], seg=2, lab_at=0.15)
    wire(("tr", "b", 0.4), ("perf", "t", 0.3), S, ["tr_retire", "tr_branch", "tr_mispredict"], via=[(1296, 840), (1785, 840)], seg=1, label="IF-4: tr_retire, tr_branch, tr_mispredict")

    # board pins
    F = "fpga_top"
    OUT.append(f'<rect x="10" y="1042" width="{W - 20}" height="40" rx="6" fill="#efe8fb" stroke="#55606e"/>')
    text(20, 1066, "Nexys A7-100T pins (fpga_top.v)", "of")
    for x, nets, lab in ((1100, ["LED"], "LED[15:0]"), (1380, ["AN", "DP"], "CA..CG, DP, AN[7:0]"), (1520, ["UART_RXD_OUT"], "UART_RXD_OUT"),
                         (1660, ["SW"], "SW[15:0]"), (600, ["CLK100MHZ", "CPU_RESETN"], "CLK100MHZ, CPU_RESETN -> u_clk : clk_rst (50 MHz)")):
        for n in nets:
            width(F, n)
        text(x, 1067, lab, "op", "middle")
    wire(("led", "b"), (1100, 1052), S, ["led"])
    wire(("seg", "b"), (1380, 1052), S, ["seg", "an"])
    wire(("uart", "b"), (1520, 1052), S, ["uart_txd"])
    wire((1660, 1052), ("sw", "b"), S, ["sw_raw"])

    # legend
    OUT.append(f'<rect x="10" y="1092" width="{W - 20}" height="58" rx="6" fill="#ffffff" stroke="#55606e"/>')
    leg = [("#dbe6fb", "G1 Avani · datapath"), ("#d4efe9", "G1 Laxmidhar · pipeline control"), ("#fbefd9", "G2 Nishant · M-unit"),
           ("#fde3cf", "G2 Nilesh · SoC / I/O"), ("#fbe0e4", "G3 Priyank · ShieldV"), ("#f4f4f4", "logic inside a module (dashed)"),
           ("#fff7d6", "multiplexer")]
    for i, (c, s_) in enumerate(leg):
        OUT.append(f'<rect x="{24 + i * 230}" y="1104" width="16" height="12" fill="{c}" stroke="#2b3440"/>')
        text(46 + i * 230, 1114, s_, "ol")
    OUT.append('<path d="M24,1136 L84,1136" class="ow" marker-end="url(#oa)"/>')
    text(90, 1140, "data (name + width)", "ol")
    OUT.append('<path d="M260,1136 L320,1136" class="ow c" marker-end="url(#oac)"/>')
    text(326, 1140, "1-bit control", "ol")
    text(480, 1140, "clk and rst_n go to every block (not drawn). Memory map and interfaces: docs/interfaces.md.", "ol")


STYLE = """<style>
.ot{font:700 19px Helvetica,Arial,sans-serif;fill:#14202e}
.of{font:700 12.5px Helvetica,Arial,sans-serif;fill:#14202e}
.oh{font:700 11.5px Helvetica,Arial,sans-serif;fill:#14202e}
.ol{font:10px Helvetica,Arial,sans-serif;fill:#333}
.os{font:italic 10.5px Helvetica,Arial,sans-serif;fill:#555}
.om{font:10.5px Consolas,monospace;fill:#222}
.op{font:700 10.5px Helvetica,Arial,sans-serif;fill:#4a2a7a}
.ow{fill:none;stroke:#1f4e9e;stroke-width:1.3}
.ow.c{stroke:#c62828;stroke-dasharray:5 3}
.old{font:9px Helvetica,Arial,sans-serif;fill:#1f4e9e;stroke:#fff;stroke-width:3px;paint-order:stroke}
.olc{font:9px Helvetica,Arial,sans-serif;fill:#c62828;stroke:#fff;stroke-width:3px;paint-order:stroke}

</style>"""


def make():
    OUT.clear()
    errors.clear()
    build()
    if errors:
        raise SystemExit("overview.py: the diagram names things that are not in the RTL:\n  " + "\n  ".join(errors))
    defs = ('<defs><marker id="oa" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto">'
            '<path d="M0,0 L10,5 L0,10 z" fill="#1f4e9e"/></marker>'
            '<marker id="oac" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto">'
            '<path d="M0,0 L10,5 L0,10 z" fill="#c62828"/></marker></defs>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
           f'font-family="Helvetica, Arial, sans-serif">{STYLE}{defs}' + "\n".join(OUT) + "</svg>")
    path = os.path.join(sim.ROOT, "diagrams", "top_block_diagram.svg")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(svg)
    print(f"  wrote diagrams/top_block_diagram.svg ({len(BOX)} blocks, all names checked against the RTL)")
    return svg


if __name__ == "__main__":
    make()
