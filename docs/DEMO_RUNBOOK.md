# ShieldV demo runbook

Follow this top to bottom. Out-of-order core first, in-order core second.
Type every command in **PowerShell**, starting in the repo folder.

What the demo proves: with SW0 down the attack takes over the CPU, and with SW0 up
ShieldV freezes the CPU at the bad return, before any attacker instruction runs. Both
cores behave this way.

## The one rule that avoids the mess

**Each core has its own folder. Never mix them.**

| | Out-of-order (present first) | In-order (present second) |
|---|---|---|
| Script flag | `--core ooo` or `--ooo` | no flag |
| Vivado project | `build/vivado_project_ooo/shieldv.xpr` | `build/vivado_project/shieldv.xpr` |
| Bitstream from the script | `build/fpga/fpga_top_ooo/fpga_top.bit` | `build/fpga/fpga_top/fpga_top.bit` |
| Bitstream from the project | `build/vivado_project_ooo/shieldv.runs/impl_1/fpga_top.bit` | `build/vivado_project/shieldv.runs/impl_1/fpga_top.bit` |
| The board prints | `Core: out-of-order` | `Core: in-order` |

The `Core:` line comes from a hardware register (`CORE_ID_REG`), so it is your proof of
which core is running. **If it shows the wrong core, stop and load the other bitstream.**

---

## Part 0: Prepare, the day before (about 30 minutes)

```powershell
cd C:\Dev\hardware_lab_shieldv
$env:PYTHONUTF8 = 1
$env:SIM = "xsim"
```

Build both bitstreams now, so that you never wait for Vivado during the demo.

```powershell
python scripts/fpga.py build attack --ooo
python scripts/fpga.py build attack
python scripts/fpga.py list
```

Each build takes about 7 minutes. `list` must show both, with a positive WNS and no
`RTL CHANGED` warning:

```
build\fpga\fpga_top\fpga_top.bit
    core: in-order, ShieldV: yes, program: attack, WNS: 0.461 ns, built ...
build\fpga\fpga_top_ooo\fpga_top.bit
    core: out-of-order, ShieldV: yes, program: attack, WNS: 0.159 ns, built ...
```

Create both Vivado projects. `--no-gui` creates a project without opening Vivado.

```powershell
python scripts/fpga.py project attack --ooo --no-gui
python scripts/fpga.py project attack --no-gui
```

---

## Part 1: Out-of-order core in the terminal

Each block below shows what you should see.

### 1.1 The attack, in simulation

```powershell
python scripts/run_prog.py attack --sw 0 --core ooo
```
```
ShieldV attack demo. Protection is OFF
Core: out-of-order
normal call returned fine
sending oversized input, hacked() is at 0x00000718
!!! HACKED: execution hijacked into hacked() !!!
RESULT: HIJACKED exit=2989
```

```powershell
python scripts/run_prog.py attack --sw 1 --core ooo
```
```
ShieldV attack demo. Protection is ON
Core: out-of-order
normal call returned fine
sending oversized input, hacked() is at 0x00000718
SHIELDV ALARM at cycle 15406: fault_pc=000007b8 expected=000008d8 actual=00000718 cause=1
RESULT: BLOCKED fault_pc=000007b8
```

How to explain the alarm line: `expected` is the real return address ShieldV saved, and
`actual` is where the overwritten stack tried to send the CPU, which is `hacked()`.

### 1.2 Everything else

| Command | Must end with | Time |
|---|---|---|
| `python scripts/run_prog.py all --core ooo` | `20/20 program runs as expected` | about 3 min |
| `python scripts/random_diff.py --workloads --core ooo` | `9/9 C workloads match the golden model on: ooo` | about 1 min |
| `python scripts/random_diff.py -n 50 --core ooo` | `50/50 random programs match the golden model on: ooo` | about 3 min |
| `python scripts/riscv_tests.py --core ooo` | `48/48 riscv-tests passed` | about 1 min |
| `python scripts/run_tests.py` (covers both cores) | `37/37 testbenches passed` | about 4 min |

**Read the summary line under the list.** In a terminal holding two runs, a list belongs to
the summary *below* it. The line now names the program set, the simulator and any failures.

`deep_over` showing `BLOCKED` in the 20 runs is correct. It nests 33 calls and the shadow
stack holds 32, so stopping the core is the known limit. It is not a false alarm.

---

## Part 2: Out-of-order core in the Vivado window

### 2.1 Open the right project

```powershell
python scripts/fpga.py project attack --ooo
```

This recreates the project and opens Vivado. To reopen it later without recreating it, use
**File > Project > Open** and pick `build/vivado_project_ooo/shieldv.xpr`.

Check that it is the out-of-order project: the title bar shows `vivado_project_ooo`.

### 2.2 Simulate

1. In **Flow Navigator** on the left, click **SIMULATION > Run Simulation > Run Behavioral Simulation**.
2. Wait about a minute. The program runs to its end by itself.
3. Open the **Tcl Console** tab at the bottom. Expect the same lines as Part 1.1 with
   protection ON: `Core: out-of-order`, then `RESULT: BLOCKED fault_pc=000007b8`.

To show protection OFF:

1. Click **File > Close Simulation**.
2. Open **Tools > Settings > Simulation**, tab **Simulation**.
3. In `xsim.simulate.xsim.more_options`, change the end from `sw=1` to `sw=0`. Click **OK**.
4. Run the simulation again. The console now ends with `RESULT: HIJACKED exit=2989`.
5. Change it back to `sw=1`.

### 2.3 Show the waveform (optional)

In the **Scope** panel, expand `soc_tb > dut > u_core`. For the out-of-order core, drag
`rob_head_pc`, `commit`, `flush` and `f_pc` from **Objects** into the waveform. Then expand
`soc_tb > dut > g_shield > u_sh` and drag `fault_pc` and `depth`. Press **Restart**, then **Run All**.

### 2.4 Bitstream from the window (optional)

Click **PROGRAM AND DEBUG > Generate Bitstream**, then **Yes > OK**. It took about 10 minutes here
and writes `build/vivado_project_ooo/shieldv.runs/impl_1/fpga_top.bit`.
Afterwards, **Open Implemented Design > Report Timing Summary** shows the WNS, which must be positive.

For a live demo, skip this and show that it was done. The script's bitstream from Part 0 holds the same design.

---

## Part 3: Out-of-order core on the board

> **Not yet checked:** I had no board. Everything in this part comes from the design and
> from the earlier run on Nishant's laptop. Rehearse it once before presenting.

### 3.1 Connect

1. Plug the micro-USB cable into the **PROG/UART** port and slide the power switch to **ON**.
2. Find the COM port: **Device Manager > Ports (COM & LPT) > USB Serial Port (COMx)**.
3. Open the terminal **before** programming, so you see the first lines.
   Use PuTTY: **Serial**, your `COMx`, speed **115200**.

On a laptop without PuTTY, this PowerShell window does the same job (replace `COM5`, press
Ctrl+C to stop, and try the other COM port if nothing appears):

```powershell
$p = New-Object System.IO.Ports.SerialPort COM5,115200; $p.Open(); while ($true) { [Console]::Write($p.ReadExisting()); Start-Sleep -Milliseconds 50 }
```

### 3.2 Load the right bitstream

By script:

```powershell
python scripts/fpga.py list
python scripts/fpga.py program --ooo
```

It prints `loading build/fpga/fpga_top_ooo/fpga_top.bit` and ends with `programmed ...`.

Or by clicking: **Flow Navigator > Open Hardware Manager > Open Target > Auto Connect**,
then **Program Device**. Choose `build\fpga\fpga_top_ooo\fpga_top.bit` and click **Program**.

Using another laptop's Vivado or PuTTY? Copy that one `.bit` file across and pick it by hand
in **Program Device**. Rename the copy first (for example `shieldv_ooo.bit`) so that the two
`fpga_top.bit` files can never be confused.

### 3.3 Run the demo

| Step | Do | Terminal | Board |
|---|---|---|---|
| 1 | SW0 **down**, press **CPU_RESET** | `Protection is OFF`, `Core: out-of-order`, ... `!!! HACKED ...` | All 16 LEDs on, display `4AC4ED00` |
| 2 | SW0 **up**, press **CPU_RESET** | `Protection is ON`, `Core: out-of-order`, ... stops after `hacked() is at 0x00000718` | Red **LD17** on, display `000007B8` |

Say this at step 2: "`000007B8` is the address of the `ret` that ShieldV caught. `hacked()`
is at `0x718` and it never ran."

**Always press CPU_RESET after moving SW0.** The program runs once from reset.

---

## Part 4: In-order core, the same way

| Step | Command or click | Expect |
|---|---|---|
| Attack OFF | `python scripts/run_prog.py attack --sw 0` | `Core: in-order`, `RESULT: HIJACKED exit=2989` |
| Attack ON | `python scripts/run_prog.py attack --sw 1` | `Core: in-order`, `SHIELDV ALARM at cycle 14509`, `RESULT: BLOCKED fault_pc=000007b8` |
| All programs | `python scripts/run_prog.py all` | `20/20 program runs as expected` |
| Golden, workloads | `python scripts/random_diff.py --workloads --core inorder` | `9/9 C workloads ...` |
| Golden, random | `python scripts/random_diff.py -n 50 --core inorder` | `50/50 random programs ...` |
| riscv-tests | `python scripts/riscv_tests.py` | `48/48 riscv-tests passed` |
| Window | `python scripts/fpga.py project attack`, then Part 2 | Title bar shows `vivado_project`, not `_ooo` |
| Board | `python scripts/fpga.py program`, then Part 3.3 | Terminal shows `Core: in-order` |

For the waveform, the in-order signals are `f_pc`, `e_pc`, `e_valid`, `stall` and `flush_ifid`
in `u_core`.

The addresses on the display are the same on both cores (`000007B8`, `0x718`) because both
run the same program. Only the `Core:` line and the cycle count differ.

---

## Part 5: If something goes wrong

| What you see | Why | Fix |
|---|---|---|
| Terminal says the wrong `Core:` | Wrong bitstream loaded | `python scripts/fpga.py program --ooo`, or without `--ooo` for in-order |
| `missing .../fpga_top.bit` | That core was never built | `python scripts/fpga.py build attack --ooo` |
| `list` says `RTL CHANGED SINCE THIS BUILD` | Bitstream is older than the Verilog | Rebuild it |
| Recursive programs time out, `pc=xxxxxxxx` | Old `ras.v`, fixed in this version | Get the latest code with `git pull`, then run again |
| `Spawn failed` or `compile.bat is not recognized` when simulating in Vivado | The shell has `NoDefaultCurrentDirectoryInExePath` set, which some tools do | `Remove-Item Env:NoDefaultCurrentDirectoryInExePath`, then start Vivado from that window |
| `No hardware target` when programming | Board off, wrong USB port, or Hardware Manager already open | Check the cable and switch, close the other Hardware Manager |
| Nothing in the terminal | Wrong COM port or speed, or opened after the program printed | Try the other COM port at 115200, press CPU_RESET |
| Display and LEDs do not change after moving SW0 | No reset | Press CPU_RESET |

To run tests in WSL on Icarus (as on Nishant's laptop), use `SIM=iverilog python3 scripts/random_diff.py --workloads --core ooo`.

---

## Part 6: Verified results

Run on 2026-11-07, after the `ras.v` fix, on the team lead's laptop.

| Check | Out-of-order | In-order |
|---|---|---|
| Unit testbenches (one set, covers both cores) | 37/37 | 37/37 |
| Programs and attack scenarios | 20/20 | 20/20 |
| riscv-tests rv32ui + rv32um | 48/48 | 48/48 |
| C workloads vs golden model, every instruction | 9/9 | 9/9 |
| Random programs vs golden model, every instruction | 50/50 | 50/50 |
| Vivado script build: WNS at 50 MHz | +0.159 ns | +0.461 ns |

The first five rows pass on Vivado's simulator. The first four also pass on Icarus 11 and 12,
but the random programs were not run on Icarus. Simulation in the Vivado project was checked
in batch mode, not by clicking: BLOCKED with `sw=1` and HIJACKED with `sw=0`, on both cores.

**Not checked:**

- Anything on the real board with these bitstreams, including the PowerShell serial window.
  `fpga.py program --ooo` was only run with no board attached: it picked the right file, then
  stopped at "no current hw_target" as expected.
- The Vivado clicks themselves, and the waveform steps in 2.3.
