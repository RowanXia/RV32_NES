/*
 * SoC MMIO addresses and register layouts shared by the board firmware.
 * Every structure member is one 32-bit APB-visible register.  Keep fields in
 * hardware offset order: C code relies on the structure layout rather than
 * explicit offset arithmetic.
 */


#ifndef __SOC_ADDR_H__
#define __SOC_ADDR_H__

#include "types.h"

/** Board-control registers at 0x10000000: status/display/mapper/input/boot. */
typedef struct {


	u32 volatile status_regs;
	u32 volatile screen_regs;
	u32 volatile mapper_control_word;
	u32 volatile button_regs;
	u32 volatile serial_buttons;
	u32 volatile boot_control;
} CTRLREG_T;

#define CTRLREG ((CTRLREG_T*)0x10000000)

/** GPIO register block at 0x10060000; output_en gates output_val pins. */
typedef struct {
	u32 volatile input_val;
	u32 volatile input_en;
	u32 volatile output_en;
	u32 volatile output_val;
} GPIO_T;

#define GPIO ((GPIO_T*)0x10060000)

/** Polling UART register block at 0x10000400: data followed by status. */
typedef struct {
	u32 volatile data;
	u32 volatile status;
} USART_T;

#define USART ((USART_T*)0x10000400)


#define GRAPHIC_RAM_BASE ((u32)0x21000000) /* One byte per 256x240 display pixel. */


#define NES_RAM_BASE ((u32)0x40000000)     /* PRG/CHR image storage consumed by NES logic. */


#define SDCARD_BASE ((u32)0xC0000000)      /* Read-only SD-image aperture. */


#define WRITE_WORD(ADDR, DATA) \
	(*(u32*)(ADDR)) = (u32)DATA

#define WRITE_HALF_WORD(ADDR, DATA) \
	(*(u16*)(ADDR)) = (u16)DATA

#define WRITE_BYTE(ADDR, DATA) \
	(*(u8*)(ADDR)) = (u8)DATA


#define READ_WORD(ADDR) \
	(*(u32*)(ADDR))

#define READ_HALF_WORD(ADDR) \
	(*(u16*)(ADDR))

#define READ_BYTE(ADDR) \
	(*(u8*)(ADDR))


#endif
