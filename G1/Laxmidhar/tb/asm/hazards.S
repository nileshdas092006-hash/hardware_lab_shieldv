# hazards.S - directed pipeline hazard tests (blocks A8-A12)
# Owner: Laxmidhar (G1)
#
# Each test puts instructions back to back so that the pipeline MUST forward,
# stall or flush correctly to get the right answer. a0 counts failures;
# main returns a0, so 0 means every hazard was handled.
# Built by scripts/build_sw.py as program "hazards" (crt0 calls main).

    .text
    .globl main
main:
    li      a0, 0                   # failure counter

    # 1. ALU -> ALU forwarding (result needed the very next cycle)
    li      t0, 5
    addi    t1, t0, 1               # needs t0 from the previous instruction
    li      t2, 6
    beq     t1, t2, 1f
    addi    a0, a0, 1
1:
    # 2. a chain of dependent instructions
    addi    t1, t1, 1
    addi    t1, t1, 1
    addi    t1, t1, 1               # 9
    li      t2, 9
    beq     t1, t2, 1f
    addi    a0, a0, 1
1:
    # 3. writer two instructions ahead (register-file write-through)
    li      t3, 77
    nop
    addi    t4, t3, 0
    li      t2, 77
    beq     t4, t2, 1f
    addi    a0, a0, 1
1:
    # 4. load then use immediately (load data forwarded from MEM/WB)
    addi    sp, sp, -16
    li      t0, 1234
    sw      t0, 0(sp)
    lw      t1, 0(sp)               # store -> load to the same address
    addi    t1, t1, 1               # uses the load result next cycle
    li      t2, 1235
    beq     t1, t2, 1f
    addi    a0, a0, 1
1:
    # 5. load -> jalr: exactly what a function return does with ra
    la      t0, 2f
    sw      t0, 4(sp)
    lw      t1, 4(sp)
    jalr    x0, 0(t1)               # must jump to 2f
    addi    a0, a0, 1               # wrong path: must be flushed
    addi    a0, a0, 1
2:
    # 6. taken branch: the next instruction must never execute
    beq     x0, x0, 1f
    addi    a0, a0, 1
1:
    # 7. jal over an instruction, link value correct
    jal     t5, 1f
    addi    a0, a0, 1
1:  la      t2, 1b
    addi    t2, t2, -4              # jal was 4 bytes before label 1 ... link = pc+4 of jal
    beq     t5, t2, 1f
    addi    a0, a0, 1
1:
    # 8. DIV followed by a dependent instruction (long stall)
    li      t0, 100
    li      t1, 7
    div     t2, t0, t1              # 14
    addi    t3, t2, 1               # 15, must wait for the divider
    li      t4, 15
    beq     t3, t4, 1f
    addi    a0, a0, 1
1:
    rem     t2, t0, t1              # 2
    li      t4, 2
    beq     t2, t4, 1f
    addi    a0, a0, 1
1:
    # 9. MUL back to back, second depends on the first
    li      t0, 3
    mul     t1, t0, t0              # 9
    mul     t2, t1, t0              # 27
    li      t4, 27
    beq     t2, t4, 1f
    addi    a0, a0, 1
1:
    # 10. sub-word stores and loads
    li      t0, 0x11223344
    sw      t0, 8(sp)
    li      t1, 0xAB
    sb      t1, 9(sp)               # word becomes 0x1122AB44
    lw      t2, 8(sp)
    li      t3, 0x1122AB44
    beq     t2, t3, 1f
    addi    a0, a0, 1
1:  lb      t2, 9(sp)               # 0xAB sign-extended
    li      t3, -85
    beq     t2, t3, 1f
    addi    a0, a0, 1
1:  lhu     t2, 10(sp)              # 0x1122
    li      t3, 0x1122
    beq     t2, t3, 1f
    addi    a0, a0, 1
1:
    # 11. branch that depends on a load
    lw      t0, 0(sp)               # 1234
    li      t1, 1234
    bne     t0, t1, 3f
    j       4f
3:  addi    a0, a0, 1
4:
    addi    sp, sp, 16
    ret
