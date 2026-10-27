// fib.c - recursive Fibonacci (workload 1)
// Owner: Priyank (G3)
//
// Recursion means thousands of calls and returns, so this is the best test
// that ShieldV raises NO false alarms: every return must match its call.
// fib(18) calls fib 8361 times and nests 18 deep (the shadow stack holds 32).
#include "../lib/rt.h"

static u32 __attribute__((noinline)) fib(u32 n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    u32 c0 = read_cycles(), i0 = read_instret();
    u32 r = fib(18);
    u32 c = read_cycles() - c0, i = read_instret() - i0;
    return report("fib(18)", r, 2584u, c, i);
}
