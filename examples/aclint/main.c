#include "rvtarget.h"
#include <riscv/csr.h>
#include <riscv/irq.h>

#include <stdlib.h>
#include <stdio.h>

volatile u8 finish = 0;
u32 counter = 0;

void tick() {
    counter++;
    if (counter == 10) {
        finish = 1;
        clear_mie(MTI_BIT);
    }
}

void first() {
    printf("First Soft IRQ received!\n");
    ACLINT_MSIP_REGS[0] = 0;
}

void second() {
    printf("Second soft IRQ received!\n");
    exit(0);
}

int main() {
    set_mtimer_period(5000);
    set_mtimer_callback(tick);

    // Enable general interrupts
    set_mstatus(MSTATUS_MIE);
    // Enable mtimer interrupts
    set_mie(MTI_BIT | MSI_BIT);

    while (!finish);
    printf("Number of ticks reached!\n");

    set_msi_callback(first);
    ACLINT_MSIP_REGS[0] = 1;

    set_msi_callback(second);
    ACLINT_MSIP_REGS[0] = 1;

    return 1;
}
