#include <rvtarget.h>

.section .init
.globl __rv_init

__rv_init:
    li x1, 10
    li x3, 20
    add x2, x1, x3
    la x4, EXIT_STATUS_ADDR
    sw x1, (x4)
    nop 
    nop
    nop

_end: 
    j _end