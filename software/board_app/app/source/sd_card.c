/* Byte, halfword and word reads from the memory-mapped SD controller. */
#include "sd_card.h"

/** Read an SD image byte at byte_offset from SDCARD_BASE. */
u8 sd_card_read_u8(u32 byte_offset){
	byte_offset += SDCARD_BASE;
	return READ_BYTE(byte_offset);
}

/** Read an aligned SD image halfword; return 0xffff for a misaligned offset. */
u16 sd_card_read_u16(u32 byte_offset){
	if (byte_offset%2 != 0) return -1;
	byte_offset += SDCARD_BASE;
	return READ_HALF_WORD(byte_offset);
}

/** Read an aligned SD image word; return 0xffffffff for a misaligned offset. */
u32 sd_card_read_u32(u32 byte_offset){
	if (byte_offset%4 != 0) return -1;
	byte_offset += SDCARD_BASE;
	return READ_WORD(byte_offset);
}
