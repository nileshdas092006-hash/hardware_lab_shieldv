# Learning log · G1 datapath (Avani Sharma)

Five plain-language lines per block: what it does, the key idea, what surprised me, how it
connects to ShieldV, and a "break it on purpose" check (what I change, which test should
catch it). Golden tables are in [`golden/`](golden/).

## A6 ALU (`rtl/alu.v`)

1. The ALU is a pure calculator: no clock, the output follows the inputs, and one 4-bit
   `op` picks among 11 operations.
2. `op = {instr[30], funct3}`, so the decoder mostly copies bits out of the instruction;
   bit 30 alone separates `add`/`sub` and `srl`/`sra`.
3. The same 32 bits can mean -1 or 4 294 967 295; `slt` and `sra` need `$signed(...)`,
   `sltu` and `srl` must not have it.
4. Loads, stores and `auipc` also use the ALU's adder, so an ALU bug breaks memory
   addresses too, including the stack that the attack overwrites.
5. Break it: replace `$signed(a) >>> b[4:0]` with `a >> b[4:0]`. The directed case
   `sra 0x8000_0000 by 31` should then give `1` instead of `0xFFFF_FFFF` and `alu_tb` fails.

## A5 Register file (`rtl/regfile.v`)

1. 32 registers, two read ports that answer instantly and one write port that writes on
   the rising clock edge.
2. x0 is not a real register: reads give 0 and writes are ignored, and the x0 check comes
   before the write-through check so x0 can never "leak" a value.
3. Write-through lets an instruction read a value that is being written in the same cycle;
   it is needed in the pipeline but must be **off** in the single-cycle core, where it
   would create a combinational loop (`addi x1, x1, 1`).
4. x1 (`ra`) lives here; it is the return address that the attack tries to corrupt and
   ShieldV protects.
5. Break it: drop the `wa != 5'd0` check in the write. The "x0 after write" check in
   `regfile_tb` should fail with `0xDEAD_BEEF`.

## A4 Immediate generator (`rtl/imm_gen.v`)

1. The immediate is the constant hidden inside an instruction, and each of the five
   formats (I, S, B, U, J) hides its bits in a different order.
2. RISC-V scrambles the bits on purpose so that the sign bit is always `instr[31]` and the
   register fields never move, which keeps the hardware simple.
3. B and J offsets are always even, so bit 0 is not stored and the hardware appends a `0`;
   U is not sign-extended at all, it is shifted left by 12.
4. `jalr` uses the I-format even though it is a jump; every `ret` (the instruction ShieldV
   checks) depends on that.
5. Break it: swap `instr[7]` and `instr[20]` (bit 11 of B and J). Small offsets still
   work, but `beq x0,x0,-4096` and `jal x0,-1MB` in `imm_gen_tb` should fail.

## A3 Decoder (`rtl/decoder.v`)

1. The decoder turns 32 instruction bits into a control word: ALU op, operand selects,
   register write, writeback select and "what kind of instruction" flags.
2. It starts from safe defaults (do nothing) and only switches on what each opcode needs,
   so nothing is left unassigned and no latch is made.
3. Bit 30 is an operation bit only for `sub`, `sra` and `srai`; for `addi` it is part of
   the immediate, which is why `addi` with bit 30 set must still be `add`.
4. Illegal instructions clear every "do something" signal, so an unknown instruction can
   never write a register or memory.
5. Break it: use `alu_op = {instr[30], funct3}` for every I-type. The case
   "addi with bit30 set is still add" in `decoder_tb` should then fail.

## A7 Branch unit (`rtl/branch_unit.v`)

1. It decides whether to leave the straight line `pc, pc+4, pc+8 …`: branches compare
   `rs1` and `rs2`, `jal` and `jalr` always jump.
2. `blt`/`bge` compare signed and `bltu`/`bgeu` compare unsigned, the same idea as `slt`
   and `sltu` in the ALU.
3. The `jalr` target is `(rs1 + imm)` with bit 0 forced to 0; branch and `jal` targets are
   `pc + imm`.
4. `link = pc + 4` is the return address a call saves, and the same value ShieldV pushes
   on its shadow stack; `target` of a return is what ShieldV checks against it.
5. Break it: remove the bit-0 clear in the `jalr` target. The check "jalr bit0 clear"
   (`rs1 = 0x1001`, `imm = 4`) in `branch_unit_tb` should then get `0x1005` instead of
   `0x1004` and fail.

## A1 Program counter (`rtl/pc_reg.v`)

1. The PC holds the address of the instruction being fetched, and a priority chain picks
   the next one: hold, then trap, then redirect, then `pc + 4`.
2. `hold` has the highest priority, so a stall or a ShieldV freeze always wins over a jump.
3. `pc_next` is exported because the instruction RAM is synchronous: we give it the
   address we are about to fetch, so the instruction arrives exactly when the PC changes.
4. ShieldV uses `hold` to freeze the CPU and `trap`/`trap_pc` to jump to its handler.
5. Break it: move the `hold` check below `trap` and `redirect`. The check "hold beats trap
   and redirect" in `pc_reg_tb` should then see the PC jump when it must stay at `0x8`.

## A2 / A15 Instruction and data RAM (`rtl/imem.v`, `rtl/dmem.v`)

1. Both are 4096 words × 32 bits = 16 KB, and both have a synchronous read: data appears
   one clock edge after the address.
2. The byte address is divided by 4 by using `addr[13:2]`; the low two bits pick a byte
   inside the word.
3. `wstrb` has one bit per byte lane, so `sb` and `sh` only change the bytes they own and
   leave the rest of the word alone.
4. The instruction RAM starts full of `nop` (`0x0000_0013`) so running past the program
   is harmless; the data RAM holds the stack, which is what the attacker overwrites.
5. Break it: write the whole word whenever `en` is 1, ignoring `wstrb`. The byte-write
   patterns in `mem_tb` should fail.

## A13 Writeback mux (`rtl/wb_mux.v`)

1. It picks what goes into `rd`: ALU result (`00`), load data (`01`), `pc + 4` (`10`) or
   the M-unit result (`11`).
2. The choice comes from the decoder's `wb_sel`, so the mux itself has no idea which
   instruction is running.
3. `jal`/`jalr` write `pc + 4` through this mux, not through the ALU.
4. This is the path that puts the return address into `ra`, the value ShieldV tracks.
5. Break it: swap the `10` and `11` cases. `wb_mux_tb` should fail and every call would
   save the wrong return address.

## Single-cycle core (`rtl/core_single.v`)

1. All the blocks above, wired so that each instruction finishes in one clock cycle:
   fetch → decode → execute → memory → writeback → next PC.
2. It needs memories that answer instantly (asynchronous read), so it is for simulation
   only; the FPGA uses the pipelined core.
3. The register file is built with `WRITE_THROUGH(0)` here to avoid a combinational loop.
4. Multiply and divide are written with Verilog `*` and `/`, including the RISC-V rules
   for divide by zero (quotient -1, remainder = dividend) and overflow.
5. Check: `run_tests.py core_single` runs `fib` and expects the program to write `0` to
   `0x1000_00FC`.

## riscv-tests regression (`tb/riscv_tests/riscv_test.h`, `/scripts/riscv_tests.py`)

1. The official riscv-tests check every RV32I and RV32M instruction, written by the
   people who wrote the spec, so they find corner cases I would not think of.
2. They normally need machine-mode CSRs and traps; our `riscv_test.h` replaces those
   macros with a tiny bare-metal setup (stack pointer, `gp` as test number).
3. PASS writes `0` to `0x1000_00FC`; FAIL writes `(test number << 1) | 1`, so the failing
   case can be read straight from the result.
4. `fence_i` and `ma_data` are skipped on purpose: our instruction RAM is read-only and the
   LSU does not support misaligned access.
5. Check: `python scripts/riscv_tests.py` (rung I1); `--core ooo` runs the same tests on
   the out-of-order core.
