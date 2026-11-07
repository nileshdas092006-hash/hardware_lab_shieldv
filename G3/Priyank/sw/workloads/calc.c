// calc.c - choose the function and its value with the board's switches
// Owner: Nilesh (G2), demo program
//
// One bitstream, no rebuild: set the switches, press CPU_RESET, read the answer.
//
//   SW15..SW13  which function (0 to 7, see the table below)
//   SW12..SW1   the value n, in binary (0 to 4095)
//   SW0         ShieldV protection, as in every other program
//
// The answer goes to the UART in decimal and to the 8-digit display in hex.
// scripts/calc.py works out the switch positions and checks this program's
// answers against its own Python copy of each function.
#include "../lib/rt.h"

u32 custom(u32 n);                              // calc_custom.c: the one to edit

// ---- 0: fib, recursive ----
static u32 __attribute__((noinline)) fib(u32 n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

// ---- 1: fact, recursive ----
static u32 __attribute__((noinline)) fact(u32 n) {
    if (n <= 1) return 1;
    return n * fact(n - 1);
}

// ---- 2: quicksort n pseudo-random numbers, result is a checksum of the sorted list ----
#define MAX_SORT 256
static u32 arr[MAX_SORT];

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

static u32 run_qsort(u32 n) {
    u32 x = 12345u, sum = 0;
    for (u32 k = 0; k < n; k++) { x = x * 1103515245u + 12345u; arr[k] = (x >> 16) & 0x7FFFu; }
    quicksort(arr, 0, (int)n - 1);
    for (u32 k = 0; k < n; k++) {
        sum += arr[k] * (k + 1u);
        if (k && arr[k - 1] > arr[k]) uart_puts("not sorted!\r\n");
    }
    return sum;
}

// ---- 3: binary search tree of n keys, result is a checksum of the in-order walk ----
#define MAX_TREE 256
typedef struct node { u32 key; struct node *left, *right; } node;
static node pool[MAX_TREE];
static u32 used, checksum;

static node * __attribute__((noinline)) insert(node *t, u32 key) {
    if (!t) {
        node *p = &pool[used++];
        p->key = key; p->left = 0; p->right = 0;
        return p;
    }
    if (key < t->key)      t->left  = insert(t->left, key);
    else if (key > t->key) t->right = insert(t->right, key);
    return t;
}

static void __attribute__((noinline)) inorder(node *t) {
    if (!t) return;
    inorder(t->left);
    checksum = checksum * 33u + t->key;
    inorder(t->right);
}

static u32 run_tree(u32 n) {
    node *root = 0;
    u32 x = 777u;
    while (used < n) {
        x = x * 1103515245u + 12345u;
        root = insert(root, (x >> 16) & 0x3FFu);
    }
    inorder(root);
    return checksum;
}

// ---- 4: multiply two n x n matrices, result is a checksum of the product ----
#define MAX_MAT 12
static u32 A[MAX_MAT][MAX_MAT], B[MAX_MAT][MAX_MAT], C[MAX_MAT][MAX_MAT];

static u32 run_matmul(u32 n) {
    u32 s = 0;
    for (u32 i = 0; i < n; i++)
        for (u32 j = 0; j < n; j++) {
            A[i][j] = (i * 3u + j * 5u + 1u) & 0xFFu;
            B[i][j] = (i * 7u + j * 2u + 3u) & 0xFFu;
        }
    for (u32 i = 0; i < n; i++)
        for (u32 j = 0; j < n; j++) {
            u32 t = 0;
            for (u32 k = 0; k < n; k++) t += A[i][k] * B[k][j];
            C[i][j] = t;
        }
    for (u32 i = 0; i < n; i++)
        for (u32 j = 0; j < n; j++) s = s * 31u + C[i][j];
    return s;
}

// ---- 5: how many primes are below n ----
static int __attribute__((noinline)) is_prime(u32 v) {
    if (v < 2) return 0;
    for (u32 d = 2; d * d <= v; d++)
        if (v % d == 0) return 0;
    return 1;
}

static u32 run_primes(u32 n) {
    u32 count = 0;
    for (u32 v = 2; v < n; v++) count += (u32)is_prime(v);
    return count;
}

// ---- 6: nest n calls, to show the shadow stack's limit ----
static volatile u32 depth_seen;

static u32 __attribute__((noinline)) nest(u32 n) {
    u32 r = n ? nest(n - 1) + 1u : 0u;
    depth_seen = r;                             // stops the compiler turning this into a loop
    return r;
}

// name and largest value of each function; values above it are lowered to it
// (47 and 12: fib and fact outgrow 32 bits above these; the others: RAM)
static const char *const NAMES[8] = {"fib", "fact", "qsort", "bintree", "matmul", "primes", "nest", "custom"};
static const u32 LIMITS[8] = {47, 12, MAX_SORT, MAX_TREE, MAX_MAT, 4095, 400, 4095};

int main(void) {
    u32 sw = read_switches();
    u32 fn = (sw >> 13) & 7u;
    u32 n  = (sw >> 1) & 0xFFFu;

    uart_puts("\r\nShieldV calculator. Protection is ");
    uart_puts((sw & 1u) ? "ON\r\n" : "OFF\r\n");
    uart_puts(CORE_ID_REG ? "Core: out-of-order\r\n" : "Core: in-order\r\n");
    if (n > LIMITS[fn]) {
        uart_puts("value lowered to the largest allowed: ");
        print_dec(LIMITS[fn]);
        uart_puts("\r\n");
        n = LIMITS[fn];
    }
    uart_puts(NAMES[fn]); uart_putc('('); print_dec(n); uart_puts(") ...\r\n");

    u32 c0 = read_cycles(), i0 = read_instret(), r = 0;
    switch (fn) {
        case 0:  r = fib(n);        break;
        case 1:  r = fact(n);       break;
        case 2:  r = run_qsort(n);  break;
        case 3:  r = run_tree(n);   break;
        case 4:  r = run_matmul(n); break;
        case 5:  r = run_primes(n); break;
        case 6:  r = nest(n);       break;
        default: r = custom(n);     break;
    }
    u32 c = read_cycles() - c0, i = read_instret() - i0;

    uart_puts("answer = "); print_dec(r);
    uart_puts("  (display shows "); print_hex(r); uart_puts(")\r\n");
    uart_puts("cycles="); print_dec(c); uart_puts(" instret="); print_dec(i); uart_puts("\r\n");
    set_seg7(r);
    set_leds(0x00FFu);                          // finished
    return 0;
}
