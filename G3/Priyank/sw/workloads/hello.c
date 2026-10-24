// hello.c - first program: proves the CPU, UART and LEDs work together
// Owner: Priyank (G3)
#include "../lib/rt.h"

int main(void) {
    uart_puts("Hello from ShieldV!\r\n");
    set_leds(0x5A5Au);
    set_seg7(0x5E1DC0DEu);
    print_kv("switches", read_switches());
    return 0;
}
