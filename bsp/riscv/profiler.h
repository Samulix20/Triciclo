#ifndef PROFILER_INTERNAL_H
#define PROFILER_INTERNAL_H

#include <rvtarget.h>
#include <riscv/csr.h>

// Profiler internal counters
#define NUM_PROFILER_COUNTERS 8

// Private real functions
void _start_internal_counter(const u8 id);
void _stop_internal_counter(const u8 id);

// Wrappers that disable/enable the hw counters

__attribute__((always_inline))
inline void start_internal_counter(const u8 id) {
    disable_hw_counters();
    _start_internal_counter(id);
    enable_hw_counters();
}

__attribute__((always_inline))
inline void stop_internal_counter(const u8 id) {
    disable_hw_counters();
    _stop_internal_counter(id);
    enable_hw_counters();
}

u64 get_internal_counter(const u8 id);

void reset_internal_counter(const u8 id);

void start_external_profiler(const u8 id);
void stop_external_profiler(const u8 id);

#endif
