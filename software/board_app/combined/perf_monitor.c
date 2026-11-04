/* Performance monitor MMIO register transactions and atomic snapshot collection. */
#include "perf_monitor.h"

/* Volatile access is required: these addresses are hardware registers, not RAM. */
#define PERF_REG(offset) (*(volatile uint32_t *)(PERF_MMIO_BASE + (offset)))

#define PERF_ID             0x000u
#define PERF_CONTROL        0x00cu
#define PERF_STATUS         0x010u
#define PERF_SNAPSHOT_ID    0x014u
#define PERF_COUNTER_INDEX  0x018u
#define PERF_COUNTER_LO     0x01cu
#define PERF_COUNTER_HI     0x020u
#define PERF_OVERFLOW_LO    0x024u
#define PERF_COUNTER_COUNT  0x02cu

#define PERF_CONTROL_START  1u
#define PERF_CONTROL_STOP   2u
#define PERF_STATUS_MARKER  (1u << 0)
#define PERF_STATUS_ACTIVE  (1u << 1)
#define PERF_STATUS_VALID   (1u << 2)

volatile uint32_t perf_capture_state;
volatile uint32_t perf_device_signature;
volatile uint32_t perf_supported_counter_count;
volatile uint32_t perf_capture_sequence;
volatile uint64_t perf_measured_cycles;
volatile uint64_t perf_retired_instructions;
volatile uint64_t perf_counter_values[PERF_MMIO_COUNTER_COUNT];
volatile uint32_t perf_counter_overflow;

/** Order CPU memory operations around an MMIO command or indexed counter read. */
static inline void perf_device_fence(void) {
    __asm__ volatile ("fence iorw, iorw" ::: "memory");
}

/** Select one frozen counter and combine its low/high 32-bit register pair. */
static uint64_t perf_read_indexed_counter(uint32_t counter_index) {
    uint32_t low;
    uint32_t high;
    PERF_REG(PERF_COUNTER_INDEX) = counter_index;
    perf_device_fence();
    low = PERF_REG(PERF_COUNTER_LO);
    high = PERF_REG(PERF_COUNTER_HI);
    return ((uint64_t)high << 32) | low;
}

/** Verify the peripheral identity, then arm the benchmark measurement interval. */
int perf_capture_begin(void) {
    perf_capture_state = PERF_CLIENT_NOT_RUN;
    perf_device_signature = PERF_REG(PERF_ID);
    perf_supported_counter_count = PERF_REG(PERF_COUNTER_COUNT);
    if ((perf_device_signature != PERF_MMIO_ID_VALUE) ||
        (perf_supported_counter_count != PERF_MMIO_COUNTER_COUNT)) {
        perf_capture_state = PERF_CLIENT_BAD_ID;
        return 0;
    }

    PERF_REG(PERF_CONTROL) = PERF_CONTROL_START;
    perf_device_fence();
    if ((PERF_REG(PERF_STATUS) & PERF_STATUS_ACTIVE) == 0u) {
        perf_capture_state = PERF_CLIENT_BAD_START;
        return 0;
    }
    return 1;
}

/**
 * Stop the interval and collect the frozen counter bank. The valid poll covers
 * the hardware marker falling-edge latency, so no counter is read mid-update.
 */
int perf_capture_finish(void) {
    uint32_t status;
    uint32_t poll_attempt;
    uint32_t counter_index;
    PERF_REG(PERF_CONTROL) = PERF_CONTROL_STOP;
    perf_device_fence();


    status = 0u;
    for (poll_attempt = 0u; poll_attempt < 32u; ++poll_attempt) {
        status = PERF_REG(PERF_STATUS);
        if (((status & PERF_STATUS_ACTIVE) == 0u) &&
            ((status & PERF_STATUS_VALID) != 0u)) {
            break;
        }
    }
    if (((status & PERF_STATUS_ACTIVE) != 0u) ||
        ((status & PERF_STATUS_VALID) == 0u)) {
        perf_capture_state = PERF_CLIENT_BAD_STOP;
        return 0;
    }

    perf_capture_sequence = PERF_REG(PERF_SNAPSHOT_ID);
    for (counter_index = 0u; counter_index < PERF_MMIO_COUNTER_COUNT; ++counter_index) {
        perf_counter_values[counter_index] = perf_read_indexed_counter(counter_index);
    }
    perf_counter_overflow = PERF_REG(PERF_OVERFLOW_LO);
    perf_measured_cycles = perf_counter_values[0];
    perf_retired_instructions = perf_counter_values[1];
    if ((perf_capture_sequence == 0u) ||
        (perf_measured_cycles == 0u) || (perf_retired_instructions == 0u) ||
        (perf_retired_instructions > perf_measured_cycles)) {
        perf_capture_state = PERF_CLIENT_BAD_DATA;
        return 0;
    }
    perf_capture_state = PERF_CLIENT_PASS;
    return 1;
}
