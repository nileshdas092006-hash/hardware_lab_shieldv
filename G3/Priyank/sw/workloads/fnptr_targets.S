# fnptr_targets.S - functions reached through function pointers (block S7)
# Owner: Priyank (G3)
#
# A legal target of an indirect call must START with an lpad marker
# (Zicfilp: `auipc x0, label`, an instruction that does nothing). Writing these
# in assembly guarantees the marker is the very first instruction, before
# any compiler-generated prologue.

    .text
    .globl add_ten
    .balign 4
add_ten:                    # u32 add_ten(u32 x) { return x + 10; }
    auipc   x0, 0           # lpad
    addi    a0, a0, 10
    ret

    .globl times_three
    .balign 4
times_three:                # u32 times_three(u32 x) { return x * 3; }
    auipc   x0, 0           # lpad
    slli    t0, a0, 1
    add     a0, a0, t0
    ret

    .globl no_pad
    .balign 4
no_pad:                     # same as add_ten but WITHOUT the landing pad
    addi    a0, a0, 10
    ret
