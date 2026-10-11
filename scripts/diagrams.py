#!/usr/bin/env python3
"""diagrams.py - the project's two diagrams (Nilesh, G2; drawn from everyone's RTL).

    python scripts/diagrams.py            # both
    python scripts/diagrams.py block      # diagrams/top_block_diagram.svg + .png
    python scripts/diagrams.py timing     # diagrams/timing_diagram.svg + .png

1. Top-level block diagram (scripts/overview.py). The layout is chosen by hand,
   but every box must be a real instance and every wire a real net of the
   Verilog; widths are computed from the declarations. Anything that is not in
   the RTL stops the script with an error instead of being drawn.
2. Timing diagram of the whole project in 12 clock cycles. The assembly program
   timing_final.S is run on the simulated SoC (in-order core, ShieldV on) and the
   12 cycles starting at its first store to SHIELD_CTRL are cut from the waveform
   (VCD) with scripts/vcd2wave.py. They show: the lock store, the attacker's store
   to the locked SHIELD_CTRL being ignored, a call (push), a MUL stall, the return
   (pop), the stack overwrite, and the bad return trapped to the handler.

The .png copies are made with Microsoft Edge in headless mode (if installed),
for slides and the report.

This file also holds the small Verilog reader that overview.py uses.
"""
import glob
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim  # noqa: E402

OUT = os.path.join(sim.ROOT, "diagrams")

# which member owns which module (for the colours)
OWNER = {}
for f in glob.glob(os.path.join(sim.ROOT, "G*", "*", "rtl", "*.v")):
    parts = os.path.relpath(f, sim.ROOT).split(os.sep)
    OWNER[os.path.basename(f)[:-2]] = (parts[0], parts[1], os.path.relpath(f, sim.ROOT).replace(os.sep, "/"))


# ============================================================ reading the Verilog
def strip_comments(t):
    t = re.sub(r"/\*.*?\*/", " ", t, flags=re.S)
    return re.sub(r"//[^\n]*", "", t)


def apply_ifdef(t, defines):
    """keep the `ifdef / `else branch that matches the defines"""
    out, stack = [], []
    for line in t.split("\n"):
        s = line.strip()
        m = re.match(r"`(ifdef|ifndef)\s+(\w+)", s)
        if m:
            on = (m.group(2) in defines) == (m.group(1) == "ifdef")
            stack.append(on)
            continue
        if s.startswith("`else"):
            stack[-1] = not stack[-1]
            continue
        if s.startswith("`endif"):
            stack.pop()
            continue
        if all(stack):
            out.append(line)
    return "\n".join(out)


def match_paren(t, i, op="(", cl=")"):
    """t[i] == op; return index of the matching close"""
    d = 0
    for j in range(i, len(t)):
        if t[j] == op:
            d += 1
        elif t[j] == cl:
            d -= 1
            if d == 0:
                return j
    raise ValueError("unbalanced")


def split_top(s, sep=","):
    parts, d, cur = [], 0, ""
    for ch in s:
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
        if ch == sep and d == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return [p.strip() for p in parts]


def safe_eval(expr, params):
    e = expr
    for k in sorted(params, key=len, reverse=True):
        e = re.sub(r"\b%s\b" % k, "(%s)" % params[k], e)
    e = re.sub(r"\d+'[dD](\d+)", r"\1", e)
    if not re.fullmatch(r"[\d\s+\-*/()<>]*", e):
        return None
    try:
        return int(eval(e.replace("/", "//")))
    except Exception:
        return None


def range_width(rng, params):
    """'[31:0]' -> 32 (None if it cannot be worked out)"""
    if not rng:
        return 1
    m = re.match(r"\[(.+):(.+)\]", rng.replace(" ", ""))
    if not m:
        return None
    hi, lo = safe_eval(m.group(1), params), safe_eval(m.group(2), params)
    return None if hi is None or lo is None else abs(hi - lo) + 1


class Module:
    def __init__(self, name, text, file):
        self.name, self.file = name, file
        self.params = {}            # name -> default value (string)
        self.ports = []             # (dir, name, range)
        self.decl = {}              # signal -> range string ('' = 1 bit)
        self.body = ""
        self.parse(text)

    def parse(self, t):
        m = re.search(r"\bmodule\s+%s\b" % self.name, t)
        i = m.end()
        rest = t[i:]
        # parameters  #( ... )
        pm = re.match(r"\s*#\s*\(", rest)
        if pm:
            j = rest.index("(", pm.start())
            k = match_paren(rest, j)
            for p in split_top(rest[j + 1:k]):
                mm = re.match(r"parameter\s+(?:\[[^\]]*\]\s*)?(\w+)\s*=\s*(.+)", p)
                if mm:
                    self.params[mm.group(1)] = mm.group(2).strip()
            rest = rest[k + 1:]
        j = rest.index("(")
        k = match_paren(rest, j)
        cur_dir, cur_rng = None, ""
        for p in split_top(rest[j + 1:k]):
            mm = re.match(r"(input|output|inout)\s+(?:wire|reg)?\s*(?:signed\s*)?(\[[^\]]*\])?\s*(\w+)$", p)
            if mm:
                cur_dir, cur_rng = mm.group(1), mm.group(2) or ""
                name = mm.group(3)
            else:
                name = p.strip()
            self.ports.append((cur_dir, name, cur_rng))
            self.decl[name] = cur_rng
        self.body = rest[k + 1:rest.index("endmodule")]
        for mm in re.finditer(r"\blocalparam\s+(?:integer\s+)?(?:\[[^\]]*\]\s*)?(\w+)\s*=\s*([^;,]+)", self.body):
            self.params.setdefault(mm.group(1), mm.group(2).strip())
        for mm in re.finditer(r"\b(?:wire|reg|integer)\s+(?:signed\s*)?(\[[^\]]*\])?\s*([^;=]+?)\s*(?:=|;)", self.body):
            for nm in mm.group(2).split(","):
                nm = nm.strip().split("[")[0].strip()
                if re.fullmatch(r"\w+", nm):
                    self.decl.setdefault(nm, mm.group(1) or "")


def load_modules(defines=()):
    mods = {}
    for f in sorted(glob.glob(os.path.join(sim.ROOT, "G*", "*", "rtl", "*.v"))):
        t = apply_ifdef(strip_comments(open(f, encoding="utf-8").read()), set(defines))
        for m in re.finditer(r"\bmodule\s+(\w+)", t):
            mods[m.group(1)] = Module(m.group(1), t, f)
    return mods


def resolve_generate(body, params):
    """keep the active branch of `generate if (P) begin ... end else begin ... end`;
    generate-for loops are kept as a note"""
    notes = []
    while True:
        g = re.search(r"\bgenerate\b", body)
        if not g:
            break
        e = body.index("endgenerate", g.end())
        inner = body[g.end():e]
        mm = re.match(r"\s*if\s*\(", inner)
        keep = ""
        if mm:
            j = inner.index("(")
            k = match_paren(inner, j)
            cond = safe_eval(inner[j + 1:k], params)
            blocks = [b for b in re.split(r"\belse\b", inner[k + 1:])]
            def strip_be(s):
                s = s.strip()
                s = re.sub(r"^begin\s*(:\s*\w+)?", "", s)
                s = re.sub(r"end\s*$", "", s.strip())
                return s
            keep = strip_be(blocks[0]) if cond else (strip_be(blocks[1]) if len(blocks) > 1 else "")
        else:
            # generate-for: keep its statements once, drawn for a symbolic index, with a note
            fm = re.search(r"\bfor\s*\(([^;]*);([^;]*);[^)]*\)\s*begin\s*(:\s*\w+)?(.*)\bend\b", inner, re.S)
            if fm:
                keep = fm.group(4)
                notes.append("generate loop (" + " ".join(fm.group(2).split()) + "): one copy of this logic per index")
            else:
                notes.append("generate loop: " + " ".join(inner.split())[:160])
        body = body[:g.start()] + keep + body[e + len("endgenerate"):]
    return body, notes


def esc(s):
    return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;"))


def list_instances(mod, mods):
    """[(module type, instance name)] of every instance inside `mod` (active generate
    branches only); FPGA primitives such as BUFG are skipped"""
    body, _ = resolve_generate(mod.body, dict(mod.params))
    out = []
    for m in re.finditer(r"\b(\w+)\s*(#\s*\()?", body):
        name = m.group(1)
        if name not in mods or name == mod.name:
            continue
        j = m.end()
        if m.group(2):
            j = match_paren(body, j - 1) + 1
        im = re.match(r"\s*(\w+)\s*\(", body[j:])
        if im:
            out.append((name, im.group(1)))
    return out


# ============================================================ the two diagrams
EDGE = [r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"]


def to_png(svg_path, w, h):
    """PNG copy at 2x resolution, if Microsoft Edge is installed"""
    edge = next((e for e in EDGE if os.path.isfile(e)), shutil.which("msedge"))
    if not edge:
        print("  (no PNG: Microsoft Edge not found)")
        return
    png = svg_path[:-4] + ".png"
    subprocess.run([edge, "--headless=new", "--disable-gpu", "--force-device-scale-factor=2",
                    f"--screenshot={png}", f"--window-size={w},{h}", "file:///" + svg_path.replace(os.sep, "/")],
                   capture_output=True)
    print("  wrote", os.path.relpath(png, sim.ROOT))


def block():
    import overview
    overview.make()
    to_png(os.path.join(OUT, "top_block_diagram.svg"), overview.W, overview.H)


# signals in the timing diagram, top to bottom:  label | path in soc_tb | format
TIMING_SIGNALS = """\
IF/ID pc       | soc_tb.dut.u_core.f_pc                          | hex
EX instr       | soc_tb.dut.u_core.e_pc                          | instr:soc_tb.dut.u_core.e_valid
EX pc          | soc_tb.dut.u_core.e_pc                          | hex
stall          | soc_tb.dut.u_core.stall                         | bit
flush          | soc_tb.dut.u_core.flush_ifid                    | bit
m_busy         | soc_tb.dut.u_core.m_busy                        | bit
bus we         | soc_tb.dut.u_core.bus_we                        | bit
bus addr       | soc_tb.dut.u_core.bus_addr                      | hex
SHIELD_CTRL    | soc_tb.dut.g_shield.u_sh.ctrl                   | hex
locked         | soc_tb.dut.g_shield.u_sh.locked                 | bit
push           | soc_tb.dut.g_shield.u_sh.do_push                | bit
pop            | soc_tb.dut.g_shield.u_sh.do_pop                 | bit
ss depth       | soc_tb.dut.g_shield.u_sh.depth                  | dec
ss top         | soc_tb.dut.g_shield.u_sh.top                    | hex
ex_target      | soc_tb.dut.u_core.br_target                     | hex
mismatch       | soc_tb.dut.g_shield.u_sh.mismatch               | bit
trap           | soc_tb.dut.u_core.sh_trap                       | bit
"""


def timing():
    import build_sw
    import run_prog
    simulator = os.environ.get("SIM") or sim.default_sim()
    prog = "timing_final"
    _, syms = build_sw.build(prog, os.path.join(sim.BUILD, "sw"))
    # run 1: find the window: 12 cycles starting with the first store to SHIELD_CTRL in EX
    result, text = run_prog.run_one(prog, 1, simulator, quiet=True, extra=["trigger_waddr=10000030"])
    if not result.startswith("RESULT: EXIT 3"):
        raise SystemExit(f"{prog} did not end in the trap handler: {result}")
    first = int(re.search(r"WTRIGGER cycle=(\d+)", text).group(1))
    start, cycles = first - 1, 12
    # run 2: dump the waveform of that window only
    vcd = os.path.join(sim.BUILD, simulator, "soc_tb", "timing_final.vcd").replace("\\", "/")
    run_prog.run_one(prog, 1, simulator, quiet=True, extra=[f"vcd={vcd}", f"vcd_from={start}", f"vcd_len={cycles + 5}"])
    sig = os.path.join(sim.BUILD, "timing_signals.txt")
    with open(sig, "w", newline="\n") as f:
        f.write(TIMING_SIGNALS)
    tmp = os.path.join(sim.BUILD, "timing_diagram")
    subprocess.run([sys.executable, os.path.join(sim.ROOT, "scripts", "vcd2wave.py"), vcd, "--signals", sig,
                    "--from", "0", "--cycles", str(cycles), "--first-cycle-label", str(start),
                    "--dis", os.path.join(sim.BUILD, "sw", prog, prog + ".dis"),
                    "--title", "ShieldV in 12 cycles (timing_final.S, in-order, SW0=1): lock, ignored write, call, MUL, return, overwrite, trap",
                    "--out", tmp], check=True)
    svg = os.path.join(OUT, "timing_diagram.svg")
    shutil.copyfile(tmp + ".svg", svg)
    print(f"  wrote diagrams/timing_diagram.svg ({cycles} cycles, from cycle {start})")
    m = re.search(r'width="(\d+)" height="(\d+)"', open(svg, encoding="utf-8").read())
    if m:
        to_png(svg, int(m.group(1)), int(m.group(2)))


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    os.makedirs(OUT, exist_ok=True)
    if what in ("block", "all"):
        block()
    if what in ("timing", "all"):
        timing()
