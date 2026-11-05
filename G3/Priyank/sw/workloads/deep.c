// deep.c - call depth at the shadow-stack limit (risk "legal call depth > 32")
// Owner: Priyank (G3)
//
// The shadow stack holds 32 return addresses. crt0's call to main() uses one,
// so main() can nest NEST more calls. Built two ways (scripts/build_sw.py):
//   deep      NEST = 31 -> 32 entries in use, exactly full: must run with no alarm
//   deep_over NEST = 32 -> the 33rd call does not fit: ShieldV reports an
//             overflow and stops the core (fail-safe, by design), so a program
//             deeper than 32 calls cannot run with protection on.
#include "../lib/rt.h"

#ifndef NEST
#define NEST 31
#endif

static u32 __attribute__((noinline)) down(u32 n) {
    if (n == 0) return 0;
    return down(n - 1) + 1;         // +1 after the call keeps this a real call, not a jump
}

int main(void) {
    u32 c0 = read_cycles(), i0 = read_instret();
    u32 r = down(NEST - 1);         // main -> down(NEST-1) ... down(0): NEST calls
    u32 c = read_cycles() - c0, i = read_instret() - i0;
    return report("deep", r, NEST - 1, c, i);
}
