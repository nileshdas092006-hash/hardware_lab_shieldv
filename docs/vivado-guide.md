# Simulating and running ShieldV in Vivado, step by step

> **For the demo, use [DEMO_RUNBOOK.md](DEMO_RUNBOOK.md).** This guide covers the in-order core only, and
> some addresses below are out of date: the attack is now caught at `000007B8`, and `hacked()` is at `0x718`.

There are two ways to do everything: **clicking in the Vivado window** (good for learning
and for looking at waveforms) and **one-line commands** (faster, same result). Both use
the same files. Commands are typed in PowerShell inside `C:\Dev\hardware_lab_shieldv`.

---

## Part 1 · Create the Vivado project (once, about 1 minute)

```powershell
cd C:\Dev\hardware_lab_shieldv
python scripts/fpga.py project attack
```

This compiles the `attack` program, runs `G2/Nilesh/fpga/create_project.tcl`, and opens
Vivado with **`build/vivado_project/shieldv.xpr`**. Next time, open that `.xpr` file from
Vivado's start page (*Open Project*).

What the project contains (left side, *Sources* window):

| Folder in Sources | What is in it |
|---|---|
| Design Sources | all 41 Verilog files; top module **fpga_top** (bold) |
| Constraints | `nexys_a7.xdc` (the board pins) |
| Simulation Sources › sim_1 | all 27 testbenches; top module **soc_tb** |

The project is set up to run the **attack program with protection ON** in simulation, and
to put the attack program into the bitstream.

To use a different program (for example `fib`), run `python scripts/fpga.py project fib`
again: it rebuilds the project for that program. Programs:
`hello fib fact qsort bintree matmul primes attack attack_trap fnptr timing1`.

---

## Part 2 · Simulate the whole system (the attack demo)

1. In the **Flow Navigator** (far left), under **SIMULATION**, click
   **Run Simulation › Run Behavioral Simulation**.
2. Vivado compiles everything (about 30 s) and runs the program to the end.
3. Look at the **Tcl Console** tab at the bottom. You should see what the program
   printed over the UART, then the result:

   ```
   ShieldV attack demo. Protection is ON
   normal call returned fine
   sending oversized input, hacked() is at 0x000004fc
   SHIELDV ALARM at cycle 12784: fault_pc=0000059c expected=0000068c actual=000004fc cause=1
   frozen pc=000005a0 (unchanged for 50 cycles), display shows 0000059c
   RESULT: BLOCKED fault_pc=0000059c
   ```

   `RESULT: BLOCKED` means ShieldV stopped the attack. `expected` is the real return
   address ShieldV saved, `actual` is the attacker's address (`hacked()`).

### See the attack with protection OFF

1. **Tools › Settings › Simulation**, tab **Simulation**.
2. Find `xsim.simulate.xsim.more_options`. At the end it says `-testplusarg sw=1`.
   Change it to `-testplusarg sw=0` (SW0 down). Click **OK**.
3. Run the simulation again (if one is open, close it first: **File › Close Simulation**).
4. The Tcl Console now ends with `!!! HACKED ...` and `RESULT: HIJACKED`.

Change it back to `sw=1` afterwards.

### Read the waveform

The waveform window opens with only the testbench's own signals. To see inside the CPU:

1. In the **Scope** window, expand `soc_tb › dut › u_core`. In the **Objects** window
   next to it, drag these into the waveform: `f_pc`, `e_pc`, `e_valid`, `stall`,
   `flush_ifid`, `br_target`.
2. Expand `soc_tb › dut › g_shield › u_sh` and drag: `do_push`, `do_pop`, `depth`,
   `top`, `mismatch`, `sh_freeze`.
3. Select all the new signals, right-click › **Radix › Hexadecimal**.
4. The waveform only has data from the moment you added a signal. Press **Restart**
   (the |◀ button in the toolbar) and then **Run All** (▶ with a bar).
5. Go to the attack: the alarm happens at cycle 12784, which is about **255.8 µs**.
   Click the zoom-fit button, then drag-select around 255.6–256.0 µs to zoom in.

What you should see, cycle by cycle (the same events are in `diagrams/timing_diagram.svg`, in trap mode):

- `e_pc` = `0x594` (`lw ra,28(sp)`): the corrupted return address is loaded from the stack.
- `e_pc` = `0x598` (`addi sp,sp,32`): the stack frame is removed.
- `e_pc` = `0x59c` (`ret`): `br_target` = `0x4fc` (attacker), `top` = `0x68c` (real).
  **`mismatch` and `sh_freeze` go to 1 in this same cycle.**
- From then on `f_pc` never changes and never becomes `0x4fc`: the attacker's code is
  never fetched.

Normal calls look like this: `do_push` pulses on every call and `depth` goes up by one;
`do_pop` pulses on every return and `depth` goes down.

---

## Part 3 · Run one module's testbench in Vivado

1. In **Sources**, open **Simulation Sources › sim_1**.
2. Right-click a testbench, for example **alu_tb**, and choose **Set as Top**.
3. **Run Simulation › Run Behavioral Simulation**.
4. The Tcl Console prints **`TEST PASSED (22014 checks)`** (or `TEST FAILED` with the
   cases that went wrong).
5. Set **soc_tb** back as top when you are done.

Testbench per member: Avani `alu_tb regfile_tb imm_gen_tb decoder_tb branch_unit_tb
pc_reg_tb mem_tb wb_mux_tb` · Laxmidhar `lsu_tb pipe_regs_tb hazard_tb` · Nishant
`multiplier_tb divider_tb munit_tb` · Nilesh `uart_tx_tb seg7_driver_tb io_regs_tb
bus_decoder_tb perf_counters_tb bus_exerciser_tb` · Priyank `callret_detect_tb
shadow_stack_tb shieldv_tb`.

Four testbenches need a compiled program or a trace and only run from the command line:
`core_single_tb`, `core_pipe_tb`, `shieldv_replay_tb`, `soc_tb` with other programs.

**The same thing without clicking** (all testbenches in about 3 minutes):

```powershell
python scripts/run_tests.py              # all 26
python scripts/run_tests.py alu          # just one
python scripts/run_prog.py attack --sw 0 # whole system, protection off
python scripts/run_prog.py attack --sw 1 # whole system, protection on
python scripts/run_prog.py all           # all 12 program scenarios
```

To look at a command-line run's waveform:
`python scripts/run_prog.py fib --vcd`, then open `build/xsim/soc_tb/fib_sw1.vcd`
in GTKWave or Surfer.

---

## Part 4 · Make the bitstream

**Clicking:** in the Flow Navigator, **PROGRAM AND DEBUG › Generate Bitstream**. Click
**Yes/OK** to run synthesis and implementation first. It takes about 5–10 minutes. The
file appears at `build/vivado_project/shieldv.runs/impl_1/fpga_top.bit`.
When it finishes, open **Reports › Report Utilization** and **Report Timing Summary**
(WNS should be positive; ours was +0.62 ns).

**Command:** `python scripts/fpga.py build attack` writes
`build/fpga/fpga_top/fpga_top.bit` plus `utilization.rpt` and `timing.rpt` in the same
folder.

---

## Part 5 · Program the Nexys A7

1. Connect the board to the laptop with the micro-USB cable (the **PROG/UART** port) and
   slide the power switch to **ON**.
2. **Clicking:** Flow Navigator › **Open Hardware Manager** › **Open Target** ›
   **Auto Connect**. Then **Program Device**, pick the `.bit` file (from Part 4) and
   click **Program**.
   **Command:** `python scripts/fpga.py program` (loads `build/fpga/fpga_top/fpga_top.bit`).
3. Open a serial terminal so you can read what the CPU prints:
   - Find the port: Windows **Device Manager › Ports (COM & LPT) › USB Serial Port (COMx)**.
     The board shows two; use the one that works.
   - **PuTTY:** Connection type **Serial**, Serial line `COMx`, Speed **115200**, Open.

The design is lost when the board is switched off; program it again after power-up.

---

## Part 6 · What to watch on the board (attack bitstream)

| Board part | Where | Meaning |
|---|---|---|
| **SW0** | rightmost slide switch | up = protection ON, down = OFF |
| **CPU_RESET** | red button | restarts the program |
| **LD16** (RGB, green) | right of the LEDs | protection armed |
| **LD17** (RGB, red) | right of the LEDs | **ShieldV alarm: CPU frozen** |
| **LD0–LD15** | green LEDs | written by the program |
| **8-digit display** | left | program output, or the fault PC when frozen |
| **Terminal** | laptop | what the program prints |

**Demo:**

1. **SW0 down**, press **CPU_RESET**. Terminal: `Protection is OFF ... !!! HACKED`. All 16
   LEDs light, the display shows `4AC4ED00`. The attack worked.
2. **SW0 up**, press **CPU_RESET**. Terminal: `Protection is ON ...` and then nothing more.
   **LD17 lights red**, the display shows **`0000059C`** (the address of the `ret` that
   was caught). The CPU is frozen: `hacked()` never ran.

**First time on a new board**, check the I/O alone before the CPU:
`python scripts/fpga.py build --top exerciser_top`, then
`python scripts/fpga.py program --top exerciser_top`. The LEDs copy the switches, the
display counts up, and the terminal prints `SHIELDV OK` twice a second.

**Other programs:** `python scripts/fpga.py build fib`, then program. The display shows
the result in hex (`00000A18` = 2584) and LD0–LD7 light for PASS; the terminal prints
PASS, cycles and CPI.

---

## Part 7 · Watch the real signals with the ILA (logic analyzer)

1. `python scripts/fpga.py build attack --ila` (adds the analyzer; also writes
   `build/fpga/fpga_top/debug_probes.ltx`).
2. `python scripts/fpga.py program` (loads the probes file too). Keep the Hardware
   Manager open (or open it and Auto Connect).
3. In the **hw_ila_1** window, **Trigger Setup** › add `alarm`, value **1** (R = rising).
4. SW0 up, click **Run Trigger** (▶), then press **CPU_RESET** on the board.
5. The waveform shows the trace port (`tr_if_pc`, `tr_ex_pc`, `tr_wb_pc`, `tr_stall`,
   `tr_flush`, `tr_ex_valid`) around the moment of the alarm, from the real chip. A
   screenshot of this is the board proof for timing Scenario 2.

---

## If something goes wrong

| Problem | Fix |
|---|---|
| `missing .../imem.hex` | build the program first: `python scripts/build_sw.py attack` |
| Simulation prints nothing | Tcl Console tab, not the Messages tab; check `more_options` has the imem/dmem paths |
| `RESULT: TIMEOUT` | the program never finished; look at `f_pc` in the waveform to see where it is stuck |
| Terminal shows nothing or garbage | wrong COM port or speed; must be 115200; press CPU_RESET after opening the terminal |
| Hardware Manager finds no device | different USB cable/port, board power switch ON, close other programs using the board |
| Timing report shows negative WNS | a change made the critical path longer; see `docs/results/README.md` for which path |
