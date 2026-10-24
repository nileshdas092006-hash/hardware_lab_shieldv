// rt.c - ShieldV mini runtime (block S3)
// Owner: Priyank (G3)
#include "rt.h"

void uart_putc(char c) {
#ifndef SPIKE_COMPARE
    while (UART_STATUS & 1u) { }        // wait while the transmitter is busy
#endif
    UART_TX_REG = (u8)c;
}

void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

void print_hex(u32 v) {
    const char *digits = "0123456789abcdef";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) uart_putc(digits[(v >> i) & 0xFu]);
}

void print_dec(u32 v) {
    char buf[11];
    int n = 0;
    do { buf[n++] = (char)('0' + v % 10u); v /= 10u; } while (v);   // uses DIVU/REMU
    while (n) uart_putc(buf[--n]);
}

void print_sdec(s32 v) {
    if (v < 0) { uart_putc('-'); print_dec((u32)(-(v + 1)) + 1u); }
    else print_dec((u32)v);
}

void print_kv(const char *key, u32 value) {
    uart_puts(key); uart_putc('='); print_dec(value); uart_puts("\r\n");
}

int report(const char *name, u32 got, u32 expected, u32 cycles, u32 instret) {
    int ok = (got == expected);
    uart_puts(ok ? "PASS " : "FAIL ");
    uart_puts(name);
    uart_puts(" result="); print_dec(got);
    if (!ok) { uart_puts(" expected="); print_dec(expected); }
    uart_puts(" cycles="); print_dec(cycles);
    uart_puts(" instret="); print_dec(instret);
    if (instret) {                       // CPI with two decimals
        u32 cpi100 = (cycles * 100u) / instret;
        uart_puts(" cpi="); print_dec(cpi100 / 100u); uart_putc('.');
        uart_putc((char)('0' + (cpi100 / 10u) % 10u)); uart_putc((char)('0' + cpi100 % 10u));
    }
    uart_puts("\r\n");
    set_seg7(got);
    set_leds(ok ? 0x00FFu : 0xF000u);
    return ok ? 0 : 1;
}

// Called by crt0 after main returns: the whole-program hardware counters,
// one line, read by scripts/measure.py (CPI, branch-prediction accuracy).
void perf_report(void) {
#ifndef SPIKE_COMPARE
    u32 c = CYCLE_REG, i = INSTRET_REG, b = BRANCHES_REG, m = MISPRED_REG;
    uart_puts("perf: core=");     print_dec(CORE_ID_REG);
    uart_puts(" cycles=");        print_dec(c);
    uart_puts(" instret=");       print_dec(i);
    uart_puts(" branches=");      print_dec(b);
    uart_puts(" mispredicts=");   print_dec(m);
    uart_puts(" calls=");         print_dec(CALLS_REG);
    uart_puts(" returns=");       print_dec(RETS_REG);
    uart_puts(" violations=");    print_dec(VIOL_REG);
    uart_puts("\r\n");
#endif
}

void sim_exit(u32 code) {
#ifndef SPIKE_COMPARE
    while (UART_STATUS & 1u) { }         // let the last character leave
#endif
    SIM_EXIT = code;
}

// ---- stack canaries (-fstack-protector), for the canary-vs-ShieldV study ----
// The compiler puts a copy of __stack_chk_guard between a function's local
// arrays and its saved return address, and checks it just before returning.
// A linear overflow that reaches ra must also overwrite the canary, so the
// check fails and __stack_chk_fail runs instead of the return.
// Bare metal has no random numbers at boot, so the value is a fixed constant
// (a real system would randomise it).
u32 __stack_chk_guard = 0x5A17C0DEu;

void __attribute__((noreturn)) __stack_chk_fail(void) {
    set_leds(0x0F0Fu);
    uart_puts("\r\n*** stack canary: stack smashing detected ***\r\n");
    sim_exit(4);
    for (;;) { }
}

void fault_viewer(void) {
    for (;;) {
        u32 pick = (read_switches() >> 14) & 3u;
        set_seg7(pick == 0 ? FAULT_PC : pick == 1 ? FAULT_EXP : FAULT_ACT);
        set_leds(0x4000u >> pick);       // LED14 = PC, LED13 = expected, LED12 = actual
    }
}

void *memset(void *dst, int c, unsigned n) {
    u8 *d = (u8 *)dst;
    while (n--) *d++ = (u8)c;
    return dst;
}

void *memcpy(void *dst, const void *src, unsigned n) {
    u8 *d = (u8 *)dst;
    const u8 *s = (const u8 *)src;
    while (n--) *d++ = *s++;
    return dst;
}

// Default security handler (trap mode). Programs that want a detailed
// report define their own shield_trap_handler(); "weak" lets theirs win.
void __attribute__((weak)) shield_trap_handler(void) {
    uart_puts("ShieldV trap at ");
    print_hex(FAULT_PC);
    uart_puts("\r\n");
}
