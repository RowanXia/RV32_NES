/*
 * Blocking, polling UART interface for board diagnostics and the optional
 * CoreMark telemetry protocol.  A write waits for TX idle; a read waits until
 * RX-valid.  These calls must not be used from latency-sensitive ISRs.
 */


#ifndef UART_H
#define UART_H

#include "SOC_ADDR.h"

/** Send a NUL-terminated diagnostic string; returns sent characters or -1. */
s32 uart_write_text(char* str);
/** Send an unsigned decimal value without a trailing newline. */
void uart_write_number(u32 num);
/** Read at most size bytes, including the terminating NUL; returns 0 or -1. */
s32 uart_read_text(char* buffer, u32 size);
char uart_read_char();
char uart_write_char(char c);


#endif
