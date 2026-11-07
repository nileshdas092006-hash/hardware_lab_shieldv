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

## Start here: the demo menu

One command gives you every function of the project:

```powershell
cd C:\Dev\hardware_lab_shieldv
python scripts/demo.py
```

Type a number to run that item. Type `c` to switch core; the top line always shows which core
is selected, and it starts on out-of-order. Each item shows the real command, a sentence you
can say, the output, and then `[AS EXPECTED]` or `[NOT AS EXPECTED]`.

To answer a question from an examiner, find the row and type its number:

| They ask about | Menu item |
|---|---|
| The attack, on and off | 1, 2 |
| What happens after a catch, the security report | 3 |
| Can an attacker switch ShieldV off? | 4, 5 |
| Function pointers, landing pads | 6 |
| Deep recursion, shadow stack limit | 7, 8 |
| Why not use stack canaries? | 9, 10, 11, then 12 for the full table |
| Does it run normal programs? | 13, 14 |
| Is the CPU correct? | 15, 16, 17 |
| One team member's modules | 18 to 22 (all of them: 23) |
| How big is it, does it meet timing? | 25 |
| Show it in Vivado | 29, then Part 2 below |
| Show the design | 30, 31 |
| Run this function with this value, on the board | 32 for the switches, 33 to load (next section) |

## Presenting order

**Before the audience arrives**

1. Plug in the board and switch it on. Close any old PuTTY and Hardware Manager windows.
2. Open PowerShell and run `python scripts/demo.py`.
3. Run item 24. Both bitstreams must be listed, with no `RTL CHANGED` warning.
4. Run items 1 and 2 once. The first run compiles the design, so it is slower than later runs.

**During the demo.** Start in the out-of-order core; the board steps need the board in view.

| # | Show | Menu | Point to make |
|---|---|---|---|
| 1 | The design | 30 | The core, ShieldV beside it, and the shadow stack nothing on the data bus can reach |
| 2 | Attack in simulation | 1, then 2 | Same program, and only the switch differs |
| 3 | Load the real chip | 26, then 27 | The file is picked from the selected core |
| 4 | Attack on the board | 28, then SW0 down and up | Press CPU_RESET each time. `Core: out-of-order`, HACKED, then the red LED and `000007B8` |
| 5 | Stronger features | 3, 4, 5, 6 | Report, lock bit, landing pads |
| 6 | Versus canaries | 10, 11 | Canaries miss this attack, ShieldV does not |
| 7 | It is a correct CPU | 15, 17 | Matches the golden model; official tests pass |
| 8 | Its cost | 25 | Small, and 50 MHz met |
| 9 | In Vivado (if asked) | 29 | Show the title bar and the Tcl Console |

**Then the in-order core.** Close PuTTY so the port is free, type `c` (the top line now says
IN-ORDER), and repeat rows 2, 3, 4 and 8. Rows 5 to 7 give the same results, so run them only if asked.
The terminal must now say `Core: in-order`.

**Three traps**

- Only one window can hold the COM port. If PuTTY shows an error, close the older PuTTY window.
- Item 12 rewrites `docs/results/canary_vs_shieldv*.md`. Run `git status` afterwards, and use
  `git restore` on those files if you do not want the change.
- The attack bitstream and the calculator bitstream are different files. To go back to the attack
  demo after the calculator, run item 26 again.

---

## Any function, any value: the calculator bitstream

Use this when the professor says "run fib of 12" or "now factorial of 5". It is one bitstream
with no rebuild: the **switches choose the function and the value**, and CPU_RESET runs it. The
board has no keyboard path into the CPU, because its UART only sends, so the switches are the input.

| Switches | Meaning |
|---|---|
| SW15, SW14, SW13 | Which function (table below) |
| SW12 to SW1 | The value n, in binary |
| SW0 | ShieldV: up = on, down = off |

| Number | SW15 SW14 SW13 | Function | n up to | The answer is |
|---|---|---|---|---|
| 0 | 0 0 0 | `fib` | 47 | The n-th Fibonacci number (recursive) |
| 1 | 0 0 1 | `fact` | 12 | n factorial (recursive) |
| 2 | 0 1 0 | `qsort` | 256 | Quicksort n numbers; a checksum of the sorted list |
| 3 | 0 1 1 | `bintree` | 256 | Search tree of n keys; a checksum of the in-order walk |
| 4 | 1 0 0 | `matmul` | 12 | Multiply two n x n matrices; a checksum of the product |
| 5 | 1 0 1 | `primes` | 4095 | How many primes are below n |
| 6 | 1 1 0 | `nest` | 400 | Nests n calls, to show the shadow stack limit |
| 7 | 1 1 1 | `custom` | 4095 | Your own function (default: 1 + 2 + ... + n) |

If n is above the limit, the program says so and uses the limit. 47 and 12 are where the
answer stops fitting in 32 bits.

**On the board**

1. In the menu, run item 33. It loads the calculator for the selected core.
2. Open PuTTY with item 27.
3. Set the switches and press **CPU_RESET**. The switches are read only at reset.
4. Read the answer in PuTTY in decimal. The display shows the same number in hex, and LD0 to LD7 light when it finishes.

**Do not work out the binary by hand.** Run item 32, or use this, which prints the switches, the
answer to expect, and a simulation:

```powershell
python scripts/calc.py fib 18
```
```
  SW  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
       0  0  0  0  0  0  0  0  0  0  1  0  0  1  0  1
      |function| |------------- value ------------| |ShieldV

Expected answer: 2584  (display 00000A18)
```

Add `--no-sim` to print only the switches.

| Ask | SW15 to SW0 | PuTTY | Display |
|---|---|---|---|
| `fib 18` | `000 000000010010 1` | `answer = 2584` | `00000A18` |
| `fact 5` | `001 000000000101 1` | `answer = 120` | `00000078` |
| `primes 1000` | `101 001111101000 1` | `answer = 168` | `000000A8` |
| `nest 31` with ShieldV on | `110 000000011111 1` | stops after `nest(31) ...` | red LD17, `00000A0C` |

**The limit of 31 nested calls, and how to explain it.** With SW0 up, `fib` works up to 31, and
`nest` up to 30, because `nest` uses one more call level. Above that, the 32-entry shadow stack
is full, so ShieldV stops the core with the red LED on. That is the design's safe choice, not a
crash. Put SW0 down and press CPU_RESET to show that the same value then runs.

**How long it takes on the board** (50 MHz): `fib 31` took 67 million cycles in simulation, which
is about 1.3 seconds. Each +1 on n takes about 1.6 times as long, so with SW0 down expect about 9 seconds
for `fib 35`, under 2 minutes for `fib 40`, and most of an hour for `fib 47`. These are
estimates. Do not offer values above 40.

**A function that is not in the table.** The professor's new function goes in
`G3/Priyank/sw/workloads/calc_custom.c`, as number 7:

```powershell
python scripts/calc.py custom 10
python scripts/fpga.py build calc --ooo
python scripts/fpga.py program calc --ooo
```

The first command tries it in simulation in about 10 seconds, so show that straight away. The
build takes about 7 minutes. Since `custom` has no Python copy, `calc.py` cannot check its
answer: check it yourself.

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
python scripts/fpga.py build calc --ooo
python scripts/fpga.py build calc
python scripts/fpga.py list
```

Each build takes about 7 minutes. `list` must show all four, with a positive WNS and no
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
| `python scripts/run_prog.py all --core ooo` | `20/20 program runs as expected` | about 2 min |
| `python scripts/random_diff.py --workloads --core ooo` | `9/9 C workloads match the golden model on: ooo` | about 1 min |
| `python scripts/random_diff.py -n 50 --core ooo` | `50/50 random programs match the golden model on: ooo` | about 4 min |
| `python scripts/riscv_tests.py --core ooo` | `48/48 riscv-tests passed` | about 3 min |
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

> On this laptop the board was on **COM7** and PuTTY is installed. COM3 to COM6 are
> Bluetooth, not the board. Menu item 27 finds the port and opens PuTTY for you.

### 3.1 Connect

1. Plug the micro-USB cable into the **PROG/UART** port and slide the power switch to **ON**.
2. Find the COM port: **Device Manager > Ports (COM & LPT) > USB Serial Port (COMx)**.
3. Open the terminal **before** programming, so you see the first lines.
   Use PuTTY: **Serial**, your `COMx`, speed **115200**.

If PuTTY is unavailable, this PowerShell window does the same job (use your port, press
Ctrl+C to stop, and try the other COM port if nothing appears):

```powershell
$p = New-Object System.IO.Ports.SerialPort COM7,115200; $p.Open(); while ($true) { [Console]::Write($p.ReadExisting()); Start-Sleep -Milliseconds 50 }
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

**Calculator, in simulation, both cores:** 31 function and value pairs with ShieldV on, plus 3 with it
off, all gave the expected result. Answers match a separate Python copy of each function, and
that copy gives the team's known answers for `fib 18`, `fact 12`, `qsort 64`, `bintree 31`, `matmul 8` and
`primes 1000`. `fib 31` passes and `fib 32` stops; `nest 30` passes and `nest 31` stops. Bitstreams built with the
same WNS as the attack ones.

**Not checked:**

- The calculator on the real board, including how long it really takes.

- The PowerShell serial window.
- The Vivado clicks themselves, and the waveform steps in 2.3.

**On the real board** (Das's laptop, COM7, 2026-11-07): the out-of-order terminal output was
correct with SW0 down and up, shown in a PuTTY screenshot. Das also reports that the LEDs and
display matched.
