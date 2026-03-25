#include "riscv/irq.h"
#include <riscv/types.h>
#include <riscv/csr.h>

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

const u32 max_ticks = 500;
u32 counter = 0;

void serial_mei() {
    i32 bytes;
    u8 buff [20];

    counter = 0;

    bytes = read(STDIN_FILENO, buff, 20);
    for (i32 i = 0; i < bytes; i++) {
        u8 c = buff[i];

        // Backspace key behaviour
        if (c == 0x7f) {
            putc('\b', stdout);
            putc(' ', stdout);
            putc('\b', stdout);
        }
        else {
            putc(c, stdout);
        }
    }

    fflush(stdout);
}

void tick() {
    counter++;
    if (counter == max_ticks) {
        printf("\nTime's up! Bye!\n");
        exit(0);
    }
}

int main() {
    printf("Echo starts!\n");

    set_mei_callback(serial_mei);

    set_mtimer_period(5000);
    set_mtimer_callback(tick);

    // Enable general interrupts
    set_mstatus(MSTATUS_MIE);
    // Enable external and timer interrupts
    set_mie(MEI_BIT | MTI_BIT);

    while(1);
}
