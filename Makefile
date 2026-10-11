# ShieldV - one command per job. Every target calls a Python script in
# scripts/, so it works the same in PowerShell, Git Bash, Linux and CI.
#
#   make help                     list the targets
#   make test                     run every unit testbench           (all members)
#   make programs                 run all C programs + attack scenarios on the SoC
#   make sim PROG=attack SW=1     run one program (SW=0: protection off; CORE=ooo for the out-of-order core)
#   make riscv-tests              official rv32ui + rv32um tests     (Avani)
#   make measure                  overhead, CPI of both cores, prediction (Nilesh)
#   make random                   random programs vs golden model, both cores (Laxmidhar)
#   make canary                   stack canaries vs ShieldV          (Nishant)
#   make diagrams                 the top block diagram + the final timing diagram
#   make sw PROG=fib              compile one C program to hex files (Priynk)
#   make lint                     check all Verilog for mistakes
#   make fpga PROG=attack         Vivado: bitstream + reports        (Nilesh)
#   make program                  load the bitstream onto the board  (Nilesh)
#   make block BLOCK=shieldv      size of one module on its own      (everyone)
#
# Choose the simulator with SIM=iverilog or SIM=xsim (default: whichever is installed).

PYTHON ?= python
PROG   ?= attack
SW     ?= 1
TOP    ?= fpga_top
BLOCK  ?= shieldv
SIM    ?=
CORE   ?= inorder

export SIM

.PHONY: help test programs sim riscv-tests measure random canary diagrams sw lint fpga program block clean

help:
	@$(PYTHON) -c "print(open('Makefile').read().split('\n\n')[0])"

test:
	$(PYTHON) scripts/run_tests.py

programs:
	$(PYTHON) scripts/run_prog.py all --core $(CORE)

sim:
	$(PYTHON) scripts/run_prog.py $(PROG) --sw $(SW) --core $(CORE)

riscv-tests:
	$(PYTHON) scripts/riscv_tests.py --core $(CORE)

random:
	$(PYTHON) scripts/random_diff.py

canary:
	$(PYTHON) scripts/canary.py

diagrams:
	$(PYTHON) scripts/diagrams.py

measure:
	$(PYTHON) scripts/measure.py

sw:
	$(PYTHON) scripts/build_sw.py $(PROG)

lint:
	$(PYTHON) scripts/lint.py

fpga:
	$(PYTHON) scripts/fpga.py build $(PROG) --top $(TOP)

program:
	$(PYTHON) scripts/fpga.py program --top $(TOP)

block:
	$(PYTHON) scripts/fpga.py block $(BLOCK)

clean:
	$(PYTHON) -c "import shutil; shutil.rmtree('build', ignore_errors=True)"
