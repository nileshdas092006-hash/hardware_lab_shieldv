// attack_skip.c - an overwrite that jumps over the stack canary (block S9)
// Owner: Priyank (G3), used by Nishant's canary-vs-ShieldV comparison
//
// attack.c overflows a buffer LINEARLY: every word from buf[0] up to the
// saved return address is overwritten, so a stack canary in between is
// destroyed too and the canary check catches it.
// Many real bugs are not linear: an out-of-range index (buf[i] = v) writes
// ONE word anywhere. Here the attacker writes &hacked into the words above
// buf[] but leaves any word that holds the canary value alone.
//
//   built normally            : protection off -> HIJACKED, on -> BLOCKED
//   built -fstack-protector-all ("attack_skip_canary"):
//                               the canary is intact, so the canary check
//                               passes and the return is hijacked unless
//                               ShieldV is on (SW0 = 1) -> BLOCKED
#include "../lib/rt.h"

void __attribute__((noinline)) hacked(void) {
    set_leds(0xFFFFu);
    uart_puts("!!! HACKED: canary skipped, execution hijacked !!!\r\n");
    sim_exit(0xBAD);
    for (;;) { }
}

// out-of-range writes: buf[i] for i = 4..10 (far enough to reach the saved
// return address with or without a canary in the frame), skipping the canary word
void __attribute__((noinline)) victim(u32 target) {
    volatile u32 buf[4];
    for (int i = 0; i < 4; i++) buf[i] = (u32)i;
    for (int i = 4; i < 11; i++)
        if (buf[i] != __stack_chk_guard) buf[i] = target;   // the bug: i >= 4
    set_seg7(buf[0]);
}

int main(void) {
    SHIELD_CTRL = SHIELD_CTRL | SHIELD_LOCK;   // lock at boot: nothing can switch ShieldV off now
    uart_puts("ShieldV attack_skip demo (non-linear overwrite)\r\n");
    victim((u32)&hacked);
    uart_puts("victim returned normally (attack missed)\r\n");
    return 1;
}
