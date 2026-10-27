// fnptr.c - function pointers and the landing-pad check (goal tier, C8 + S7)
// Owner: Priyank (G3)
//
// Calls two marked functions through a function pointer (allowed), then
// calls an unmarked one (a forward-edge violation). With the landing-pad
// check on and trap mode, ShieldV jumps to the handler, which prints the
// report and ends the program with code 3.
#include "../lib/rt.h"

typedef u32 (*op_fn)(u32);
extern u32 add_ten(u32);
extern u32 times_three(u32);
extern u32 no_pad(u32);
extern void shield_trap_entry(void);

// volatile: force a real indirect call (jalr) instead of a direct one
static volatile op_fn table[3] = { add_ten, times_three, no_pad };

void shield_trap_handler(void) {
    u32 cause = (SHIELD_STAT >> 16) & 0xFu;
    uart_puts("ShieldV trap: cause=");
    print_dec(cause);
    uart_puts(cause == 4u ? " (missing landing pad) at " : " at ");
    print_hex(FAULT_ACT);
    uart_puts("\r\n");
}

int main(void) {
    SHIELD_HANDLER = (u32)&shield_trap_entry;
    SHIELD_CTRL = SHIELD_ENABLE | SHIELD_TRAP_MODE | SHIELD_LPAD;

    u32 v = 5;
    v = table[0](v);                 // 15
    v = table[1](v);                 // 45
    int fails = report("fnptr", v, 45u, 0, 0);

    uart_puts("calling a function without a landing pad...\r\n");
    v = table[2](v);                 // must trap here
    uart_puts("no_pad ran: landing-pad check did not fire\r\n");
    return fails + 1;
}
