/*
 * Polling UART access for diagnostics, NES menu communication and optional
 * result telemetry.  The UART hardware exposes TX-busy in status bit 0 and
 * RX-valid in status bit 1; no interrupt state is consumed by this driver.
 */
#include "uart.h"


/** Block until TX is idle, write one byte, and return the transmitted byte. */
char uart_write_char(char character){

	while ((USART -> status) & BIT0)
		;
	USART -> data = character;
	return character;
}


/** Send at most 256 characters followed by a NUL framing byte. */
s32 uart_write_text(char* text){
	s32 character_index = 0;
	while (text[character_index] != '\0'){
		uart_write_char(text[character_index]);
		++character_index;


		if (character_index == 256) {
			return -1;
		}
	}

	uart_write_char('\0');
	return character_index;
}

/** Convert an unsigned 32-bit number to decimal without relying on libc. */
void uart_write_number(u32 number){
	if (number == 0) {
		uart_write_char('0');
		return;
	}

    char buffer[11];
    int index = 0;


    while (number > 0) {
        buffer[index++] = '0' + (number % 10);
        number /= 10;
    }


    for (int i = index - 1; i >= 0; i--) {
        uart_write_char(buffer[i]);
    }
}


/** Block until a received byte is available and return it. */
char uart_read_char(){

	while (!((USART -> status) & BIT1))
		;
	char c = USART -> data;

	return c;
}


/** Read a NUL-framed string, retaining space for the local terminator. */
s32 uart_read_text(char* buffer, u32 buffer_size){
	if (buffer_size == 0) return -1;
	u32 character_index = 0;
	char character;
	while (1) {
		character = uart_read_char();
		if (character == '\0') {
			buffer[character_index] = '\0';
			break;
		}
		/* Keep one byte for the local terminator; never write past buffer_size. */
		if ((character_index + 1u) >= buffer_size) {
			buffer[buffer_size - 1u] = '\0';
			return -1;
		}
		buffer[character_index++] = character;
	}
	return 0;
}
