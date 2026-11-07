// calc_custom.c - function 7 of calc.c: the place to write a new function
// Owner: Nilesh (G2), demo program
//
// Change the body of custom() to anything you like. Then:
//   python scripts/calc.py custom 10          try it in simulation (about 10 seconds)
//   python scripts/fpga.py build calc --ooo   put it on the board (about 7 minutes)
#include "../lib/rt.h"

// the example: 1 + 2 + ... + n
u32 custom(u32 n) {
    u32 sum = 0;
    for (u32 i = 1; i <= n; i++) sum += i;
    return sum;
}
