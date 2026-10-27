# G3 · ShieldV · commit plan

41 commits by Priyank: 20 software, 21 hardware (updated 2026-10-11 for the new abstract:
lock bit, skip-the-canary attack, formal proofs planned). All the code already exists in
`Priyank/`; the plan adds it to git **one small step at a time, on the dates you study
each block**, so the history shows steady work and you understand each file before you
commit it.

How to use it (details in [docs/how-to-commit.md](../docs/how-to-commit.md)):

1. Study the block (README section, the code, its test).
2. Write the files marked **(you write)** yourself.
3. Run the check in the last column; it must pass.
4. `git add` exactly the files in the row, `git commit -m "<message>"`, `git push`.
5. Tick the box.

Commit from your **own** GitHub account. Paths are relative to `G3/Priyank/` unless
they start with `/` (repo root).

## Software first (branch names start with `g3/priynk-sw-`)

The software runs in simulation from day one, so it comes first and feeds the hardware
tests.

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G3-P01 | Oct 5 | `feat(sw): add startup code and linker script` | `sw/crt0.S`, `sw/link.ld` | – |
| ☐ | G3-P02 | Oct 5 | `build(sw): add build script producing hex files and listings` | `/scripts/build_sw.py` | `make sw PROG=hello` (after P04) |
| ☐ | G3-P03 | Oct 6 | `feat(sw): add mini runtime (UART print, counters, LEDs)` | `sw/lib/rt.h`, `sw/lib/rt.c` | – |
| ☐ | G3-P04 | Oct 6 | `feat(sw): add hello program` | `sw/workloads/hello.c` | `make sw PROG=hello` |
| ☐ | G3-P05 | Oct 7 | `feat(attack): add return-address overwrite program` | `sw/attack/attack.c` | `make sw PROG=attack` |
| ☐ | G3-P06 | Oct 8 | `docs(attack): explain victim's stack frame from the listing` | `sw/attack/README.md` **(you write, from `attack.dis`)** | – |
| ☐ | G3-P07 | Oct 12 | `feat(workloads): add recursive Fibonacci` | `sw/workloads/fib.c` | – |
| ☐ | G3-P08 | Oct 12 | `feat(workloads): add recursive factorial (MUL)` | `sw/workloads/fact.c` | – |
| ☐ | G3-P09 | Oct 13 | `feat(workloads): add quicksort` | `sw/workloads/qsort.c` | – |
| ☐ | G3-P10 | Oct 13 | `feat(workloads): add binary search tree` | `sw/workloads/bintree.c` | – |
| ☐ | G3-P11 | Oct 14 | `feat(workloads): add matrix multiply (MUL)` | `sw/workloads/matmul.c` | – |
| ☐ | G3-P12 | Oct 14 | `feat(workloads): add primes, GCD and division edge cases` | `sw/workloads/primes.c` | `make programs` (after I1) |
| ☐ | G3-P13 | Oct 15 | `test(golden): turn commit logs into call/return traces` | `sw/golden/make_trace.py` | – |
| ☐ | G3-P14 | Oct 15 | `test(golden): add Python shadow-stack model` | `sw/golden/shadow_model.py` | `shadow_model.py build/sw/fib/fib.trace` |
| ☐ | G3-P15 | Oct 16 | `test(golden): add commit-log comparison with Spike` | `sw/golden/compare_spike.py` | – |
| ☐ | G3-P16 | Oct 24 | `feat(sw): add landing-pad targets and function-pointer test` | `sw/workloads/fnptr.c`, `sw/workloads/fnptr_targets.S` | – |
| ☐ | G3-P17 | Oct 30 | `feat(attack): add trap-mode attack with security report` | `sw/attack/attack_trap.c` | `make sim PROG=attack_trap` |
| ☐ | G3-P18 | Oct 31 | `feat(sw): add short recursive program (timing1)` | `sw/workloads/timing1.c` | `run_prog.py timing1` |

## Hardware (branch names start with `g3/priynk-hw-`)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G3-P19 | Oct 5 | `feat(shield): add ShieldV stub obeying IF-3` | `rtl/shieldv_stub.v` | `make lint` |
| ☐ | G3-P20 | Oct 8 | `docs(detect): add call/return/indirect encoding table` | `golden/C1_callret.md` **(you write)** | – |
| ☐ | G3-P21 | Oct 9 | `feat(detect): add call/return detector with testbench` | `rtl/callret_detect.v`, `tb/callret_detect_tb.v` | `run_tests.py callret` |
| ☐ | G3-P22 | Oct 10 | `docs(ss): add golden push/pop sequence` | `golden/C2_C3_shadow_stack.md` **(you write)** | – |
| ☐ | G3-P23 | Oct 10 | `test(ss): add shadow stack push/pop/full/empty tests` | `tb/shadow_stack_tb.v` | – |
| ☐ | G3-P24 | Oct 11 | `feat(ss): add 32-entry LUTRAM shadow stack` | `rtl/shadow_stack.v` | `run_tests.py shadow_stack` |
| ☐ | G3-P25 | Oct 12 | `feat(commit): only real, unblocked instructions change the stack` | `rtl/commit_ctrl.v` | – |
| ☐ | G3-P26 | Oct 13 | `feat(cmp): add zero-cycle return comparator` | `rtl/ret_compare.v` | – |
| ☐ | G3-P27 | Oct 14 | `docs(fsm): add violation FSM state diagram` | `golden/C6_violation_fsm.drawio` **(you draw)** | – |
| ☐ | G3-P28 | Oct 14 | `feat(fsm): add violation FSM (freeze, trap, count-only)` | `rtl/violation_fsm.v` | – |
| ☐ | G3-P29 | Oct 15 | `feat(ctrl): add mode register with lock bit, and fault registers` | `rtl/shield_ctrl.v`, `rtl/fault_regs.v` | – |
| ☐ | G3-P30 | Oct 16 | `feat(lpad): add landing-pad check (goal tier)` | `rtl/lpad_check.v` | – |
| ☐ | G3-P31 | Oct 17 | `feat(shield): wire ShieldV top with register block` | `rtl/shieldv.v` | `make lint` |
| ☐ | G3-P32 | Oct 18 | `test(shield): add fake-pipeline testbench (10 scenarios)` | `tb/shieldv_tb.v` | `run_tests.py shieldv_tb` |
| ☐ | G3-P33 | Oct 21 | `test(shield): replay real workload traces, inject an attack` | `tb/shieldv_replay_tb.v` | `run_tests.py replay` |
| ☐ | G3-P34 | Oct 31 | `docs(shield): attack blocked on the board` | `reports/board_attack.md` **(lab notes + photo)** | rung I4 |
| ☐ | G3-P35 | Nov 4 | `docs(shield): add learning log` | `learning-log.md` **(you write)** | – |
| ☐ | G3-P36 | Nov 5 | `docs(shield): add ShieldV block diagram` | `shieldv.drawio` **(you draw)** | – |

## New scope (lock bit, canary comparison, formal proofs)

| | ID | Date | Commit message | Files | Check |
|---|---|---|---|---|---|
| ☐ | G3-P37 | Oct 16 | `test(lock): directed write tests for the lock bit` | `tb/shield_ctrl_tb.v` | `run_tests.py shield_ctrl` |
| ☐ | G3-P38 | Oct 17 | `feat(attack): lock demo, the attacker cannot switch ShieldV off` | `sw/attack/lock.c` | `run_prog.py lock`, `run_prog.py lock_off` (M2) |
| ☐ | G3-P39 | Oct 31 | `feat(attack): add an overwrite that skips the stack canary` | `sw/attack/attack_skip.c` | `run_prog.py all` |
| ☐ | G3-P40 | Nov 3 | `test(formal): prove 3 ShieldV safety properties with SymbiYosys` | `formal/shieldv.sby`, `formal/shieldv_props.sv` **(not written yet: planned, needs SymbiYosys installed)** | `sby -f formal/shieldv.sby` |
| ☐ | G3-P41 | Oct 29 | `feat(sw): add the program behind the final timing diagram` | `sw/workloads/timing_final.S` | `run_prog.py timing_final` (exit 3 = trapped) |

Stretch, only if everything above is done: C10 (decode `sspush`/`sspopchk`/`ssrdp`) and
C11 (spill a full shadow stack to protected memory), each as a test commit then an RTL
commit.

## Gates (milestones from the abstract)

- **Oct 8 (M1):** attack hijacks the CPU in simulation with protection off (`make sim PROG=attack SW=0`).
  The abstract also says "confirmed on Spike": Spike is not installed on the lab laptop yet, so
  this is still to do (see `sw/golden/compare_spike.py` for the command).
- **Oct 18 (M2):** all ShieldV unit tests pass, including the lock bit (after G3-P32, G3-P37, G3-P38).
- **Oct 29–Nov 1 (M5), rung I4:** attack blocked or allowed by SW0 on the board, lock and trap
  handler working (after G3-P34).
- **Nov 2–6 (M6):** three formal proofs (G3-P40, planned).

The three properties planned for G3-P40 (write them as assertions, prove them with SymbiYosys):
1. after the lock is set, SHIELD_CTRL and SHIELD_HANDLER never change until reset;
2. when a return's target differs from the shadow-stack top and protection is on, `sh_freeze`
   or `sh_trap` is high in that same cycle (so the PC never takes the target);
3. an instruction with `ex_valid = 0` never changes the shadow-stack pointer.
