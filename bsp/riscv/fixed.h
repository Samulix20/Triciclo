#include "types.h"

// Implemented as macros to be more generic

#define MULFIX(a, b, scale) \
    ((i32) (((int64) ((a) * (b))) >> (scale)))

#define DIVFIX(a, b, scale) \
    ((i32) ((((int64) (a)) << (scale)) / (b)))

i32 log2fix(i32 x, const u8 scale);
i32 logfix(i32 x, const u8 scale);
