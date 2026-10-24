// qsort.c - recursive quicksort of 64 pseudo-random numbers (workload 3)
// Owner: Priyank (G3)
#include "../lib/rt.h"

#define N 64
static u32 arr[N];

static void __attribute__((noinline)) quicksort(u32 *a, int lo, int hi) {
    if (lo >= hi) return;
    u32 pivot = a[(lo + hi) / 2];
    int i = lo, j = hi;
    while (i <= j) {
        while (a[i] < pivot) i++;
        while (a[j] > pivot) j--;
        if (i <= j) { u32 t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
    }
    quicksort(a, lo, j);
    quicksort(a, i, hi);
}

int main(void) {
    u32 x = 12345u;
    for (int k = 0; k < N; k++) { x = x * 1103515245u + 12345u; arr[k] = (x >> 16) & 0x7FFFu; }

    u32 c0 = read_cycles(), i0 = read_instret();
    quicksort(arr, 0, N - 1);
    u32 c = read_cycles() - c0, i = read_instret() - i0;

    u32 sum = 0; int sorted = 1;
    for (int k = 0; k < N; k++) {
        sum += arr[k] * (u32)(k + 1);
        if (k && arr[k - 1] > arr[k]) sorted = 0;
    }
    if (!sorted) uart_puts("not sorted!\r\n");
    return report("qsort", sorted ? sum : 0u, 44251377u, c, i);
}
