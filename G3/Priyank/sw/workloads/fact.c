// fact.c - recursive factorial (workload 2, uses MUL)
// Owner: Priyank (G3)
#include "../lib/rt.h"

static u32 __attribute__((noinline)) fact(u32 n) {
    if (n <= 1) return 1;
    return n * fact(n - 1);
}

int main(void) {
    u32 c0 = read_cycles(), i0 = read_instret();
    u32 r = fact(12);
    u32 c = read_cycles() - c0, i = read_instret() - i0;
    return report("fact(12)", r, 479001600u, c, i);
}
