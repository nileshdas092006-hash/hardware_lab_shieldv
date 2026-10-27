RV32UM Multiply/Divide/Remainder Integration Test Results
Commit-plan task: G2-NS16
Run date: 2026-10-25
Core configuration: In-order core (the runner's default; no --core ooo argument was supplied)
Test suite: RISC-V rv32um assembly tests
Command: python3 scripts/riscv_tests.py mul div rem
Results
The command completed successfully. All eight RV32M multiplication, division, and remainder programs reported PASS.
Test	Operation	Result
rv32um-div	DIV — signed division	PASS
rv32um-divu	DIVU — unsigned division	PASS
rv32um-mul	MUL — low 32 bits of product	PASS
rv32um-mulh	MULH — signed × signed high word	PASS
rv32um-mulhsu	MULHSU — signed × unsigned high word	PASS
rv32um-mulhu	MULHU — unsigned × unsigned high word	PASS
rv32um-rem	REM — signed remainder	PASS
rv32um-remu	REMU — unsigned remainder	PASS


Summary
Metric	Result
Tests passed	8 / 8
Tests failed	0
Overall RV32UM simulation result	PASS


These results provide simulation evidence for the M-extension operations through the integrated in-order SoC testbench. They are simulation results, not physical-board results.
Reproduction
Run from the repository root with the RISC-V xPack toolchain and Icarus Verilog available in PATH:
python3 scripts/riscv_tests.py mul div rem
Output from the successful run:
PASS  rv32um-div
PASS  rv32um-divu
PASS  rv32um-mul
PASS  rv32um-mulh
PASS  rv32um-mulhsu
PASS  rv32um-mulhu
PASS  rv32um-rem
PASS  rv32um-remu

8/8 riscv-tests passed
Environment and reproducibility note
The successful local run required restoring the core_pipe and shieldv RTL dependencies (including helper modules) and the linker script into the working tree from a locally extracted project copy. These dependencies were absent from the checked upstream/main tree at the time of the run. A clean clone may not reproduce this result until the team integrates or otherwise makes those dependencies available.

Do not include other contributors' RTL files in the G2-NS16 commit; this task's commit should contain only G2/Nishant/reports/rv32um.md.
Milestone I3 status
The eight RV32UM simulator tests passed. This output alone does not verify milestone I3. The commit plan separately requires matrix multiplication and primes to run on the board. Mark I3 complete only after that board run has actually been performed and recorded.
