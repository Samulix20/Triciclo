#include <riscv/irq.h>
#include <riscv/csr.h>

#include <stdio.h>
#include <stdlib.h>

// Timer IRQ

static u64 period;

void (*mtimer_callback_fun_ptr)(void) = NULL;

void _mtimer_irq() {
    MTIMER_CMP = MTIMER_COUNTER + period;
    if (mtimer_callback_fun_ptr != NULL) {
        (*mtimer_callback_fun_ptr)();
    }
}

void set_mtimer_period(u64 p) {
    period = p;
    MTIMER_CMP = MTIMER_COUNTER + period;
}

void set_mtimer_callback(void (*callback)()) {
    mtimer_callback_fun_ptr = callback;
}

// External IRQ

void (*mei_callback_fun_ptr)(void) = NULL;

void _mei_irq() {
    if (mei_callback_fun_ptr == NULL) {
        printf("External interrupt w/o handler\n");
        exit(-1);
    } 
    else { 
        (*mei_callback_fun_ptr)();
    }
}

void set_mei_callback(void (*callback)()) {
    mei_callback_fun_ptr = callback;
}

// Software IRQ

void (*msi_callback_fun_ptr)(void) = NULL;

void _msi_irq() {
    if (msi_callback_fun_ptr == NULL) {
        printf("Software interrupt w/o handler\n");
        exit(-1);
    } 
    else { 
        (*msi_callback_fun_ptr)();
    } 
}

void set_msi_callback(void (*callback)()) {
    msi_callback_fun_ptr = callback;
}
