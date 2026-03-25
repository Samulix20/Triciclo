#ifndef RV_DEBUG_H
#define RV_DEBUG_H

#include <riscv/types.h>
#include <rvtarget.h>

__attribute__((always_inline))
inline void debug_breakpoint() {
    DEBUG_REQ_REG = 1;
}

#endif