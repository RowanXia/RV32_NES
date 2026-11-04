/*
 * Production boot sequence: validate CoreMark, capture CPU counters, then
 * hand control to the NES menu.  The boot-control register is persistent
 * across the warm handoff, so a return path can enter the NES side directly
 * without rerunning the benchmark.
 */
#include "graphics.h"
#include "uart.h"
#include "nes_menu.h"
#include "sd_card.h"
#include "benchmark_result.h"
#include "perf_monitor.h"
#include "uart_report.h"

#ifndef COMBINED_ENABLE_UART_REPORT
#define COMBINED_ENABLE_UART_REPORT 0
#endif
#ifndef COMBINED_CPU_HZ
#define COMBINED_CPU_HZ 100000000ull
#endif

extern int benchmark_coremark_entry(void);

/** Read a coherent 64-bit mcycle value on RV32, where the CSR is split in two. */
static unsigned long long read_board_cycle_counter(void) {
    unsigned int high0, low, high1;
    do {
        __asm__ volatile ("csrr %0, mcycleh" : "=r"(high0));
        __asm__ volatile ("csrr %0, mcycle" : "=r"(low));
        __asm__ volatile ("csrr %0, mcycleh" : "=r"(high1));
    } while (high0 != high1);
    return ((unsigned long long)high0 << 32) | low;
}

/**
 * Publish visible boot progress and select the CoreMark or NES hardware mode.
 *
 * @param led_pattern Low eight GPIO bits displayed as progress/error state.
 * @param enable_nes_mode Non-zero enables the NES hardware handoff (boot bit 8).
 */
static void board_set_boot_mode(unsigned int led_pattern,
                                unsigned int enable_nes_mode) {


    GPIO->output_en = 0xffu;
    GPIO->output_val = led_pattern & 0xffu;
    CTRLREG->boot_control = enable_nes_mode ? BIT8 : 0u;
}

/**
 * Firmware entry point.
 *
 * A warm handoff (boot-control bit 9) skips measurement and returns directly
 * to the menu. A cold boot starts the performance monitor before CoreMark,
 * rejects an invalid benchmark or counter snapshot, then exposes the NES menu.
 */
int main(void) {
    unsigned int boot_status_leds = BIT0;
    int performance_snapshot_valid;


    /* Resume the NES menu after a warm reset. */
    if (CTRLREG->boot_control & BIT9) {
        /* Switch to game mode. */
        board_set_boot_mode(0u, 1u);
        /* Initialise and run the menu. */
        nes_menu_init();
        nes_menu_loop();
        nes_game_loop();
        return 0;
    }


    /* Show cold-start progress. */
    board_set_boot_mode(boot_status_leds, 0u);


    /* Record entry into the performance-measurement stage. */
    boot_status_leds |= BIT1;
    board_set_boot_mode(boot_status_leds, 0u);
    /* Start the measurement counters, then begin CoreMark. */
    if (!perf_capture_begin()) {
        /* Record the failure state and halt. */
        board_set_boot_mode(boot_status_leds | BIT7, 0u);
        for (;;) { }
    }
    /* Run the CoreMark benchmark. */
    (void)benchmark_coremark_entry();
    /* Stop capture and read the performance snapshot. */
    performance_snapshot_valid = perf_capture_finish();


    /* Block game handoff if CoreMark validation fails. */
    if ((benchmark_done_flag != COMBINED_COREMARK_DONE_MAGIC) ||
        (benchmark_check_state != COMBINED_VALIDATION_PASS) ||
        (benchmark_result_record.validation != COMBINED_VALIDATION_PASS)) {
        board_set_boot_mode(boot_status_leds | BIT7, 0u);
        for (;;) { }
    }
    /* Record successful entry into the NES stage. */
    boot_status_leds |= BIT2;
    board_set_boot_mode(boot_status_leds, 0u);

    /* A benchmark pass without a valid performance snapshot is still a test failure. */
    if (!performance_snapshot_valid || (perf_capture_state != PERF_CLIENT_PASS)) {
        board_set_boot_mode(boot_status_leds | BIT7, 0u);
        for (;;) { }
    }
    boot_status_leds |= BIT3;
    board_set_boot_mode(boot_status_leds, 0u);

#if COMBINED_ENABLE_UART_REPORT
    /* The optional host protocol acknowledges the exact counter snapshot CRC. */
    for (;;) {
        unsigned int report_crc;
        if (!uart_report_wait_request(5ull * COMBINED_CPU_HZ))
            continue;
        report_crc = uart_report_send_snapshot();
        boot_status_leds |= BIT4;
        board_set_boot_mode(boot_status_leds, 0u);
        if (uart_report_wait_ack(perf_capture_sequence, report_crc,
                                5ull * COMBINED_CPU_HZ))
            break;
    }
    boot_status_leds |= BIT5;
    board_set_boot_mode(boot_status_leds, 0u);
    boot_status_leds |= BIT6;
    board_set_boot_mode(boot_status_leds, 0u);
    {
        unsigned long long handoff_begin_cycle = read_board_cycle_counter();
        while ((read_board_cycle_counter() - handoff_begin_cycle) < COMBINED_CPU_HZ) { }
    }
    board_set_boot_mode(0u, 1u);
    uart_write_text("NES_READY\n");
#else
    board_set_boot_mode(0u, 1u);
#endif


    nes_menu_init();
    nes_menu_loop();
    nes_game_loop();

    return 0;
}
