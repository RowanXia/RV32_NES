/* Standalone CoreMark port used by the performance-marker test configuration. */
#include "coremark.h"

#define GPIO_OUTPUT_VAL (*(volatile ee_u32 *)0x1006000cu)
#define PERF_MARKER_MASK 0x80000000u

volatile ee_u32 coremark_done;
volatile ee_u32 coremark_status;
volatile ee_u32 coremark_cycles;
volatile ee_s32 seed1_volatile = 0;
volatile ee_s32 seed2_volatile = 0;
volatile ee_s32 seed3_volatile = 0x66;
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;
ee_u32 default_num_contexts = 1;
static CORETIMETYPE start_ticks;
static CORETIMETYPE stop_ticks;

static ee_u32 read_mcycle(void) {
    ee_u32 value;
    __asm__ volatile ("csrr %0, mcycle" : "=r" (value));
    return value;
}

/** Drive GPIO bit 31 around the measured interval for waveform correlation. */
static void set_perf_marker(ee_u32 enabled) {
    ee_u32 value = GPIO_OUTPUT_VAL;
    if (enabled) value |= PERF_MARKER_MASK;
    else value &= ~PERF_MARKER_MASK;
    GPIO_OUTPUT_VAL = value;
    __asm__ volatile ("fence iorw, iorw" ::: "memory");
}

static int contains_error(const char *text) {
    const char key[] = "ERROR";
    int index;
    while (*text != '\0') {
        for (index = 0; key[index] != '\0'; index++)
            if (text[index] != key[index]) break;
        if (key[index] == '\0') return 1;
        text++;
    }
    return 0;
}

static int starts_with_correct(const char *text) {
    const char key[] = "Correct operation validated";
    int index;
    for (index = 0; key[index] != '\0'; index++)
        if (text[index] != key[index]) return 0;
    return 1;
}

int ee_printf(const char *format, ...) {
    if (contains_error(format)) coremark_status = 0xfffffff0u;
    if (starts_with_correct(format)) coremark_status = 1u;
    return 0;
}

void start_time(void) {
    set_perf_marker(1u);
    start_ticks = read_mcycle();
}

void stop_time(void) {
    stop_ticks = read_mcycle();
    set_perf_marker(0u);
}

CORE_TICKS get_time(void) { return stop_ticks - start_ticks; }
secs_ret time_in_secs(CORE_TICKS ticks) { return ticks / 1000000u; }

void portable_init(core_portable *portable, int *argc, char *argv[]) {
    (void)argc; (void)argv;
    coremark_done = 0u;
    coremark_status = 0u;
    coremark_cycles = 0u;
    set_perf_marker(0u);
    portable->portable_id = 1u;
}

void portable_fini(core_portable *portable) {
    coremark_cycles = get_time();
    portable->portable_id = 0u;
    coremark_done = 0xc0de600du;
}
