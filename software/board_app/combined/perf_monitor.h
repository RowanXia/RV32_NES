/*
 * MMIO performance-monitor client contract.  perf_capture_begin() resets and
 * starts a hardware snapshot; perf_capture_finish() stops it and exports all
 * counters below.  The values are valid only when perf_capture_state is PASS.
 */
#ifndef PERF_MONITOR_H
#define PERF_MONITOR_H

#include <stdint.h>

#define PERF_MMIO_BASE          0x30000000u
#define PERF_MMIO_ID_VALUE      0x50455246u
#define PERF_MMIO_COUNTER_COUNT 31u

#define PERF_CLIENT_NOT_RUN     0u
#define PERF_CLIENT_PASS        1u
#define PERF_CLIENT_BAD_ID      2u
#define PERF_CLIENT_BAD_START   3u
#define PERF_CLIENT_BAD_STOP    4u
#define PERF_CLIENT_BAD_DATA    5u

extern volatile uint32_t perf_capture_state;
extern volatile uint32_t perf_device_signature;
extern volatile uint32_t perf_supported_counter_count;
extern volatile uint32_t perf_capture_sequence;
extern volatile uint64_t perf_measured_cycles;
extern volatile uint64_t perf_retired_instructions;
extern volatile uint64_t perf_counter_values[PERF_MMIO_COUNTER_COUNT];
extern volatile uint32_t perf_counter_overflow;

/** Start a fresh hardware counter interval; zero means device/signature failure. */
int perf_capture_begin(void);
/** Stop, validate and copy the atomic hardware snapshot; zero means failure. */
int perf_capture_finish(void);

#endif
