// matmul.c - 8x8 matrix multiply (workload 5, uses MUL)
// Owner: Priyank (G3)
#include "../lib/rt.h"

#define N 8
static u32 A[N][N], B[N][N], C[N][N];

static void __attribute__((noinline)) matmul(void) {
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            u32 s = 0;
            for (int k = 0; k < N; k++) s += A[i][k] * B[k][j];
            C[i][j] = s;
        }
}

int main(void) {
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            A[i][j] = (u32)(i * 3 + j * 5 + 1) & 0xFFu;
            B[i][j] = (u32)(i * 7 + j * 2 + 3) & 0xFFu;
        }
    u32 c0 = read_cycles(), i0 = read_instret();
    matmul();
    u32 c = read_cycles() - c0, i = read_instret() - i0;
    u32 s = 0;
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) s = s * 31u + C[i][j];
    return report("matmul", s, 2088526336u, c, i);
}
