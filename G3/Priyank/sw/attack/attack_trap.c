// attack_trap.c - same attack, but ShieldV traps to a handler (goal tier)
// Owner: Priyank (G3)
//
// Instead of freezing, ShieldV redirects the bad return to
// shield_trap_entry (crt0.S), which switches to a private stack and calls
// shield_trap_handler() below. The handler reads ShieldV's fault registers
// and prints a security report over UART.
#include "../lib/rt.h"

#define PAYLOAD_WORDS 8

extern void shield_trap_entry(void);

static const char *cause_name(u32 cause) {
    switch (cause) {
        case 1:  return "return address mismatch";
        case 2:  return "shadow stack underflow";
        case 3:  return "shadow stack overflow";
        case 4:  return "missing landing pad";
        default: return "unknown";
    }
}

void shield_trap_handler(void) {
    u32 stat = SHIELD_STAT;
    set_leds(0xF00Fu);
    set_seg7(FAULT_PC);
    uart_puts("\r\n*** ShieldV security report ***\r\n");
    uart_puts("cause    : "); uart_puts(cause_name((stat >> 16) & 0xFu)); uart_puts("\r\n");
    uart_puts("fault PC : "); print_hex(FAULT_PC);  uart_puts("\r\n");
    uart_puts("expected : "); print_hex(FAULT_EXP); uart_puts("\r\n");
    uart_puts("actual   : "); print_hex(FAULT_ACT); uart_puts("\r\n");
    uart_puts("count    : "); print_dec(stat & 0xFFu); uart_puts("\r\n");
    uart_puts("attack blocked, 0 attacker instructions executed\r\n");
}

void __attribute__((noinline)) hacked(void) {
    set_leds(0xFFFFu);
    uart_puts("!!! HACKED !!!\r\n");
    sim_exit(0xBAD);
    for (;;) { }
}

void __attribute__((noinline)) copy_words(u32 *dst, const u32 *src, int n) {
    for (int i = 0; i < n; i++) dst[i] = src[i];
}

void __attribute__((noinline)) victim(const u32 *input, int n) {
    u32 buf[4];
    copy_words(buf, input, n);
    set_seg7(buf[0]);
}

static u32 payload[PAYLOAD_WORDS];

int main(void) {
    SHIELD_HANDLER = (u32)&shield_trap_entry;
    SHIELD_CTRL = SHIELD_ENABLE | SHIELD_TRAP_MODE;
    uart_puts("ShieldV trap-mode demo\r\n");
    for (int i = 0; i < PAYLOAD_WORDS; i++) payload[i] = (u32)&hacked;
    victim(payload, PAYLOAD_WORDS);
    uart_puts("victim returned normally (attack missed)\r\n");
    return 1;
}
