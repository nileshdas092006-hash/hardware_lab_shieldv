# timing_final.S - the whole project in 12 clock cycles, for the final timing diagram (block S10)
# Owner: Priyank (G3)
#
# scripts/diagrams.py timing runs this on the simulated SoC (in-order core, SW0 = 1) and
# cuts exactly 12 cycles, starting when the first store below reaches EX. Everything is
# set up BEFORE that window, so inside it every cycle shows something:
#
#   1  sw   t3, 0x30(t1)   SHIELD_CTRL = 0x13: protection on, trap mode, LOCK
#   2  sw   zero, 0x30(t1) the attacker tries to switch ShieldV off: ignored (locked)
#   3  jal  ra, scale      call: shadow-stack PUSH; the instruction behind it is flushed
#   4  (bubble)
#   5  mul  a0, a0, a1     the M-unit is busy: the pipeline STALLS (the MUL stays in EX
#   6  (mul still in EX)   for cycles 5, 6 and 7)
#   7  (mul still in EX)
#   8  ret                 normal return: shadow-stack POP; flush
#   9  (bubble)
#  10  sw   t2, 12(sp)     the "overflow": &hacked overwrites main's saved return address
#  11  lw   ra, 12(sp)     the tampered address is loaded into ra (forwarded, no stall)
#  12  ret                 ShieldV: target != shadow-stack top -> MISMATCH, TRAP; the next
#                          fetch is shield_trap_entry, the security handler; hacked never runs
#
# Assembly instead of C so the compiler cannot spread these instructions out.
# shield_trap_entry (crt0.S) runs the default handler and ends the program with code 3.

    .text
    .globl main
main:
    addi    sp, sp, -16
    sw      ra, 12(sp)              # main's return address, saved like any C function does
    li      t1, 0x10000000          # I/O page
    la      t0, shield_trap_entry
    sw      t0, 0x44(t1)            # SHIELD_HANDLER = security handler
    li      t3, 0x13                # enable | trap mode | lock
    la      t2, hacked              # the attacker's target
    li      a0, 7
    li      a1, 3
    nop                             # let the set-up leave the pipeline before the window
    nop
    # ---------------- the 12-cycle window starts here ----------------
    sw      t3, 0x30(t1)            # 1  lock
    sw      zero, 0x30(t1)          # 2  attacker's store: ignored
    jal     ra, scale               # 3  call (push)
    sw      t2, 12(sp)              # 10 overflow over the saved return address
    lw      ra, 12(sp)              # 11
    ret                             # 12 caught: trap to the handler

scale:
    mul     a0, a0, a1              # 5-7 M-unit
    ret                             # 8  return (pop)

    .globl hacked
hacked:                             # never reached with protection on
    li      t0, 0xFFFF
    li      t1, 0x10000000
    sw      t0, 0(t1)               # all LEDs: HACKED
    li      a0, 0xBAD
    call    sim_exit
1:  j       1b
