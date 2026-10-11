# Getting started

This is everything you need to run the project on your own laptop, in order.
Commands are typed in **PowerShell** (or Git Bash) inside the project folder.

## 1. Install the tools (once)

| Tool | Why | How |
|---|---|---|
| Python 3 | every script in `scripts/` | python.org, tick "Add to PATH" |
| Vivado ML Standard (free) | simulator (xsim), synthesis, bitstream, ILA | amd.com, choose Artix-7 support only to save space |
| xPack RISC-V GCC | compiles our C programs for `rv32im` | `npm install --global xpm` then `xpm install --global @xpack-dev-tools/riscv-none-elf-gcc@latest` |
| GNU make (optional) | short commands like `make test` | `choco install make`, or call the Python scripts directly (shown below) |
| Icarus Verilog (optional) | faster simulator, also used by GitHub CI | bleyer.org/icarus (Windows) or `sudo apt install iverilog` (Linux/WSL) |
| GTKWave or Surfer (optional) | look at waveforms (`.vcd` files) | gtkwave.sourceforge.net / surfer-project.org |

The scripts find Vivado and the xPack compiler in their default install folders
on their own; you do not need to edit PATH for them.

## 2. Check everything works (about 10 minutes)

| What | With make | Without make | Expected |
|---|---|---|---|
| Lint all Verilog | `make lint` | `python scripts/lint.py` | "all 41 RTL files compile" |
| Unit testbenches | `make test` | `python scripts/run_tests.py` | `26/26 testbenches passed` |
| Programs + attack | `make programs` | `python scripts/run_prog.py all` | `12/12 program runs as expected` |
| Official ISA tests | `make riscv-tests` | `python scripts/riscv_tests.py` | `48/48 riscv-tests passed` |

Run just your own tests by giving part of a name: `python scripts/run_tests.py alu decoder`.

## 3. Run one program and watch it

```
make sim PROG=attack SW=0      # protection off: prints "HACKED"
make sim PROG=attack SW=1      # protection on: SHIELDV ALARM, CPU frozen
make sim PROG=fib              # a workload; prints PASS, cycles and CPI
```

Programs: `hello fib fact qsort bintree matmul primes fnptr attack attack_trap timing1 hazards`.

To look at the waveform: `python scripts/run_prog.py fib --vcd`, then open
`build/xsim/soc_tb/fib_sw1.vcd` in GTKWave or Surfer.

## 4. Numbers for the reports

```
make measure      # docs/results/overhead.md: cycles with protection off vs on, CPI
make diagrams     # diagrams/top_block_diagram.svg and diagrams/timing_diagram.svg
```

## 5. On the board (Nexys A7-100T)

```
make fpga PROG=attack          # about 5-10 minutes; bitstream in build/fpga/fpga_top/
make program                   # board connected by USB and switched on
```

Then open a serial terminal (PuTTY, or the Arduino serial monitor) on the board's
COM port at **115200 baud**, press the red CPU_RESET button, and flip **SW0**:
down = protection off (LEDs all on, "HACKED"), up = protection on (red LED LD17,
fault PC on the display).

First time on a new board, try the I/O alone: `make fpga TOP=exerciser_top`, then
`make program TOP=exerciser_top`. The LEDs copy the switches, the display counts, and
the terminal prints `SHIELDV OK`.

For the on-chip logic analyzer: `python scripts/fpga.py build attack --ila`, program
the board, open Vivado's Hardware Manager, and trigger on `alarm` rising.

## 6. Where things are

- [vivado-guide.md](vivado-guide.md) - clicking through simulation, bitstream and the board in Vivado
- [README.md](../README.md) - overview and who owns what
- [interfaces.md](interfaces.md) - the frozen ports and memory map
- [results/README.md](results/README.md) - what has been verified so far
- [how-to-commit.md](how-to-commit.md) - the git steps for the commit plans
- [golden-template.md](golden-template.md) - how to write your golden tables
