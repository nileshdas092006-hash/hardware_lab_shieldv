// primes.c - prime count, GCD and division edge cases (workload 6, uses DIV/REM)
// Owner: Priyank (G3)
#include "../lib/rt.h"

static int __attribute__((noinline)) is_prime(u32 n) {
    if (n < 2) return 0;
    for (u32 d = 2; d * d <= n; d++)
        if (n % d == 0) return 0;               // REMU
    return 1;
}

static u32 __attribute__((noinline)) gcd(u32 a, u32 b) {
    return b ? gcd(b, a % b) : a;               // recursive, REMU
}

// volatile stops the compiler from working these out at compile time,
// so the real DIV/REM hardware is used
static volatile s32 vneg7 = -7, vtwo = 2, vzero = 0, vmin = (s32)0x80000000, vm1 = -1;

int main(void) {
    int fails = 0;
    u32 c0 = read_cycles(), i0 = read_instret();
    u32 count = 0;
    for (u32 n = 2; n < 1000; n++) count += (u32)is_prime(n);
    u32 c = read_cycles() - c0, i = read_instret() - i0;
    fails += report("primes<1000", count, 168u, c, i);
    fails += report("gcd(1071,462)", gcd(1071u, 462u), 21u, 0, 0);

    // RISC-V division rules (no exceptions, fixed answers)
    fails += report("-7/2",        (u32)(vneg7 / vtwo),  (u32)-3, 0, 0);
    fails += report("-7%2",        (u32)(vneg7 % vtwo),  (u32)-1, 0, 0);
    fails += report("x/0",         (u32)(vneg7 / vzero), 0xFFFFFFFFu, 0, 0);
    fails += report("x%0",         (u32)(vneg7 % vzero), (u32)-7, 0, 0);
    fails += report("INT_MIN/-1",  (u32)(vmin / vm1),    0x80000000u, 0, 0);
    fails += report("INT_MIN%-1",  (u32)(vmin % vm1),    0u, 0, 0);
    return fails;
}
