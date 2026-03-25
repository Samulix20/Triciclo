#ifndef CSR_H
#define CSR_H

#include <rvtarget.h>
#include "types.h"

// mcause values
#define MCAUSE_MISALIGNED_FETCH      0x0
#define MCAUSE_FETCH_ACCESS          0x1
#define MCAUSE_ILLEGAL_INSTRUCTION   0x2
#define MCAUSE_BREAKPOINT            0x3
#define MCAUSE_MISALIGNED_LOAD       0x4
#define MCAUSE_LOAD_ACCESS           0x5
#define MCAUSE_MISALIGNED_STORE      0x6
#define MCAUSE_STORE_ACCESS          0x7
#define MCAUSE_USER_ECALL            0x8
#define MCAUSE_SUPERVISOR_ECALL      0x9
#define MCAUSE_HYPERVISOR_ECALL      0xa
#define MCAUSE_MACHINE_ECALL         0xb
#define MCAUSE_FETCH_PAGE_FAULT      0xc
#define MCAUSE_LOAD_PAGE_FAULT       0xd
#define MCAUSE_STORE_PAGE_FAULT      0xf

#define MCAUSE_SOFT_IRQ              0x80000003
#define MCAUSE_TIMER_IRQ             0x80000007
#define MCAUSE_MACHINE_EXT_IRQ       0x8000000B

// FUNCTIONS IMPLEMENTED HERE FOR INLINING

__attribute__((always_inline))
inline u32 read_mcause() {
    u32 mcause;
    asm volatile("csrr %0, mcause" : "=r" (mcause));
    return mcause;
}

__attribute__((always_inline))
inline u32 read_mscratch() {
    u32 mscratch;
    asm volatile("csrr %0, mscratch" : "=r" (mscratch));
    return mscratch;
}

#define MSI_BIT (1 << 3)
#define MTI_BIT (1 << 7)
#define MEI_BIT (1 << 11)

// Bitmask set mie
__attribute__((always_inline))
inline void set_mie(u32 mask) {
    asm volatile("csrs mie, %0" :: "r" (mask));
}

// Bitmask clear mie
__attribute__((always_inline))
inline void clear_mie(u32 mask) {
    asm volatile("csrc mie, %0" :: "r" (mask));
}

// mstatus mie bit
#define MSTATUS_MIE (1 << 3)

// Bitmask set mstatus
__attribute__((always_inline))
inline void set_mstatus(u32 mask) {
    asm volatile("csrs mstatus, %0" :: "r" (mask));
}

// Bitmask clear mstatus
__attribute__((always_inline))
inline void clear_mstatus(u32 mask) {
    asm volatile("csrc mstatus, %0" :: "r" (mask));
}

__attribute__((always_inline))
inline u32 read_mstatus() {
    u32 mstatus;
    asm volatile("csrr %0, mstatus" : "=r" (mstatus));
    return mstatus;
}

__attribute__((always_inline))
inline u32 read_mepc() {
    u32 mepc;
    asm volatile("csrr %0, mepc" : "=r" (mepc));
    return mepc;
}

__attribute__((always_inline))
inline void write_mepc(u32 value) {
    asm volatile ("csrw mepc, %0" :: "r" (value));
}

// mcountinhibit bits
#define MCYCLE_BIT      (1)
#define MINSTRET_BIT    (1 << 2)

__attribute__((always_inline))
inline void set_mcountinhibit(u32 mask) {
    asm volatile("csrs mcountinhibit, %0" :: "r" (mask));
}

__attribute__((always_inline))
inline void clear_mcountinhibit(u32 mask) {
    asm volatile("csrc mcountinhibit, %0" :: "r" (mask));
}

// Utility functions for disable/enable the hw counters
// 2 cycles overhead

__attribute__((always_inline))
inline void disable_hw_counters() {
    asm volatile(
        "li x31, 5\n"
        "csrs mcountinhibit, x31"
        ::: "x31"
    );
}

__attribute__((always_inline))
inline void enable_hw_counters() {
    asm volatile(
        "li x31, 5\n"
        "csrc mcountinhibit, x31"
        ::: "x31"
    );
}

__attribute__((always_inline))
inline u64 read_mcycle() {
    u32 cl, ch;

    asm volatile(
        "csrr %0, mcycle\n"
        "csrr %1, mcycleh" 
        : "=r" (cl), "=r" (ch)
    );

    return ((u64) ch << 32) | cl;
}

__attribute__((always_inline))
inline u64 read_instret() {
    u32 il, ih;

    asm volatile(
        "csrr %0, minstret\n"
        "csrr %1, minstreth"
        : "=r" (il), "=r" (ih)
    );

    return ((u64) ih << 32) | il;
}

__attribute__((always_inline))
inline void read_hw_counters(u64* cycles, u64* instr) {
    u32 cl, ch, il, ih;

    asm volatile(
        "csrr %0, mcycle\n"
        "csrr %1, mcycleh" 
        : "=r" (cl), "=r" (ch)
    );
    asm volatile(
        "csrr %0, minstret\n"
        "csrr %1, minstreth"
        : "=r" (il), "=r" (ih)
    );

    *cycles = ((u64) ch << 32) | cl;
    *instr = ((u64) ih << 32) | il;
}

#endif
