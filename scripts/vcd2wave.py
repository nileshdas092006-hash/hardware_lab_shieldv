# Owner: Laxmidhar (G1) - VCD to WaveDrom/SVG converter
#!/usr/bin/env python3
"""vcd2wave.py - turn a window of a simulation VCD into a timing diagram.

    python scripts/vcd2wave.py build/xsim/soc_tb/timing1.vcd \
        --signals build/timing_signals.txt --from 0 --cycles 40 \
        --dis build/sw/timing1/timing1.dis --title "Scenario 1" --out build/scenario1
(scripts/diagrams.py timing calls it for the final timing diagram.)

Writes <out>.json (WaveDrom format, paste into wavedrom.com/editor.html),
<out>.html (opens in a browser, rendered by WaveDrom) and <out>.svg (drawn
by this script, no internet needed, ready for the report).

Every value is sampled once per clock cycle, half a cycle after the rising
edge, i.e. the value the signal holds during that cycle. Because the VCD
comes from a real simulation run, the diagram shows what the hardware
actually did, which is what the course asks for.

signals.txt format, one row per line:   label | hierarchical.path | format
  format: bit, hex, dec, or instr:<path of valid bit>  (shows the assembly
  text for a PC, using the objdump listing given with --dis; "bubble" when
  the valid bit is 0)
"""
import argparse
import html
import json
import re


def parse_vcd(path):
    """Return {full_name: [(time, value_str), ...]} and the timescale."""
    ids, changes, scope = {}, {}, []
    t = 0
    with open(path) as f:
        in_defs = True
        for line in f:
            tok = line.split()
            if not tok:
                continue
            if in_defs:
                if tok[0] == "$scope":
                    scope.append(tok[2])
                elif tok[0] == "$upscope":
                    scope.pop()
                elif tok[0] == "$var":
                    code, name = tok[3], tok[4]
                    full = ".".join(scope + [name])
                    ids.setdefault(code, []).append(full)
                    changes[full] = []
                elif tok[0] == "$enddefinitions":
                    in_defs = False
                continue
            i = 0
            while i < len(tok):
                item = tok[i]
                if item[0] == "#":
                    t = int(item[1:])
                elif item[0] == "$":
                    pass                                   # $dumpvars, $dumpoff, $end ...
                elif item[0] in "bBrR":                    # vector: "b1010 <id>"
                    for n in ids.get(tok[i + 1], []):
                        changes[n].append((t, item[1:]))
                    i += 1
                elif item[0] in "01xXzZ":                  # scalar: "1<id>"
                    for n in ids.get(item[1:], []):
                        changes[n].append((t, item[0]))
                i += 1
    return changes


def find(changes, path):
    if path in changes:
        return path
    hits = [n for n in changes if n.endswith("." + path.split(".")[-1]) and
            all(p in n.split(".") for p in path.split(".")[1:-1] if not p.startswith("g_"))]
    hits = [n for n in hits if n.split(".")[-1] == path.split(".")[-1]]
    best = [n for n in hits if n.endswith(path.split("soc_tb.", 1)[-1].replace("g_shield.", ""))]
    if best:
        return best[0]
    if hits:
        return hits[0]
    raise SystemExit(f"signal {path} not found in the VCD")


def value_at(series, t):
    v = None
    for ct, cv in series:
        if ct > t:
            break
        v = cv
    return v


def to_int(v):
    try:
        return int(v, 2)
    except (TypeError, ValueError):
        return None


def load_dis(path):
    m = {}
    if not path:
        return m
    for line in open(path):
        r = re.match(r"\s+([0-9a-f]+):\s+(.*)$", line)
        if r:
            m[int(r.group(1), 16)] = re.sub(r"\s+#.*$", "", r.group(2)).replace("\t", " ").strip()
    return m


def build(args):
    ch = parse_vcd(args.vcd)
    clk = find(ch, args.clock)
    rises = [t for t, v in ch[clk] if v == "1"]
    if len(rises) < 2:
        raise SystemExit("no clock edges in the VCD window")
    half = (rises[1] - rises[0]) // 2
    samples = [t + half for t in rises[args.start:args.start + args.cycles]]
    dis = load_dis(args.dis)

    rows = []
    for line in open(args.signals):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        label, path, fmt = [x.strip() for x in line.split("|")]
        name = find(ch, path)
        vals = []
        if fmt.startswith("instr:"):
            valid = find(ch, fmt.split(":", 1)[1])
            for t in samples:
                pc, ok = to_int(value_at(ch[name], t)), value_at(ch[valid], t)
                vals.append("bubble" if ok != "1" else dis.get(pc, "%x" % pc if pc is not None else "x"))
            rows.append((label, "bus", vals))
        elif fmt == "bit":
            rows.append((label, "bit", [value_at(ch[name], t) or "x" for t in samples]))
        else:
            out = []
            for t in samples:
                n = to_int(value_at(ch[name], t))
                out.append("x" if n is None else (("%x" % n) if fmt == "hex" else str(n)))
            rows.append((label, "bus", out))
    return rows


def wavedrom(rows, title, first_cycle):
    sig = [{"name": "clk", "wave": "p" + "." * (len(rows[0][2]) - 1)}]
    for label, kind, vals in rows:
        wave, data, prev = "", [], None
        for v in vals:
            if kind == "bit":
                wave += "." if v == prev else (v if v in "01" else "x")
            else:
                if v == prev:
                    wave += "."
                else:
                    wave += "x" if v == "x" else ("=" if v != "bubble" else "2")
                    if v != "x":
                        data.append(v)
            prev = v
        entry = {"name": label, "wave": wave}
        if data:
            entry["data"] = data
        sig.append(entry)
    return {"signal": sig, "head": {"text": title, "tick": first_cycle},
            "config": {"hscale": 2}}


def svg(rows, title, first_cycle, cw=74, rh=30, lw=110):
    n = len(rows[0][2])
    W, H = lw + n * cw + 20, 60 + (len(rows) + 1) * rh
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="monospace" font-size="11">',
         f'<rect width="{W}" height="{H}" fill="white"/>',
         f'<text x="10" y="20" font-size="14" font-weight="bold">{html.escape(title)}</text>']
    y0 = 40
    for c in range(n + 1):
        x = lw + c * cw
        o.append(f'<line x1="{x}" y1="{y0}" x2="{x}" y2="{H - 10}" stroke="#ddd"/>')
        if c < n:
            o.append(f'<text x="{x + cw / 2}" y="{y0 - 4}" text-anchor="middle" fill="#888">{first_cycle + c}</text>')
    # clock
    y = y0 + 6
    d = f"M{lw},{y + rh - 12}"
    for c in range(n):
        x = lw + c * cw
        d += f" L{x},{y} L{x + cw / 2},{y} L{x + cw / 2},{y + rh - 12} L{x + cw},{y + rh - 12}"
    o.append(f'<text x="8" y="{y + 12}">clk</text><path d="{d}" fill="none" stroke="black"/>')
    for i, (label, kind, vals) in enumerate(rows):
        y = y0 + (i + 1) * rh + 6
        top, bot, mid = y, y + rh - 12, y + (rh - 12) / 2
        o.append(f'<text x="8" y="{mid + 4}">{html.escape(label)}</text>')
        if kind == "bit":
            d = ""
            for c, v in enumerate(vals):
                x = lw + c * cw
                yy = top if v == "1" else bot
                d += (f"M{x},{yy}" if c == 0 else f" L{x},{yy}") + f" L{x + cw},{yy}"
            color = "#c00" if label.lower() in ("mismatch", "freeze", "alarm") else "#06c"
            o.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2"/>')
        else:
            c = 0
            while c < n:
                e = c
                while e + 1 < n and vals[e + 1] == vals[c]:
                    e += 1
                x1, x2, k = lw + c * cw, lw + (e + 1) * cw, 4
                v = vals[c]
                fill = "#eee" if v in ("bubble", "x") else "#e8f0fe"
                o.append(f'<path d="M{x1},{mid} L{x1 + k},{top} L{x2 - k},{top} L{x2},{mid} L{x2 - k},{bot} '
                         f'L{x1 + k},{bot} Z" fill="{fill}" stroke="#333"/>')
                maxch = max(3, int((x2 - x1) / 7))
                text = v if len(v) <= maxch else v[:maxch - 1] + "~"
                o.append(f'<text x="{(x1 + x2) / 2}" y="{mid + 4}" text-anchor="middle">{html.escape(text)}</text>')
                c = e + 1
    o.append("</svg>")
    return "\n".join(o)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("vcd")
    ap.add_argument("--signals", required=True)
    ap.add_argument("--clock", default="soc_tb.clk")
    ap.add_argument("--from", dest="start", type=int, default=0, help="first clock cycle in the VCD window")
    ap.add_argument("--cycles", type=int, default=30)
    ap.add_argument("--first-cycle-label", type=int, default=None, help="cycle number printed on the first column")
    ap.add_argument("--dis", default=None)
    ap.add_argument("--title", default="ShieldV timing diagram")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    rows = build(args)
    label0 = args.first_cycle_label if args.first_cycle_label is not None else args.start
    with open(args.out + ".json", "w") as f:
        json.dump(wavedrom(rows, args.title, label0), f, indent=1)
    with open(args.out + ".svg", "w") as f:
        f.write(svg(rows, args.title, label0))
    with open(args.out + ".html", "w") as f:
        f.write('<!doctype html><meta charset="utf-8"><title>%s</title>\n'
                '<script src="https://unpkg.com/wavedrom@3.5.0/skins/default.js"></script>\n'
                '<script src="https://unpkg.com/wavedrom@3.5.0/wavedrom.min.js"></script>\n'
                '<body onload="WaveDrom.ProcessAll()"><script type="WaveDrom">%s</script></body>\n'
                % (html.escape(args.title), json.dumps(wavedrom(rows, args.title, label0))))
    print(f"wrote {args.out}.svg / .json / .html ({args.cycles} cycles, {len(rows)} signals)")


if __name__ == "__main__":
    main()
