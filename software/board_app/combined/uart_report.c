/* UART report framing, CRC32 encoding and host request/acknowledgment protocol. */
#include "uart_report.h"
#include "benchmark_result.h"
#include "perf_monitor.h"
#include "SOC_ADDR.h"

#ifndef COMBINED_CPU_HZ
#define COMBINED_CPU_HZ 100000000ull
#endif

#define UART_REPORT_FRAME_MAGIC 0x52505652u /* Little-endian bytes: R V P R. */
#define UART_REPORT_FRAME_TYPE  2u
#define UART_REPORT_FRAME_MAX   384u

/** Return coherent mcycle for timeout deadlines; see the matching CoreMark hook. */
static uint64_t uart_report_cycle_now(void) {
    uint32_t high0, low, high1;
    do {
        __asm__ volatile ("csrr %0, mcycleh" : "=r"(high0));
        __asm__ volatile ("csrr %0, mcycle" : "=r"(low));
        __asm__ volatile ("csrr %0, mcycleh" : "=r"(high1));
    } while (high0 != high1);
    return ((uint64_t)high0 << 32) | low;
}

/** Append a 16-bit value in the protocol's little-endian byte order. */
static void frame_append_u16(uint8_t *buffer, uint32_t *cursor, uint16_t value) {
    buffer[(*cursor)++] = (uint8_t)value;
    buffer[(*cursor)++] = (uint8_t)(value >> 8);
}

/** Append a 32-bit value in the protocol's little-endian byte order. */
static void frame_append_u32(uint8_t *buffer, uint32_t *cursor, uint32_t value) {
    uint32_t shift;
    for (shift = 0; shift < 32; shift += 8)
        buffer[(*cursor)++] = (uint8_t)(value >> shift);
}

/** Append a 64-bit value as two little-endian 32-bit protocol fields. */
static void frame_append_u64(uint8_t *buffer, uint32_t *cursor, uint64_t value) {
    frame_append_u32(buffer, cursor, (uint32_t)value);
    frame_append_u32(buffer, cursor, (uint32_t)(value >> 32));
}

/** Calculate the wire-format CRC32 over the bytes preceding the CRC field. */
static uint32_t frame_calculate_crc32(const uint8_t *buffer, uint32_t length) {
    uint32_t frame_crc = 0xffffffffu;
    uint32_t i, bit;
    for (i = 0; i < length; ++i) {
        frame_crc ^= buffer[i];
        for (bit = 0; bit < 8; ++bit)
            frame_crc = (frame_crc >> 1) ^ (0xedb88320u & (0u - (frame_crc & 1u)));
    }
    return ~frame_crc;
}

/** Send an already serialised frame byte-by-byte through the polling UART driver. */
static void frame_uart_send(const uint8_t *buffer, uint32_t length) {
    uint32_t i;
    for (i = 0; i < length; ++i) {
        while ((USART->status & BIT0) != 0u) { }
        USART->data = buffer[i];
    }
    while ((USART->status & BIT0) != 0u) { }
}

/** Return one currently available UART byte; do not block if RX-valid is clear. */
static int frame_uart_recv(uint8_t *value) {
    if ((USART->status & BIT1) == 0u)
        return 0;
    *value = (uint8_t)USART->data;
    return 1;
}

/** Wait for the host request token, bounded in CPU cycles rather than wall time. */
int uart_report_wait_request(uint64_t timeout_cycles) {
    uint64_t timeout_deadline = uart_report_cycle_now() + timeout_cycles;
    uint8_t value;
    while ((int64_t)(timeout_deadline - uart_report_cycle_now()) > 0) {
        if (frame_uart_recv(&value) && value == REPORT_REQUEST_BYTE)
            return 1;
    }
    return 0;
}

/* Keep the wire format and CRC polynomial compatible with the existing Python receiver. */
/**
 * Serialize the CoreMark verdict and frozen performance counters, append CRC32,
 * transmit the frame, and return the CRC expected in the host ACK.
 */
uint32_t uart_report_send_snapshot(void) {
    uint8_t tx_frame[UART_REPORT_FRAME_MAX];
    uint32_t cursor = 0u;
    uint32_t payload_length_field;
    uint32_t payload_data_begin;
    uint32_t frame_crc;
    uint32_t index;

    frame_append_u32(tx_frame, &cursor, UART_REPORT_FRAME_MAGIC);
    frame_append_u16(tx_frame, &cursor, REPORT_PROTOCOL_VERSION);
    frame_append_u16(tx_frame, &cursor, UART_REPORT_FRAME_TYPE);
    payload_length_field = cursor;
    frame_append_u32(tx_frame, &cursor, 0u);
    frame_append_u32(tx_frame, &cursor, perf_capture_sequence);
    payload_data_begin = cursor;
    frame_append_u32(tx_frame, &cursor, REPORT_BUILD_ID);
    frame_append_u32(tx_frame, &cursor, (uint32_t)COMBINED_CPU_HZ);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.coremark_size);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.iterations);
    frame_append_u64(tx_frame, &cursor, ((uint64_t)benchmark_result_record.ticks_hi << 32) |
                              benchmark_result_record.ticks_lo);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.seconds_floor);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.seedcrc);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.crclist);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.crcmatrix);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.crcstate);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.crcfinal);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.validation);
    frame_append_u32(tx_frame, &cursor, benchmark_result_record.error_count);
    frame_append_u32(tx_frame, &cursor, PERF_MMIO_COUNTER_COUNT);
    frame_append_u32(tx_frame, &cursor, perf_counter_overflow);
    for (index = 0; index < PERF_MMIO_COUNTER_COUNT; ++index)
        frame_append_u64(tx_frame, &cursor, perf_counter_values[index]);

    index = cursor - payload_data_begin;
    tx_frame[payload_length_field + 0] = (uint8_t)index;
    tx_frame[payload_length_field + 1] = (uint8_t)(index >> 8);
    tx_frame[payload_length_field + 2] = (uint8_t)(index >> 16);
    tx_frame[payload_length_field + 3] = (uint8_t)(index >> 24);
    frame_crc = frame_calculate_crc32(tx_frame, cursor);
    frame_append_u32(tx_frame, &cursor, frame_crc);
    frame_uart_send(tx_frame, cursor);
    return frame_crc;
}

/** Accept an ACK only when it explicitly confirms this snapshot's ID and CRC. */
int uart_report_wait_ack(uint32_t snapshot_id, uint32_t report_crc,
                        uint64_t timeout_cycles) {
    uint8_t bytes[9];
    uint32_t count = 0u;
    uint64_t timeout_deadline = uart_report_cycle_now() + timeout_cycles;
    while ((int64_t)(timeout_deadline - uart_report_cycle_now()) > 0) {
        if (frame_uart_recv(&bytes[count])) {
            if ((count == 0u) && (bytes[0] != REPORT_ACK_BYTE))
                continue;
            ++count;
            if (count == sizeof(bytes)) {
                uint32_t id = (uint32_t)bytes[1] | ((uint32_t)bytes[2] << 8) |
                              ((uint32_t)bytes[3] << 16) | ((uint32_t)bytes[4] << 24);
                uint32_t frame_crc = (uint32_t)bytes[5] | ((uint32_t)bytes[6] << 8) |
                               ((uint32_t)bytes[7] << 16) | ((uint32_t)bytes[8] << 24);
                return (id == snapshot_id) && (frame_crc == report_crc);
            }
        }
    }
    return 0;
}
