// lock.c - the lock bit: a memory write cannot switch ShieldV off (block S8)
// Owner: Priyank (G3)
//
// THE STORY
//   Boot code points SHIELD_HANDLER at the real security handler, then turns
//   protection on, picks trap mode and sets the LOCK bit, all in one store.
//   Later, an attacker who can write memory tries the cheap way out first:
//   store 0 to SHIELD_CTRL (protection off) and point SHIELD_HANDLER at
//   hacked(). Then they run the usual stack overflow.
//
//   Locked (this file)          : both writes are ignored, the overflow is
//                                 trapped to the real handler, exit code 3.
//   Not locked (-DNO_LOCK build) : the writes work, protection is off and
//                                 hacked() runs. Program name "lock_off".
#include "../lib/rt.h"

#define PAYLOAD_WORDS 8

extern void shield_trap_entry(void);

void shield_trap_handler(void) {
    u32 stat = SHIELD_STAT;
    set_leds(0xF00Fu);
    set_seg7(FAULT_PC);
    uart_puts("\r\n*** ShieldV security report ***\r\n");
    uart_puts("cause    : "); print_dec((stat >> 16) & 0xFu); uart_puts(" (1 = return mismatch)\r\n");
    uart_puts("fault PC : "); print_hex(FAULT_PC);  uart_puts("\r\n");
    uart_puts("expected : "); print_hex(FAULT_EXP); uart_puts("\r\n");
    uart_puts("actual   : "); print_hex(FAULT_ACT); uart_puts("\r\n");
    uart_puts("locked   : "); print_dec((stat >> 30) & 1u); uart_puts("\r\n");
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
    // ---- boot code ----
    SHIELD_HANDLER = (u32)&shield_trap_entry;
#ifdef NO_LOCK
    SHIELD_CTRL = SHIELD_ENABLE | SHIELD_TRAP_MODE;
    uart_puts("ShieldV lock demo: lock NOT set\r\n");
#else
    SHIELD_CTRL = SHIELD_ENABLE | SHIELD_TRAP_MODE | SHIELD_LOCK;
    uart_puts("ShieldV lock demo: lock set\r\n");
#endif
    u32 ctrl_before = SHIELD_CTRL, handler_before = SHIELD_HANDLER;

    // ---- the attacker's memory writes ----
    SHIELD_CTRL = 0;                         // switch protection off
    SHIELD_HANDLER = (u32)&hacked;           // and steal the handler
    u32 ctrl_after = SHIELD_CTRL, handler_after = SHIELD_HANDLER;
    print_kv("ctrl before", ctrl_before);
    print_kv("ctrl after ", ctrl_after);
    uart_puts(ctrl_after == ctrl_before && handler_after == handler_before
              ? "lock held: both writes ignored\r\n" : "registers changed by the attacker\r\n");

    // ---- the overflow ----
    for (int i = 0; i < PAYLOAD_WORDS; i++) payload[i] = (u32)&hacked;
    victim(payload, PAYLOAD_WORDS);
    uart_puts("victim returned normally (attack missed)\r\n");
    return 1;
}
