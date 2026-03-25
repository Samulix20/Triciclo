#include <riscv/profiler.h>
#include <riscv/csr.h>

u64 counters[NUM_PROFILER_COUNTERS] = {
    0
};
u64 counters_starts[NUM_PROFILER_COUNTERS] = {
    0
};

void _start_internal_counter(const u8 id) {
    // Error counter does not exist
    if (id >= NUM_PROFILER_COUNTERS) return;

    counters_starts[id] = read_mcycle();
}

void _stop_internal_counter(const u8 id) {
    // Error counter does not exist
    if (id >= NUM_PROFILER_COUNTERS) return;

    // Only required at stop because those are counted after the start
    // -2 overhead cycles of disabling the hw counter
    counters[id] += read_mcycle() - 2 - counters_starts[id];
}

u64 get_internal_counter(const u8 id) {
    // Error counter does not exist
    if (id >= NUM_PROFILER_COUNTERS) return 0;

    return counters[id];
}

void reset_internal_counter(const u8 id) {
    // Error counter does not exist
    if (id >= NUM_PROFILER_COUNTERS) return;

    counters[id] = 0;
}

void start_external_profiler(const u8 id) {
    PROFILER_COUNTER_START = id;
}

void stop_external_profiler(const u8 id) {
    PROFILER_COUNTER_STOP = id;
}


