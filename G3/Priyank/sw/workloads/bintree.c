// bintree.c - binary search tree: recursive insert + in-order traversal (workload 4)
// Owner: Priyank (G3)
#include "../lib/rt.h"

typedef struct node { u32 key; struct node *left, *right; } node;

static node pool[40];
static int used;
static u32 checksum, visited;

static node * __attribute__((noinline)) insert(node *t, u32 key, int *added) {
    if (!t) {
        node *n = &pool[used++];
        n->key = key; n->left = 0; n->right = 0;
        *added = 1;
        return n;
    }
    if (key < t->key)      t->left  = insert(t->left, key, added);
    else if (key > t->key) t->right = insert(t->right, key, added);
    return t;                                   // equal key: ignore duplicate
}

static void __attribute__((noinline)) inorder(node *t) {
    if (!t) return;
    inorder(t->left);
    checksum = checksum * 33u + t->key;
    visited++;
    inorder(t->right);
}

int main(void) {
    u32 c0 = read_cycles(), i0 = read_instret();
    node *root = 0;
    u32 x = 777u;
    int count = 0;
    while (count < 31) {
        x = x * 1103515245u + 12345u;
        int added = 0;
        root = insert(root, (x >> 16) & 0x3FFu, &added);
        count += added;
    }
    inorder(root);
    u32 c = read_cycles() - c0, i = read_instret() - i0;
    if (visited != 31u) uart_puts("wrong node count!\r\n");
    return report("bintree", checksum, 1267957422u, c, i);
}
