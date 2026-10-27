# crt0.S - startup code (block S1)
# Owner: Priyank (G3)
#
# The very first instructions the CPU runs after reset (address 0x0).
# C cannot run yet: there is no stack. This file
#   1. sets gp (global pointer) and sp (stack pointer, top of data RAM)
#   2. clears .bss (global variables that start at zero)
#   3. calls main()
#   4. reports main's return value to the simulator and parks the CPU
#
# Initialised data (.data, .rodata) does not need copying: the build puts it
# straight into the data RAM image (dmem.hex).

    .section .text.init
    .globl _start
_start:
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop
    la      sp, __stack_top

    la      t0, __bss_start
    la      t1, __bss_end
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:
    call    main                  # pushes the return address onto ShieldV's stack

    mv      s0, a0                # keep main's return value
    call    perf_report           # whole-program counters over UART (rt.c)
    mv      a0, s0
    call    sim_exit              # a0 holds main's return value
halt:
    j       halt                  # stay here forever (on the board)

# Entry point of the ShieldV security handler (trap mode, goal tier).
# ShieldV jumps here instead of the attacker's address. Give the handler a
# clean stack of its own, because the normal stack has just been tampered with.
    .globl shield_trap_entry
    .balign 4
shield_trap_entry:
    la      sp, __trap_stack_top
    call    shield_trap_handler
    li      a0, 3
    call    sim_exit              # simulation ends here
    call    fault_viewer          # board: show PC / expected / actual (SW15..14)
1:  j       1b
