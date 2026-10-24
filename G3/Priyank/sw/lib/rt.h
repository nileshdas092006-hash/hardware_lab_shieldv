// rt.h - ShieldV mini runtime (block S3)
// Owner: Priyank (G3)
//
// Bare metal means: no operating system, no C library. To print or light an
// LED, we store to the device's address (memory-mapped I/O, see
// docs/interfaces.md). `volatile` tells the compiler every access really
// matters, so it never removes or reorders them.
#ifndef SHIELDV_RT_H
#define SHIELDV_RT_H

typedef unsigned int  u32;
typedef int           s32;
typedef unsigned char u8;

#define MMIO(addr) (*(volatile u32 *)(addr))

#define LED_REG       MMIO(0x10000000u)
#define SEG7_REG      MMIO(0x10000004u)
#define SWITCH_REG    MMIO(0x10000008u)
#define UART_TX_REG   MMIO(0x10000010u)
#define UART_STATUS   MMIO(0x10000014u)
#define CYCLE_REG     MMIO(0x10000020u)
#define INSTRET_REG   MMIO(0x10000024u)
#define CALLS_REG     MMIO(0x10000028u)
#define RETS_REG      MMIO(0x1000002Cu)
#define SHIELD_CTRL   MMIO(0x10000030u)
#define SHIELD_STAT   MMIO(0x10000034u)
#define FAULT_PC      MMIO(0x10000038u)
#define FAULT_EXP     MMIO(0x1000003Cu)
#define FAULT_ACT     MMIO(0x10000040u)
#define SHIELD_HANDLER MMIO(0x10000044u)
#define BRANCHES_REG  MMIO(0x10000050u)   // branches and jumps retired
#define MISPRED_REG   MMIO(0x10000054u)   // of those, mispredicted (pipeline redirected)
#define VIOL_REG      MMIO(0x10000058u)   // ShieldV violations seen
#define CORE_ID_REG   MMIO(0x1000005Cu)   // 0 = in-order core, 1 = out-of-order core
#define SIM_EXIT      MMIO(0x100000FCu)   // simulation only: ends the testbench

// SHIELD_CTRL bits
#define SHIELD_ENABLE     0x1u
#define SHIELD_TRAP_MODE  0x2u
#define SHIELD_COUNT_ONLY 0x4u
#define SHIELD_LPAD       0x8u
#define SHIELD_LOCK       0x10u    // after this is set, CTRL and HANDLER ignore writes until reset

// landing pad marker for the forward-edge check (Zicfilp: lpad = auipc x0, 0)
#define LPAD() __asm__ volatile ("auipc x0, 0")

void uart_putc(char c);
void uart_puts(const char *s);
void print_hex(u32 v);
void print_dec(u32 v);
void print_sdec(s32 v);
void print_kv(const char *key, u32 value);   // "key=value\r\n" in decimal

// SPIKE_COMPARE builds (build_sw.py --spike) avoid every value that depends
// on timing, so the commit log matches the Spike simulator instruction for
// instruction: counters read as 0 and the UART is not polled.
#ifdef SPIKE_COMPARE
static inline u32  read_cycles(void)  { return 0; }
static inline u32  read_instret(void) { return 0; }
#else
static inline u32  read_cycles(void)  { return CYCLE_REG; }
static inline u32  read_instret(void) { return INSTRET_REG; }
#endif
static inline void set_leds(u32 v)    { LED_REG = v; }
static inline void set_seg7(u32 v)    { SEG7_REG = v; }
static inline u32  read_switches(void){ return SWITCH_REG; }

// report a workload result in a fixed format, return 0 on pass
int report(const char *name, u32 got, u32 expected, u32 cycles, u32 instret);

// end of program: simulation stops; on the board, crt0 parks the CPU
void sim_exit(u32 code);

// whole-program counters over UART; crt0 calls it after main returns
void perf_report(void);

// board only: after a trap, show FAULT_PC / EXPECTED / ACTUAL on the display,
// chosen with SW15..SW14 (00, 01, 10). Never returns.
void fault_viewer(void);

// stack canary (used only by programs built with -fstack-protector)
extern u32 __stack_chk_guard;

void *memset(void *dst, int c, unsigned n);
void *memcpy(void *dst, const void *src, unsigned n);

#endif
