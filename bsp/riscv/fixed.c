#include <riscv/fixed.h>
#include <riscv/types.h>

#include <limits.h>

i32 log2fix(i32 x, const u8 scale) {

    // log(0) error, returns min value
    if (x == 0) return INT_MIN;

    i32 y = 0;
    i32 b = 1 << (scale - 1); // 0.5 in scale

    const i32 f1 = 1 << scale;
    const i32 f2 = 2 << scale;

    // Integer part
    while(x < f1) {
        x <<= 1; // mul 2
        y -= f1;
    }
    while (x >= f2) {
        x >>= 1; // div 2
        y += f1;
    }

    // Decimal part
    for(u8 i = 0; i < scale; i++) {
        x = (x * x) >> scale;
        if (x >= f2) {
            x >>= 1; // div 2
            y += b;
        }
        b >>= 1; // div 2
    }

    return y;
}

const i32 log2e_f28 = 387270501;

// TODO implement this function
i32 logfix(i32 x, const u8 scale) {
    (void) x;
    (void) scale;
    return 0;
}
