// attack.c - a controlled return-address overwrite (block S5)
// Owner: Priyank (G3)
//
// THE STORY
//   main() calls victim(). victim() saves its return address (ra) on the
//   stack, then copies "user input" into a 4-word local buffer WITHOUT
//   checking the length. The input is longer than the buffer, so the copy
//   runs past the end of buf[] and overwrites the saved ra with the address
//   of hacked(). When victim() returns, it jumps into hacked().
//
//   Protection OFF (SW0 down): hacked() runs, LEDs light up, "HACKED" is printed.
//   Protection ON  (SW0 up)  : ShieldV sees that the return goes to hacked()
//                              instead of back into main(), freezes the CPU
//                              before hacked()'s first instruction, lights the
//                              red LED and shows the faulting PC on the display.
//
// Why "spray" the input with &hacked instead of computing the exact offset?
// The saved ra sits a few words above buf[] (see attack/README.md for the
// exact frame from the objdump). Filling every word with &hacked hits ra no
// matter which of those words it is, and only touches victim's own frame.
#include "../lib/rt.h"

#define BUF_WORDS     4
#define PAYLOAD_WORDS 8          // buf[4] + the saved registers above it

void __attribute__((noinline)) hacked(void) {
    set_leds(0xFFFFu);                          // all LEDs: HACKED pattern
    set_seg7(0x4AC4ED00u);                      // "HACKED" (as close as hex digits get)
    uart_puts("!!! HACKED: execution hijacked into hacked() !!!\r\n");
    sim_exit(0xBAD);
    for (;;) { }
}

// copies n words; deliberately does not know how big dst is
void __attribute__((noinline)) copy_words(u32 *dst, const u32 *src, int n) {
    for (int i = 0; i < n; i++) dst[i] = src[i];
}

void __attribute__((noinline)) victim(const u32 *input, int n) {
    u32 buf[BUF_WORDS];
    copy_words(buf, input, n);                  // the bug: n is not checked
    set_seg7(buf[0]);
}

static u32 payload[PAYLOAD_WORDS];

int main(void) {
    u32 sw = read_switches();
    SHIELD_CTRL = SHIELD_CTRL | SHIELD_LOCK;   // lock at boot: nothing can switch ShieldV off now
    uart_puts("ShieldV attack demo. Protection is ");
    uart_puts((sw & 1u) ? "ON\r\n" : "OFF\r\n");
    // the hardware says which core this bitstream holds, so the demo can prove it
    uart_puts(CORE_ID_REG ? "Core: out-of-order\r\n" : "Core: in-order\r\n");

    // 1. a normal, well-behaved call: must NOT raise an alarm
    u32 ok_input[BUF_WORDS] = {1, 2, 3, 4};
    victim(ok_input, BUF_WORDS);
    uart_puts("normal call returned fine\r\n");

    // 2. the attack
    for (int i = 0; i < PAYLOAD_WORDS; i++) payload[i] = (u32)&hacked;
    uart_puts("sending oversized input, hacked() is at ");
    print_hex((u32)&hacked);
    uart_puts("\r\n");
    victim(payload, PAYLOAD_WORDS);

    // only reached if the overflow did not hit ra
    uart_puts("victim returned normally (attack missed)\r\n");
    return 1;
}
