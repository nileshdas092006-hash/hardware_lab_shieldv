// riscv_test.h - ShieldV environment for the official riscv-tests (rv32ui, rv32um)
// Owner: Avani (G1)
//
// The riscv-tests suite is written against a small set of macros, normally
// provided by an "env" that uses machine-mode CSRs and traps. Our bare-metal
// core has none of those, so this file supplies a minimal environment:
//   * code starts at _start (address 0, from link.ld)
//   * the test number lives in gp (TESTNUM), as the tests expect
//   * PASS writes 0 to the simulation exit register (0x1000_00FC)
//   * FAIL writes (TESTNUM << 1) | 1, so the failing case can be read back
#ifndef SHIELDV_RISCV_TEST_H
#define SHIELDV_RISCV_TEST_H

#define RVTEST_RV32U
#define RVTEST_RV64U
#define TESTNUM gp

#define SIM_EXIT_ADDR 0x100000FC

#define RVTEST_CODE_BEGIN                                               \
        .section .text.init;                                            \
        .align  4;                                                      \
        .globl  _start;                                                 \
_start:                                                                 \
        la      sp, __stack_top;                                        \
        li      TESTNUM, 0;

#define RVTEST_CODE_END                                                 \
1:      j       1b;

#define RVTEST_PASS                                                     \
        li      a0, 0;                                                  \
        li      t0, SIM_EXIT_ADDR;                                      \
        sw      a0, 0(t0);                                              \
1:      j       1b;

#define RVTEST_FAIL                                                     \
        slli    a0, TESTNUM, 1;                                         \
        ori     a0, a0, 1;                                              \
        li      t0, SIM_EXIT_ADDR;                                      \
        sw      a0, 0(t0);                                              \
1:      j       1b;

#define RVTEST_DATA_BEGIN                                               \
        .data;                                                          \
        .align 4;

#define RVTEST_DATA_END

#endif
