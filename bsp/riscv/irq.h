#ifndef IRQ_H
#define IRQ_H

#include <rvtarget.h>

#include "types.h"

// mtimer irq handler
void _mtimer_irq();

// mtimer set interrupt period in ticks
void set_mtimer_period(u64 p);

// Set callback funtion pointer
void set_mtimer_callback(void (*callback)());

// machine external interrupt handler
void _mei_irq();

// Set callback function pointer
void set_mei_callback(void (*callback)());

// machine soft interrupt handler
void _msi_irq();

// Set callback function pointer
void set_msi_callback(void (*callback)());

#endif
