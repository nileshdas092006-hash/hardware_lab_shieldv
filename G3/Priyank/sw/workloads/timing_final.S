# timing_final.S - the whole project in 24 clock cycles, for the final timing diagram (block S10)
# Owner: Priyank (G3)
#
# scripts/diagrams.py timing runs this on the simulated SoC (in-order core, SW0 = 1) and
# cuts exactly 24 cycles, starting when the first store below reaches EX. Everything is
# set up BEFORE that window, so inside it every cycle shows something:
#
#   1  sw   t3, 0x30(t1)   SHIELD_CTRL = 0x13: protection on, trap mode, LOCK
#   2  sw   zero, 0x30(t1) the attacker tries to switch ShieldV off: ignored (locked)
#   3  lw   t4, 0x30(t1)   read SHIELD_CTRL back: still 0x13
#   4  bne  t4, t3, fail   branch NOT taken (the read-back is forwarded, no stall, no flush)
#   5  jal  ra, scale      call: shadow-stack PUSH; the instruction behind it is flushed
#   6  (bubble)
#   7  mul  a0, a0, a1     the M-unit is busy: the pipeline STALLS (the MUL stays in EX
#   8  (mul still in EX)   for cycles 7, 8 and 9)
#   9  (mul still in EX)
#  10  ret                 normal return: shadow-stack POP; flush
#  11  (bubble)
#  12  beq  a0, a2, 1f     branch TAKEN (7*3 == 21): mispredicted by "not taken", flush
#  13  (bubble)
#  14  sw   t2, 12(sp)     the "overflow": &hacked overwrites main's saved return address
#  15  lw   ra, 12(sp)     the tampered address is loaded into ra (forwarded, no stall)
#  16  ret                 ShieldV: target != shadow-stack top -> MISMATCH, TRAP; the fault
#                          registers latch PC / expected / actual, the violation count goes up
#  17  (bubble)            the next fetch is shield_trap_entry (crt0.S), not hacked
#  18.. the security handler runs: new stack pointer, call shield_trap_handler (PUSH), ...
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
    li      a2, 21                  # expected product, for the taken branch
    nop                             # let the set-up leave the pipeline before the window
    nop
    # ---------------- the 24-cycle window starts here ----------------
    sw      t3, 0x30(t1)            # 1  lock
    sw      zero, 0x30(t1)          # 2  attacker's store: ignored
    lw      t4, 0x30(t1)            # 3  read back
    bne     t4, t3, fail            # 4  not taken
    jal     ra, scale               # 5  call (push)
    beq     a0, a2, 1f              # 12 taken
    j       fail                    #    skipped (flushed)
1:  sw      t2, 12(sp)              # 14 overflow over the saved return address
    lw      ra, 12(sp)              # 15
    ret                             # 16 caught: trap to the handler

scale:
    mul     a0, a0, a1              # 7-9 M-unit
    ret                             # 10 return (pop)

    .globl hacked
hacked:                             # never reached with protection on
    li      t0, 0xFFFF
    li      t1, 0x10000000
    sw      t0, 0(t1)               # all LEDs: HACKED
    li      a0, 0xBAD
    call    sim_exit
1:  j       1b

fail:                               # only if the lock or the MUL did not work
    li      a0, 1
    call    sim_exit
2:  j       2b
