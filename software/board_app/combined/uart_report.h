/*
 * Optional host telemetry protocol.  The host sends REPORT_REQUEST_BYTE, the
 * target transmits one binary snapshot and then accepts REPORT_ACK_BYTE only
 * when its sequence number and CRC match the transmitted frame.
 */
#ifndef UART_REPORT_H
#define UART_REPORT_H

#include <stdint.h>

#define REPORT_PROTOCOL_VERSION 1u
#ifndef COMBINED_BUILD_ID
#define COMBINED_BUILD_ID 0x20261026u
#endif
#define REPORT_BUILD_ID COMBINED_BUILD_ID
#define REPORT_REQUEST_BYTE 0xa5u
#define REPORT_ACK_BYTE 0x5au

uint32_t uart_report_send_snapshot(void);
int uart_report_wait_request(uint64_t timeout_cycles);
int uart_report_wait_ack(uint32_t snapshot_id, uint32_t report_crc,
                        uint64_t timeout_cycles);

#endif
