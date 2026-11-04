/* CoreMark timing, seed and result-capture port; keep the CoreMark API symbols stable. */
#include "coremark.h"
#include "benchmark_result.h"
#include <stdarg.h>

#ifndef COMBINED_CPU_HZ
#define COMBINED_CPU_HZ 100000000ull
#endif
#ifndef COMBINED_SEED3
#define COMBINED_SEED3 0x66
#endif

/* Exported result fields are consumed by main.c and optional UART telemetry. */
volatile benchmark_u32 benchmark_done_flag;
volatile benchmark_u32 benchmark_check_state;
volatile benchmark_u64 benchmark_cycle_count;
volatile benchmark_result_record_t benchmark_result_record;

volatile ee_s32 seed1_volatile = 0;
volatile ee_s32 seed2_volatile = 0;
volatile ee_s32 seed3_volatile = COMBINED_SEED3;
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;
ee_u32 default_num_contexts = 1;

static CORETIMETYPE benchmark_begin_tick;
static CORETIMETYPE benchmark_end_tick;
static ee_u32 benchmark_validation_seen;
static ee_u32 benchmark_error_seen;

/** Read mcycle without mixing the low half before a high-half rollover. */
static ee_u64 read_cycle_counter64(void) {
    ee_u32 high_before;
    ee_u32 low;
    ee_u32 high_after;
    do {
        __asm__ volatile ("csrr %0, mcycleh" : "=r" (high_before));
        __asm__ volatile ("csrr %0, mcycle" : "=r" (low));
        __asm__ volatile ("csrr %0, mcycleh" : "=r" (high_after));
    } while (high_before != high_after);
    return ((ee_u64)high_after << 32) | (ee_u64)low;
}

/** Compare a complete CoreMark status string without pulling in libc strcmp(). */
static int format_matches(const char *left, const char *right) {
    while ((*left != '\0') && (*left == *right)) {
        ++left;
        ++right;
    }
    return *left == *right;
}

/** Search CoreMark's text-only reporting channel for a validation keyword. */
static int format_contains(const char *text, const char *key) {
    int index;
    while (*text != '\0') {
        for (index = 0; key[index] != '\0'; ++index)
            if (text[index] != key[index]) break;
        if (key[index] == '\0') return 1;
        ++text;
    }
    return 0;
}


/* Parse CoreMark diagnostics into a fixed record without UART traffic in the timed interval. */
/**
 * CoreMark emits its verdict through ee_printf. There is no console in the
 * production image, so recognise the official text and record validation
 * state; formatting arguments are intentionally ignored.
 */
int ee_printf(const char *format, ...) {
    va_list arguments;
    va_start(arguments, format);

    if (format_matches(format, "CoreMark Size    : %lu\n")) {
        benchmark_result_record.coremark_size =
            (benchmark_u32)va_arg(arguments, unsigned long);
        benchmark_result_record.valid_mask |= COMBINED_FIELD_SIZE;
    } else if (format_matches(format, "Total ticks      : %lu\n")) {


        (void)va_arg(arguments, unsigned long);
    } else if (format_matches(format, "Total time (secs): %d\n")) {
        benchmark_result_record.seconds_floor = (benchmark_u32)va_arg(arguments, unsigned int);
        benchmark_result_record.valid_mask |= COMBINED_FIELD_SECONDS;
    } else if (format_matches(format, "Iterations       : %lu\n")) {
        benchmark_result_record.iterations =
            (benchmark_u32)va_arg(arguments, unsigned long);
        benchmark_result_record.valid_mask |= COMBINED_FIELD_ITERATIONS;
    } else if (format_matches(format, "seedcrc          : 0x%04x\n")) {
        benchmark_result_record.seedcrc = (benchmark_u32)va_arg(arguments, int) & 0xffffu;
        benchmark_result_record.valid_mask |= COMBINED_FIELD_SEEDCRC;
    } else if (format_matches(format, "[%d]crclist       : 0x%04x\n")) {
        (void)va_arg(arguments, int);
        benchmark_result_record.crclist = (benchmark_u32)va_arg(arguments, int) & 0xffffu;
        benchmark_result_record.valid_mask |= COMBINED_FIELD_CRCLIST;
    } else if (format_matches(format, "[%d]crcmatrix     : 0x%04x\n")) {
        (void)va_arg(arguments, int);
        benchmark_result_record.crcmatrix = (benchmark_u32)va_arg(arguments, int) & 0xffffu;
        benchmark_result_record.valid_mask |= COMBINED_FIELD_CRCMATRIX;
    } else if (format_matches(format, "[%d]crcstate      : 0x%04x\n")) {
        (void)va_arg(arguments, int);
        benchmark_result_record.crcstate = (benchmark_u32)va_arg(arguments, int) & 0xffffu;
        benchmark_result_record.valid_mask |= COMBINED_FIELD_CRCSTATE;
    } else if (format_matches(format, "[%d]crcfinal      : 0x%04x\n")) {
        (void)va_arg(arguments, int);
        benchmark_result_record.crcfinal = (benchmark_u32)va_arg(arguments, int) & 0xffffu;
        benchmark_result_record.valid_mask |= COMBINED_FIELD_CRCFINAL;
    } else if (format_matches(format,
               "Correct operation validated. See README.md for run and reporting rules.\n")) {
        benchmark_validation_seen = 1u;
        benchmark_result_record.valid_mask |= COMBINED_FIELD_VALIDATED;
    }

    if (format_contains(format, "ERROR") ||
        format_contains(format, "Errors detected") ||
        format_contains(format, "Cannot validate operation")) {
        benchmark_error_seen = 1u;
        benchmark_result_record.error_count++;
    }

    va_end(arguments);
    return 0;
}

/** Begin the interval reported by the standard CoreMark get_time() hook. */
void start_time(void) {
    benchmark_begin_tick = read_cycle_counter64();
}

/** Latch the end of the exact interval opened by start_time(). */
void stop_time(void) {
    benchmark_end_tick = read_cycle_counter64();
}

CORE_TICKS get_time(void) {
    return benchmark_end_tick - benchmark_begin_tick;
}

secs_ret time_in_secs(CORE_TICKS ticks) {
    return (secs_ret)(ticks / COMBINED_CPU_HZ);
}

/** Initialise the standard CoreMark port state before benchmark_coremark_entry(). */
void portable_init(core_portable *portable, int *argc, char *argv[]) {
    (void)argc;
    (void)argv;
    benchmark_done_flag = 0u;
    benchmark_check_state = COMBINED_VALIDATION_NOT_RUN;
    benchmark_cycle_count = 0ull;
    benchmark_result_record.magic = COMBINED_COREMARK_RESULT_MAGIC;
    benchmark_result_record.version = COMBINED_COREMARK_RESULT_VERSION;
    benchmark_result_record.valid_mask = 0u;
    benchmark_result_record.validation = COMBINED_VALIDATION_NOT_RUN;
    benchmark_result_record.error_count = 0u;
    benchmark_result_record.coremark_size = 0u;
    benchmark_result_record.iterations = 0u;
    benchmark_result_record.seconds_floor = 0u;
    benchmark_result_record.ticks_lo = 0u;
    benchmark_result_record.ticks_hi = 0u;
    benchmark_result_record.seedcrc = 0u;
    benchmark_result_record.crclist = 0u;
    benchmark_result_record.crcmatrix = 0u;
    benchmark_result_record.crcstate = 0u;
    benchmark_result_record.crcfinal = 0u;
    benchmark_validation_seen = 0u;
    benchmark_error_seen = 0u;
    portable->portable_id = 1u;
}

/** Publish validation fields after the benchmark has completed all CRC checks. */
void portable_fini(core_portable *portable) {
    ee_u64 ticks = get_time();
    ee_u32 fields;
    ee_u32 values_match;

    benchmark_cycle_count = ticks;
    benchmark_result_record.ticks_lo = (benchmark_u32)ticks;
    benchmark_result_record.ticks_hi = (benchmark_u32)(ticks >> 32);
    benchmark_result_record.valid_mask |= COMBINED_FIELD_TICKS;

    fields = benchmark_result_record.valid_mask;
    values_match =
        (benchmark_result_record.coremark_size == 666u) &&
        (benchmark_result_record.iterations == (benchmark_u32)ITERATIONS) &&
        (benchmark_result_record.seedcrc == 0xe9f5u) &&
        (benchmark_result_record.crclist == 0xe714u) &&
        (benchmark_result_record.crcmatrix == 0x1fd7u) &&
        (benchmark_result_record.crcstate == 0x8e3au);

    if (benchmark_validation_seen && !benchmark_error_seen && values_match &&
        ((fields & COMBINED_REQUIRED_FIELDS) == COMBINED_REQUIRED_FIELDS)) {
        benchmark_result_record.validation = COMBINED_VALIDATION_PASS;
        benchmark_check_state = COMBINED_VALIDATION_PASS;
    } else {
        benchmark_result_record.validation = COMBINED_VALIDATION_FAIL;
        benchmark_check_state = COMBINED_VALIDATION_FAIL;
    }

    __asm__ volatile ("fence rw, rw" ::: "memory");
    benchmark_done_flag = COMBINED_COREMARK_DONE_MAGIC;
    portable->portable_id = 0u;
}
