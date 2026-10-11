# ShieldV

**Hardware control-flow protection for in-order and out-of-order RV32IM processors, on the Nexys A7-100T.**
CS2202L Hardware Lab, IIT Guwahati · Group 8

> **New here?** Read [docs/getting-started.md](docs/getting-started.md) to install the tools
> and run everything, [docs/vivado-guide.md](docs/vivado-guide.md) to simulate and program
> the board from the Vivado window, then the README in your own folder.
> **Diagrams:** [diagrams/top_block_diagram.png](diagrams/top_block_diagram.png) (the whole system) and
> [diagrams/timing_diagram.png](diagrams/timing_diagram.png) (the whole project in one simulated run).

## What we are building, in plain words

A processor reads instructions one after another and does what they say. Ours speaks
**RISC-V**, an open instruction set. "RV32IM" means 32-bit, the basic integer
instructions (**I**) plus multiply and divide (**M**).

It is **pipelined in 3 stages**, so three instructions are being worked on at once, like
three people on an assembly line:

| Stage | What happens |
|---|---|
| IF/ID | Fetch the instruction and work out what it means (decode), read registers |
| EX | Do the work: add, compare, compute an address, decide where to jump |
| MEM/WB | Read or write data memory, then write the result into a register |

The new part is **ShieldV**, a security unit. When a C function is called, its *return
address* (where to come back to) is saved on the stack in normal memory. A classic
attack overflows a buffer on that stack and overwrites the return address, so the
function "returns" into the attacker's code. ShieldV keeps a second, private copy of
every return address in a tiny memory that no load or store can reach. On every return
it compares the two copies; if they differ, it freezes the CPU before a single attacker
instruction runs.

## Two cores, one shield (updated Oct 11 for the new abstract)

There are now **two interchangeable cores**, chosen when the design is built:

- `core_pipe` (default): the 3-stage in-order pipeline above, the committed baseline.
- `core_ooo` (`--core ooo` in every script, `` `define SHIELDV_OOO `` in Verilog): an
  out-of-order Tomasulo core with register renaming, a 16-entry reorder buffer, reservation
  stations, a load/store queue, a common data bus, a tournament branch predictor, a BTB and
  a return-address stack. ShieldV checks returns when they **commit** (leave the reorder
  buffer), over the same wires the in-order core uses from EX.

Also new: the **lock bit** (after boot code sets SHIELD_CTRL bit 4, the control and handler
registers ignore every write until reset), counters for branches, mispredictions and
violations, a stack-canary comparison, and random programs checked against a golden model.

## Status (simulation on the team laptop, Oct 11)

Details and all numbers: [docs/results/README.md](docs/results/README.md).

| Check | In-order core | Out-of-order core |
|---|---|---|
| Unit testbenches (both cores together) | 37 / 37 pass | (included) |
| C programs + attack, lock and canary scenarios | 18 / 18 as expected | 18 / 18 as expected |
| riscv-tests rv32ui + rv32um | 48 / 48 | 48 / 48 |
| Random programs vs the golden model | 50 / 50 match | 50 / 50 match |
| Protection overhead | 0 cycles on every workload | 0 cycles on every workload |
| Speed | baseline | 1.04x geometric-mean speed-up |
| On the real board | **not yet tested**: needs the lab | **not yet tested** |

**Planned, no code yet:** SymbiYosys proofs (tool not installed), Spike runs (tool not
installed), two-wide dispatch, Zicfiss instructions with spill, privilege modes.

## How the work is split

Five people, three groups (2 + 2 + 1), as in our abstract. Each person owns hardware
modules and their testbenches.

| Group | Member | Owns | Folder |
|---|---|---|---|
| G1 · Core | Avani Sharma | Datapath: PC, ALU, register file, decoder, immediate generator, branch unit, writeback mux, memories, single-cycle core, riscv-tests; **branch predictor** (bimodal, gshare, tournament, BTB, RAS), prediction study | [G1/Avani](G1/Avani/README.md) |
| G1 · Core | Laxmidhar Mohapatra | Pipeline control: pipeline registers, forwarding, hazard/stall, flush, load/store unit, trace port, pipelined core; **out-of-order engine** (rename, ROB, RS, LSQ, CDB, commit); golden model and random tests; timing diagrams | [G1/Laxmidhar](G1/Laxmidhar/README.md) |
| G2 · RV32M + SoC | Nishant | Multiplier, divider, start/busy/done handshake, MUL/DIV tests, canary vs ShieldV comparison | [G2/Nishant](G2/Nishant/README.md) |
| G2 · RV32M + SoC | Nilesh Das (lead) | SoC: bus decoder, UART, 7-segment, LEDs, switches, performance counters, clock/reset, pins, Vivado, ILA, CI, ShieldV cost, diagrams page | [G2/Nilesh](G2/Nilesh/README.md) |
| G3 · ShieldV | Priyank Patel | ShieldV unit (detector, shadow stack, comparator, violation FSM, **lock bit**, landing pads), trap handler, all C software, formal proofs (planned) | [G3/Priynk](G3/Priynk/README.md) |

Each group folder has a README explaining its part and a **COMMIT_PLAN.md** that turns
the existing files into 20+ small commits per person, to make by hand over the weeks:
[G1](G1/COMMIT_PLAN.md) · [G2](G2/COMMIT_PLAN.md) · [G3](G3/COMMIT_PLAN.md).
Git steps for beginners: [docs/how-to-commit.md](docs/how-to-commit.md).

## Folder map

```
hardware_lab_shieldv/
├─ README.md                you are here
├─ Makefile                 make test | programs | sim | riscv-tests | random | measure | canary | diagrams | fpga
├─ diagrams/                top_block_diagram.svg/.png and timing_diagram.svg/.png
├─ docs/
│  ├─ getting-started.md    install tools, run everything
│  ├─ interfaces.md         the frozen contracts between modules and the memory map
│  ├─ results/              what has been verified, with numbers
│  ├─ PROVENANCE.md         which files are AI-assisted (for the report)
│  ├─ timing/               the two timing diagrams (generated from simulation)
│  ├─ golden-template.md    how to write your golden I/O tables
│  └─ how-to-commit.md      git basics for the commit plans
├─ G1/  Avani/ Laxmidhar/   the core            (rtl/ tb/ golden/)
├─ G2/  Nishant/ Nilesh/    M-unit and SoC      (rtl/ tb/ golden/, Nilesh: fpga/)
├─ G3/  Priynk/             ShieldV + software  (rtl/ tb/ golden/ sw/)
├─ scripts/                 Python: build software, run tests, timing diagrams, Vivado
└─ .github/workflows/       CI: lint + all tests on every push
```

In every member folder: `rtl/` is the Verilog that becomes hardware, `tb/` the
testbenches that prove it works, `golden/` the expected answers you write yourself
before reading the code ([how](docs/golden-template.md)).

## How the pieces connect

```
                      ┌──────────────── soc_top (G2 Nilesh) ────────────────┐
  switches ─► sync ─► │  ┌─────────────── core_pipe (G1) ───────────────┐   │
                      │  │ IF/ID ──► EX ──► MEM/WB                       │   │
                      │  └────┬───────┬──────────┬────────────────────────┘   │
                      │  IF-1 │  IF-3 │     IF-2 │                            │
                      │   munit    shieldv   bus_decoder ─┬─ data RAM         │
                      │ (G2 Nishant) (G3)                 ├─ LEDs, 7-seg ─────┼─► board
                      │                                   ├─ UART ────────────┼─► laptop
                      │                                   └─ counters, ShieldV registers
                      └───────────────────────────────────────────────────────┘
```

The four connections IF-1 to IF-4 and the memory map are fixed in
[docs/interfaces.md](docs/interfaces.md). Change them only when everyone affected agrees.

## Rules everyone follows

1. **Contract first.** Ports between modules are fixed in `docs/interfaces.md`.
2. **Predict before you read.** Write the golden table for a block before studying its
   code; when the simulation disagrees, find out who is wrong.
3. **Stub to start early.** `munit_stub.v` and `shieldv_stub.v` let the core run before
   the real units are joined (switch with `USE_MUNIT_STUB` / `USE_SHIELD_STUB` in `soc_top`).
4. **One rung at a time.** Join blocks in the order below; each rung has one gate test.
5. **Explain to own.** A block is yours when you can explain every line in the viva.

## The integration ladder

| Rung | Date | What joins | Gate test (command) |
|---|---|---|---|
| I0 | Oct 4–5 | everything as stubs, CI | `make lint` |
| I1 | Oct 16–17 | core + memories + software | `make riscv-tests`, `make sim PROG=fib` |
| I2 | Oct 20–21 | + SoC on the FPGA | `make fpga PROG=fib`, Fibonacci over UART |
| I3 | Oct 23–24 | + M-unit | `make sim PROG=matmul`, `PROG=primes`, then on the board |
| I4 | Oct 29–Nov 1 | + ShieldV, lock and trap | `make programs`; attack on the board with SW0; lock demo |
| I5 | Nov 2–4 | goal tier: evaluation | `attack_trap`, `fnptr`, `make measure`, `make canary`, `make diagrams` |
| I6 | Nov 1 sim, Nov 2–6 board | out-of-order core | `riscv_tests.py --core ooo`, `run_prog.py all --core ooo`, `fpga.py build attack --ooo` |

## Key dates

Oct 11 block-diagram report · Oct 13 presentation · Oct 22 core on FPGA ·
Oct 25 status report · Oct 27 mini-demo · Nov 1 minimum system complete ·
Nov 5 report + video · Nov 7–8 final demo
