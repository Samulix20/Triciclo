
#include <stdio.h>
#include <stdlib.h>

#include <riscv/types.h>
#include <rvtarget.h>

int main() {

    for (u32 i = 0; i < 4; i++) {
        u32 v = i + 1;
        AXI_REGS[i] = v;
        if (AXI_REGS[i] != v) {
            printf("Missmatch %u \n", v);
            exit(v);
        }
    }

    printf("AXI working!\n");
    return 0;
}
