// timing1.c - a short program made for timing-diagram Scenario 1
// Owner: Priyank (G3), used by Laxmidhar's timing diagrams
//
// In a window of ~66 cycles it shows everything the report must explain:
// nested calls (shadow-stack pushes), returns (pops), forwarding, a taken
// branch (flush), a load used right away, and a 34-cycle DIV stall.
#include "../lib/rt.h"

static volatile u32 divisor = 3;

static u32 __attribute__((noinline)) step(u32 n) {
    if (n == 0) return 0;                 // branch: taken at the bottom of the recursion
    u32 r = step(n - 1);                  // nested call (push) ... and its return (pop)
    u32 d = divisor;                      // load, used right away (forwarding)
    return r + n / d;                     // DIV: the pipeline stalls ~34 cycles
}

int main(void) {
    u32 r = step(2);                      // 2/3 + 1/3 + 0 = 0
    return report("timing1", r, 0u, 0, 0);
}
