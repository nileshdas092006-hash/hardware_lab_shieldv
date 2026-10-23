# Priyank Patel · G3 ShieldV unit and software

You own the security unit and every C program that runs on the CPU, including the attack.

## Hardware files (`rtl/`, `tb/`)

| Block | RTL | What it does |
|---|---|---|
| C1 Call/return detector | `callret_detect.v` | classifies the EX instruction as call, return, swap or indirect jump |
| C2 + C3 Shadow stack | `shadow_stack.v` | 32 × 32-bit LUTRAM, pointer, full/empty; push, pop, swap |
| C4 Commit control | `commit_ctrl.v` | only real (`ex_valid`) and unblocked instructions touch the stack |
| C5 Return comparator | `ret_compare.v` | target vs top of stack; also underflow and overflow |
| C6 Violation FSM | `violation_fsm.v` | NORMAL → ALARM; freeze (or trap) in the same cycle |
| C7 Mode register | `shield_ctrl.v` | SHIELD_CTRL bits, handler address; AND-ed with switch SW0 |
| C8 Landing pads (goal) | `lpad_check.v` | after an indirect jump the next instruction must be `lpad` |
| C9 Fault registers | `fault_regs.v` | FAULT_PC, EXPECTED, ACTUAL, cause, count |
| ShieldV top | `shieldv.v` | wires C1–C9 behind IF-3, register block at 0x1000_0030 |
| Stub | `shieldv_stub.v` | never fires; lets the core run before ShieldV joins |

| Testbench | What it proves |
|---|---|
| `callret_detect_tb.v` | 15 encodings, including the tricky swap and x7 cases |
| `shadow_stack_tb.v` | 32 pushes fill it, 33rd dropped, LIFO order, swap, empty pop |
| `shieldv_tb.v` | 9 scenarios with a fake pipeline (see G3 README) |
| `shieldv_replay_tb.v` | replays every call/return of a real fib run; 0 false alarms; injected attack caught |

Run them: `python scripts/run_tests.py callret shadow_stack shieldv`.

## Software files (`sw/`)

| Block | Files | What it does |
|---|---|---|
| S1 Startup + linker | `crt0.S`, `link.ld` | sets gp and sp (top of data RAM), clears .bss, calls main; code at 0x0, data at 0x1_0000 |
| S2 Build | `/scripts/build_sw.py` | gcc `-march=rv32im -mabi=ilp32`, then `imem.hex`, `dmem.hex`, `.dis` listing |
| S3 Runtime | `lib/rt.h`, `lib/rt.c` | putc/puts/print_hex/print_dec over UART, counters, LEDs, display, `report()` |
| S4 Workloads | `workloads/fib.c fact.c qsort.c bintree.c matmul.c primes.c` (+ `hello.c`, `timing1.c`) | each checks its own answer and prints PASS, cycles, CPI |
| S5 Attack | `attack/attack.c`, `attack/attack_trap.c` | the overflow; freeze version and trap-handler version |
| S6 Golden model | `golden/make_trace.py`, `shadow_model.py`, `compare_spike.py` | call/return trace, Python shadow stack, commit-log comparison with Spike |
| S7 Landing pads | `workloads/fnptr.c`, `fnptr_targets.S` | function pointers to targets with and without `lpad` |

Run them: `make programs` (all 12 scenarios) or `make sim PROG=attack SW=0` / `SW=1`.

## The ideas, in plain words

**Why LUTRAM and not block RAM?** LUTRAM can be read in the same cycle (asynchronously),
so the comparison finishes inside EX: zero extra cycles. Block RAM would add one.

**Why `ex_valid` matters.** In a pipeline some instructions are fetched and then thrown
away. If a thrown-away call pushed, the stack would go out of step and the next return
would raise a false alarm. `shieldv_tb` scenario 2 tests exactly this.

**Why freeze is combinational.** If ShieldV raised the alarm one cycle later, the PC would
already hold the attacker's address and one instruction of `hacked()` would run.

**Why the attack "sprays" the payload.** Every word of the oversized input is
`&hacked`, so it hits the saved `ra` without computing the exact offset, and only
overwrites `victim`'s own frame.

**Avoiding false alarms.** No `setjmp`/`longjmp`; recursion depth ≤ 32 (fib(18) reaches
19); use count-only mode (`SHIELD_CTRL = 0x5`) to find a false alarm without freezing.

**Comparing with Spike.** Build with `python scripts/build_sw.py fib --spike` (no
counters, no UART polling, so both runs execute the same instructions), log with
`python scripts/run_prog.py fib --log`, run Spike as described at the top of
`compare_spike.py`, then compare. Spike is not installed on the team laptop yet, so
this comparison has not been run.

## New on Oct 11

| File | What |
|---|---|
| `rtl/shield_ctrl.v`, `rtl/shieldv.v` | lock bit: CTRL bit 4; STAT bit 30 |
| `tb/shield_ctrl_tb.v` | directed write tests: 1,001 writes after the lock, 0 changes |
| `tb/shieldv_tb.v` | scenario 10: after the lock, the attack is still trapped to the real handler |
| `sw/attack/lock.c` | `lock` (trap, exit 3) and `lock_off` (hijacked) |
| `sw/attack/attack_skip.c` | out-of-range write that skips the canary |
| `sw/lib/rt.c`, `sw/crt0.S` | `perf_report()`, `fault_viewer()`, `__stack_chk_guard` / `__stack_chk_fail` |

The three formal properties planned for G3-P40 are listed at the end of
[../COMMIT_PLAN.md](../COMMIT_PLAN.md).

## Still open

- Stretch goals C10 (decode real `sspush`/`sspopchk`/`ssrdp`) and C11 (spill to memory).
- SymbiYosys proofs of the three properties (planned, tool not installed).
- The attack on the real board, and an ILA capture of it.

Your commits: rows **G3-P01 … G3-P41** in [../COMMIT_PLAN.md](../COMMIT_PLAN.md).
