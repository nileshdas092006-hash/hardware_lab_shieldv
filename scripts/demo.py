#!/usr/bin/env python3
"""demo.py - one menu for the whole ShieldV demo (see docs/DEMO_RUNBOOK.md).

    python scripts/demo.py                 # the menu, starting on the out-of-order core
    python scripts/demo.py --core inorder  # the menu, starting on the in-order core
    python scripts/demo.py 2               # run item 2 and return to the terminal
    python scripts/demo.py --list          # print the menu and leave
    python scripts/demo.py 2 --dry-run     # show what item 2 would do, without running it

Every item runs the same script you could type by hand, shows that command, and
then compares the output with the result it should give.
"""
import argparse
import glob
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim  # noqa: E402

PY = sys.executable
TAGS = {"ooo": "fpga_top_ooo", "inorder": "fpga_top"}
NAMES = {"ooo": "out-of-order", "inorder": "in-order"}
OWNERS = ["Avani", "Laxmidhar", "Nishant", "Nilesh", "Priyank"]

state = {"core": "ooo", "dry": False}


def prog(name, sw, expect, say):
    """a program on the simulated SoC, on the chosen core"""
    return ("run", lambda c: ["scripts/run_prog.py", name, "--sw", str(sw), "--core", c], expect, say)


def script(args, expect, say):
    """any other script; args is a function of the chosen core"""
    return ("run", args, expect, say)


def testbenches(owner):
    names = [os.path.basename(t)[:-2] for t in glob.glob(os.path.join(sim.ROOT, "G*", owner, "tb", "*_tb.v"))]
    names = [n for n in names if n != "soc_tb"]            # soc_tb is driven by run_prog.py
    return ["scripts/run_tests.py", *sorted(names)]


# ---- the menu: (group heading) or (title, action) ----
MENU = [
    "ATTACK DEMO",
    ("Attack with protection OFF", prog("attack", 0, "RESULT: HIJACKED", "Protection off: the overflow overwrites the return address and hacked() runs.")),
    ("Attack with protection ON", prog("attack", 1, "RESULT: BLOCKED", "Same attack. ShieldV compares the return with its own saved copy and freezes the core before hacked().")),
    ("Trap mode: security report instead of a freeze", prog("attack_trap", 1, "RESULT: EXIT 3", "ShieldV jumps to a trusted handler, which prints what happened.")),
    "SHIELDV FEATURES",
    ("Lock bit ON: attacker cannot switch ShieldV off", prog("lock", 1, "RESULT: EXIT 3", "The attacker's write to the control register is ignored, so the attack is still trapped.")),
    ("Lock bit OFF: why the lock is needed", prog("lock_off", 1, "RESULT: HIJACKED", "Without the lock, the attacker first switches ShieldV off, and then the attack works.")),
    ("Landing pads: bad function-pointer call", prog("fnptr", 1, "RESULT: EXIT 3", "Marked functions are allowed. A call to an unmarked function is trapped.")),
    ("Exactly full shadow stack (32): no false alarm", prog("deep", 1, "RESULT: EXIT 0", "32 return addresses fit exactly, and the program finishes normally.")),
    ("One call too deep (33): core stops safely", prog("deep_over", 1, "RESULT: BLOCKED", "The known limit: ShieldV stops the core rather than run unchecked. It is not a false alarm.")),
    "SHIELDV VS STACK CANARIES",
    ("Canary catches a linear overflow (ShieldV off)", prog("attack_canary", 0, "RESULT: EXIT 4", "A software canary does catch a simple overflow.")),
    ("Attack that skips the canary (ShieldV off)", prog("attack_skip_canary", 0, "RESULT: HIJACKED", "This write steps over the canary, so canaries alone miss it.")),
    ("Same attack with ShieldV on", prog("attack_skip_canary", 1, "RESULT: BLOCKED", "ShieldV checks the return address itself, so it does not matter how it was overwritten.")),
    ("Full canary vs ShieldV table (about 2 min, rewrites its results file)", script(lambda c: ["scripts/canary.py", "--core", c], "", "Cost and coverage of both defences on this core.")),
    "CORRECTNESS",
    ("Run a recursive program: fib", prog("fib", 1, "RESULT: EXIT 0", "Normal programs run with ShieldV on, with no false alarm.")),
    ("All 20 program and attack scenarios (about 2 min)", script(lambda c: ["scripts/run_prog.py", "all", "--core", c], "20/20 program runs as expected", "Every scenario gives its expected outcome.")),
    ("9 C workloads vs golden model (about 1 min)", script(lambda c: ["scripts/random_diff.py", "--workloads", "--core", c], "9/9 C workloads match", "Every committed instruction matches a separate reference simulator.")),
    ("10 random programs vs golden model (about 1 min)", script(lambda c: ["scripts/random_diff.py", "-n", "10", "--core", c], "10/10 random programs match", "New random programs, compared instruction by instruction.")),
    ("48 official riscv-tests (about 3 min)", script(lambda c: ["scripts/riscv_tests.py", "--core", c], "48/48 riscv-tests passed", "The official RISC-V tests for the base and multiply/divide instructions.")),
    "UNIT TESTBENCHES (BY TEAM MEMBER)",
] + [
    (f"{o}'s blocks", script(lambda c, o=o: testbenches(o), "testbenches passed", f"{o}'s modules, each tested on its own."))
    for o in OWNERS
] + [
    ("All 37 testbenches (about 4 min)", script(lambda c: ["scripts/run_tests.py"], "37/37 testbenches passed", "Every module on its own.")),
    "HARDWARE AND BOARD",
    ("Which bitstreams exist", script(lambda c: ["scripts/fpga.py", "list"], "core:", "Each bitstream with its core, program and timing.")),
    ("Size and timing of this core", ("size",)),
    ("Load this core's bitstream onto the board", script(lambda c: ["scripts/fpga.py", "program"] + (["--ooo"] if c == "ooo" else []), "programmed", "The file is chosen from the core selected in this menu.")),
    ("Open PuTTY on the board's port", ("putty",)),
    ("What the board should show", ("board",)),
    ("Open this core's Vivado project", ("project",)),
    "PICTURES",
    ("Block diagram", ("open", "diagrams/top_block_diagram.png")),
    ("Timing diagram", ("open", "diagrams/timing_diagram.png")),
    "ANY FUNCTION, ANY VALUE",
    ("Choose a function and value: switches, then simulate", ("calc",)),
    ("Load the calculator bitstream onto the board", script(lambda c: ["scripts/fpga.py", "program", "calc"] + (["--ooo"] if c == "ooo" else []), "programmed", "One bitstream: the switches choose the function and the value.")),
]
ITEMS = [m for m in MENU if not isinstance(m, str)]


def child_env():
    env = dict(os.environ, PYTHONUTF8="1", PYTHONUNBUFFERED="1")
    env.pop("NoDefaultCurrentDirectoryInExePath", None)     # it stops Vivado's project simulation from starting
    return env


def run_script(args, expect, say):
    cmd = [PY, *args]
    print("\n> python " + " ".join(args))
    if say:
        print("  Say: " + say)
    print()
    if state["dry"]:
        return True
    start = time.time()
    p = subprocess.Popen(cmd, cwd=sim.ROOT, env=child_env(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, errors="replace")
    seen = []
    for line in p.stdout:
        sys.stdout.write(line)
        seen.append(line)
    p.wait()
    text = "".join(seen)
    took = f"{time.time() - start:.0f}s"
    if expect:
        ok = expect in text
    else:
        ok = p.returncode == 0
    if ok and "testbenches passed" in expect:              # N/N, not just the word "passed"
        m = re.search(r"(\d+)/(\d+) testbenches passed", text)
        ok = bool(m) and m.group(1) == m.group(2)
    want = f'expected "{expect}"' if expect else "expected a clean finish"
    print(f"\n[{'AS EXPECTED' if ok else 'NOT AS EXPECTED'}] {want} ({took})")
    return ok


def show_size(core):
    d = os.path.join(sim.BUILD, "fpga", TAGS[core])
    rpt = os.path.join(d, "utilization.rpt")
    print(f"\nBuild folder: {os.path.relpath(d, sim.ROOT)}")
    if not os.path.isfile(rpt):
        print(f"No build yet: python scripts/fpga.py build attack{' --ooo' if core == 'ooo' else ''}")
        return False
    with open(rpt) as f:
        text = f.read()
    for label in ("Slice LUTs", "Slice Registers", "Block RAM Tile", "DSPs"):
        m = re.search(r"\|\s*" + label + r"\s*\*?\s*\|\s*([\d.]+).*?([\d.]+)\s*\|\s*$", text, re.M)
        if m:
            print(f"  {label:16s} {m.group(1):>8s}   ({m.group(2)} % of the chip)")
    hier = os.path.join(d, "utilization_hier.rpt")
    if os.path.isfile(hier):
        with open(hier) as f:
            for line in f:
                if "u_sh" in line and "shieldv" in line:
                    cols = [c.strip() for c in line.split("|")]
                    print(f"  ShieldV alone    {cols[3]:>8s} LUTs")
                    break
    note = os.path.join(d, "build_info.txt")
    if os.path.isfile(note):
        with open(note) as f:
            info = dict(line.split(None, 1) for line in f.read().splitlines() if " " in line)
        wns = info.get("wns_ns", "?")
        print(f"  Timing at 50 MHz WNS {wns} ns ({'met' if float(wns) >= 0 else 'FAILED'})")
    return True


def find_board_port():
    """the board shows up as a USB serial port; Bluetooth serial ports are skipped"""
    ps = ("Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\\(COM\\d+\\)' } | "
          "ForEach-Object { $_.Name }")
    r = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True)
    return [re.search(r"\((COM\d+)\)", n).group(1) for n in r.stdout.splitlines()
            if "USB Serial" in n and re.search(r"\((COM\d+)\)", n)]


def open_putty():
    ports = find_board_port()
    if not ports:
        print("\nNo USB serial port found. Plug in the PROG/UART cable and switch the board on.")
        return False
    exe = r"C:\Program Files\PuTTY\putty.exe"
    print(f"\n> putty -serial {ports[0]} -sercfg 115200,8,n,1,N")
    if len(ports) > 1:
        print(f"  Several USB serial ports: {', '.join(ports)}. If this window stays empty, use another one.")
    if not state["dry"]:
        subprocess.Popen([exe, "-serial", ports[0], "-sercfg", "115200,8,n,1,N"])
    return True


def show_board(core):
    print(f"""
Terminal, first lines, every time:  Core: {NAMES[core]}
Always press CPU_RESET after moving SW0.

  SW0 DOWN (off)   terminal ends with  !!! HACKED ...
                   all 16 LEDs on      display 4AC4ED00
  SW0 UP (on)      terminal stops at   hacked() is at 0x00000718
                   red LD17 on         display 000007B8

000007B8 is the address of the ret that ShieldV caught. hacked() at 0x718 never ran.""")
    return True


def open_project(core):
    folder = "vivado_project_ooo" if core == "ooo" else "vivado_project"
    xpr = os.path.join(sim.BUILD, folder, "shieldv.xpr")
    if not os.path.isfile(xpr):
        return run_script(["scripts/fpga.py", "project", "attack"] + (["--ooo"] if core == "ooo" else []),
                          "", "Creates the project, then opens it in Vivado.")
    print(f"\nOpening {os.path.relpath(xpr, sim.ROOT)}. The title bar must show {folder}.")
    if state["dry"]:
        return True
    import fpga
    subprocess.Popen(f'"{fpga.find_vivado()}" "{xpr}"', shell=True, cwd=sim.BUILD, env=child_env())
    return True


def open_file(path):
    full = os.path.join(sim.ROOT, path.replace("/", os.sep))
    print(f"\nOpening {path}")
    if not os.path.isfile(full):
        print("That file is missing.")
        return False
    if not state["dry"]:
        os.startfile(full)
    return True


def run_calc(core):
    print("")
    subprocess.run([PY, "scripts/calc.py", "--list"], cwd=sim.ROOT, env=child_env())
    if state["dry"]:
        return True
    name = input("\nFunction name: ").strip().lower()
    value = input("Value n: ").strip()
    r = subprocess.run([PY, "scripts/calc.py", name, value, "--core", core], cwd=sim.ROOT, env=child_env())
    return r.returncode == 0


def run_item(n):
    title, action = ITEMS[n - 1]
    core = state["core"]
    print("\n" + "=" * 70 + f"\n{n}. {title}   [core: {NAMES[core]}]\n" + "=" * 70)
    kind = action[0]
    if kind == "run":
        return run_script(action[1](core), action[2], action[3])
    if kind == "size":
        return show_size(core)
    if kind == "putty":
        return open_putty()
    if kind == "board":
        return show_board(core)
    if kind == "project":
        return open_project(core)
    if kind == "calc":
        return run_calc(core)
    return open_file(action[1])


def print_menu():
    print(f"\nShieldV demo    core selected: {NAMES[state['core']].upper()}\n")
    n = 0
    for m in MENU:
        if isinstance(m, str):
            print(f"\n {m}")
        else:
            n += 1
            print(f"  {n:2d}. {m[0]}")
    print("\n  c = switch core    q = quit")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("item", nargs="?", type=int, help="run this item and leave")
    ap.add_argument("--core", default="ooo", choices=sorted(sim.CORES))
    ap.add_argument("--list", action="store_true", help="print the menu and leave")
    ap.add_argument("--dry-run", action="store_true", help="show what would run, without running it")
    args = ap.parse_args()
    state["core"], state["dry"] = args.core, args.dry_run

    if args.list:
        print_menu()
        return
    if args.item is not None:
        if not 1 <= args.item <= len(ITEMS):
            sys.exit(f"choose an item from 1 to {len(ITEMS)}")
        sys.exit(0 if run_item(args.item) else 1)

    while True:
        print_menu()
        choice = input("\nChoose: ").strip().lower()
        if choice == "q":
            return
        if choice == "c":
            state["core"] = "inorder" if state["core"] == "ooo" else "ooo"
        elif choice.isdigit() and 1 <= int(choice) <= len(ITEMS):
            run_item(int(choice))
            input("\nPress Enter for the menu ")
        else:
            print("Type a number from the menu, c or q.")


if __name__ == "__main__":
    main()
