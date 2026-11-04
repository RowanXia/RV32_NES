/*
 * Read access to the board's memory-mapped SD image.  Addresses are offsets
 * from SDCARD_BASE, not CPU absolute addresses.  Halfword/word helpers return
 * all ones when the supplied offset is not naturally aligned.
 */
#ifndef SD_CARD_H
#define SD_CARD_H

#include "SOC_ADDR.h"

u8 sd_card_read_u8(u32 addr);

u16 sd_card_read_u16(u32 addr);

u32 sd_card_read_u32(u32 addr);

#endif
