/* NES ROM directory, mapper configuration, menu navigation and game handoff. */
#include "nes_menu.h"


/** One SD catalogue entry: byte offsets to the ROM image and its display name. */
typedef struct {
	u32 rom_start_offset;
	u32 rom_name_offset;
} NES_ROM_ENTRY;


/* The menu supports the first 50 catalogue entries, ten per rendered page. */
static NES_ROM_ENTRY nes_rom_catalog[50];
static u32 nes_rom_count = 0;

const u32 menu_page_capacity = 10;

static u32 menu_page_count = 0;
static u32 menu_current_page = 0;
static u32 menu_focus_index = 0;


/* ROM index entries are read from the SD image before menu rendering. */
/**
 * Read paired name/ROM offsets from the SD catalogue until its zero terminator.
 * The catalogue itself stays on SD; only the small index is retained in CPU RAM.
 */
void nes_catalog_scan(void) {
    u32 catalog_cursor = 0;
    nes_rom_count = 0;


    while (nes_rom_count < 50) {

        u32 name_location = sd_card_read_u32(catalog_cursor);
		uart_write_number(name_location);
		uart_write_char('\n');
        catalog_cursor += 4;


        u32 rom_location = sd_card_read_u32(catalog_cursor);
		uart_write_number(rom_location);
		uart_write_char('\n');
        catalog_cursor += 4;


        if (name_location == 0 && rom_location == 0) {
            break;
        }


        nes_rom_catalog[nes_rom_count].rom_name_offset = name_location;
        nes_rom_catalog[nes_rom_count].rom_start_offset = rom_location;
        nes_rom_count++;
    }

	menu_page_count = (nes_rom_count == 0) ? 1
			: ((nes_rom_count - 1) / menu_page_capacity + 1);

	uart_write_text("file_count = ");uart_write_number(nes_rom_count);uart_write_char('\n');
	uart_write_text("total_page = ");uart_write_number(menu_page_count);uart_write_char('\n');
}


/**
 * Parse an iNES header, copy PRG/CHR payloads to NES RAM, and program mapper
 * metadata.  @return 0 on a supported image, otherwise the existing error code.
 */
u32 nes_cartridge_load(u32 rom_index){

	uart_write_text("进入游戏：");uart_write_number(rom_index);uart_write_text("\n");

	u32 rom_location = nes_rom_catalog[rom_index].rom_start_offset;
	if(rom_index >= nes_rom_count || sd_card_read_u32(rom_location) != 0x1a53454e) return 0;
	uart_write_text("起始地址");uart_write_number(rom_location);uart_write_text("\n");


	u8 prg_bank_count = sd_card_read_u8(rom_location + 4);
	u8 chr_bank_count = sd_card_read_u8(rom_location + 5);

	// Validate cartridge image parameters.
	// Derive the PRG and CHR byte counts from their bank counts.
	u32 program_rom_bytes = (u32)prg_bank_count * 16384;
	u32 character_rom_bytes = (u32)chr_bank_count * 8192;

	// Read header bytes 6 and 7.
	u8 BYTE6 = sd_card_read_u8(rom_location + 6);
	u8 BYTE7 = sd_card_read_u8(rom_location + 7);
	// Check the image capacity limits.
	if(program_rom_bytes == 0 || program_rom_bytes > 262144 || character_rom_bytes > 131072) return 0;
	// Reject NES 2.0 and four-screen images that this loader does not support.
	if((BYTE7 & 12) == 8 || (BYTE6 & 8)) return 0;
	// Require PRG and CHR bank counts to be powers of two.
	if((prg_bank_count & (prg_bank_count-1)) || (chr_bank_count && (chr_bank_count & (chr_bank_count-1)))) return 0;
	// Skip the file header and the optional 512-byte trainer.
	u32 rom_payload_offset = 16 + ((BYTE6 & 4) ? 512 : 0);
	uart_write_text("BYTE6为");uart_write_number(BYTE6);uart_write_text("\n");
	uart_write_text("BYTE7为");uart_write_number(BYTE7);uart_write_text("\n");


	// Extract the mapper number from the cartridge header.
	u8 mapper = (BYTE7 & 0xF0) + ((BYTE6 & 0xF0) >> 4);
	// Check that the mapper is within the supported set.
	if(mapper!=0 && mapper!=1 && mapper!=2 && mapper!=3 && mapper!=127 && mapper!=132) return 0;

	u8 nametable_mirror_mode = BYTE6 & BIT0;

	u8 chr_rom_log =	chr_bank_count <= 1  ? 0 :
						chr_bank_count <= 2  ? 1 :
						chr_bank_count <= 4  ? 2 :
						chr_bank_count <= 8  ? 3 :
						chr_bank_count <= 16 ? 4 :
						chr_bank_count <= 32 ? 5 :
						chr_bank_count <= 64 ? 6 : 7;

	u8 prg_rom_log =	prg_bank_count <= 1  ? 0 :
						prg_bank_count <= 2  ? 1 :
						prg_bank_count <= 4  ? 2 :
						prg_bank_count <= 8  ? 3 :
						prg_bank_count <= 16 ? 4 :
						prg_bank_count <= 32 ? 5 :
						prg_bank_count <= 64 ? 6 : 7;

	u8 uses_character_ram = (chr_bank_count == 0);


	u32 mapper_control_word =	((u32)uses_character_ram << 15) +
						((u32)nametable_mirror_mode << 14) +
						((u32)(chr_rom_log & 0x07) << 11) +
						((u32)(prg_rom_log & 0x07) << 8) +
						(u32)mapper;

	CTRLREG -> mapper_control_word = mapper_control_word;

	uart_write_text("MAPPER为");uart_write_number(mapper_control_word);uart_write_text("\n");
	uart_write_text("PRG大小为");uart_write_number(program_rom_bytes);uart_write_text("\n");
	uart_write_text("CHR大小为");uart_write_number(character_rom_bytes);uart_write_text("\n");


	// Write the cartridge image into NES execution memory.
	// Copy PRG and CHR data separately.
	u32 i;
	for(i = 0; i < program_rom_bytes; ++i){
		u32 dest_addr = NES_RAM_BASE + i;
		(*(u8*)dest_addr) = sd_card_read_u8(rom_location + rom_payload_offset + i);
	}


	for(i = 0; i < character_rom_bytes; ++i){
		u32 dest_addr = NES_RAM_BASE + BIT18 + i;
		(*(u8*)dest_addr) = sd_card_read_u8(rom_location + rom_payload_offset + program_rom_bytes + i);
	}
	// When no CHR ROM is present, clear the 8 KiB CHR RAM instead.
	if(character_rom_bytes == 0) for(i=0;i<8192;i++) WRITE_BYTE(NES_RAM_BASE + BIT18 + i,0);
	// Return success; all validation failures returned earlier.
	return 1;
}


static char temp_filename_buffer[50];
/** Draw one visible catalogue row and invert/highlight it when selected. */
void nes_menu_draw_item(u32 rom_index, u32 menu_item_index, u8 is_selected){

	u32 char_idx = 0;
	while (char_idx < 50){
		char c = sd_card_read_u8(nes_rom_catalog[rom_index].rom_name_offset + char_idx);
		if (c == '\0' || char_idx == 49){
			temp_filename_buffer[char_idx] = '\0';
			break;
		}
		temp_filename_buffer[char_idx] = c;
		++char_idx;
	}

	POINT_T pos = {20, 40 + menu_item_index*17};
	COLOR_T color = is_selected ? C_ORANGE : C_WGRAY;
	graphics_draw_string(pos, temp_filename_buffer, color);
}


void nes_menu_clear(void){

	POINT_T p0 = {20, 40};
	POINT_T p1 = {240, 220};
	graphics_fill_rectangle(p0, p1, C_BLACK);
}


/** Render only the current page, using menu_current_page and menu_focus_index. */
void nes_menu_render(void){

	u32 items = (menu_current_page == menu_page_count - 1) ?
			 (nes_rom_count ? ((nes_rom_count - 1) % menu_page_capacity + 1) : 0) : menu_page_capacity;
	for (u32 i = 0; i < items; ++i){
		nes_menu_draw_item(menu_current_page * menu_page_capacity + i, i, (i == menu_focus_index));
	}
}

void nes_menu_draw_page(){

	POINT_T p0 = {128-4, 220};
	POINT_T p1 = {128+4, 220+8};
	graphics_fill_rectangle(p0, p1, C_BLACK);
	graphics_draw_character(p0, '0' + menu_current_page%10 + 1, C_WGRAY);
}


/** Enable the NES display path after a ROM has been loaded into NES RAM. */
void nes_display_activate(){
	CTRLREG -> status_regs |= BIT1;
}


void nes_menu_draw_background(){

	POINT_T p0 = {0,0};
	POINT_T p1 = {255, 239};
	graphics_draw_frame(p0, p1, C_DGRAY);
	++p0.x; ++p0.y;
	--p1.x; --p1.y;
	graphics_draw_frame(p0, p1, C_DGRAY);


	POINT_T pos = {96 + 1, 10 + 1};
	graphics_draw_chinese_glyph(pos, char_dot_Chinese_0, 8, 2, C_DGRAY);

	--pos.x; --pos.y;
	graphics_draw_chinese_glyph(pos, char_dot_Chinese_0, 8, 2, C_WGRAY);


}


// Initialise the menu.
void nes_menu_init(){
	// Scan the SD-card game catalogue.
	nes_catalog_scan();
	// Clear the display framebuffer.
	graphics_clear();
	// Draw the menu background.
	nes_menu_draw_background();
	// Render the current menu entries.
	nes_menu_render();
	// Draw the current menu page.
	nes_menu_draw_page();
	// Enable the HDMI display output.
	nes_display_activate();
}


typedef enum {
	KEY_UP_PRESS = 0,
	KEY_UP_RELEASE,

	KEY_DOWN_PRESS,
	KEY_DOWN_RELEASE,

	KEY_LEFT_PRESS,
	KEY_LEFT_RELEASE,

	KEY_RIGHT_PRESS,
	KEY_RIGHT_RELEASE,

	KEY_A_PRESS,
	KEY_A_RELEASE,

	KEY_B_PRESS,
	KEY_B_RELEASE,

	KEY_START_PRESS,
	KEY_START_RELEASE,

	KEY_SELECT_PRESS,
	KEY_SELECT_RELEASE,

	NO_INFO
} KEY_INFO_T;

// Menu button sampling.
KEY_INFO_T nes_input_sample(){
 // Preserve the state of the previously processed keys.
 static u8 previous=0, queued=0;
 static const KEY_INFO_T press[8]={KEY_A_PRESS,KEY_B_PRESS,KEY_SELECT_PRESS,KEY_START_PRESS,KEY_UP_PRESS,KEY_DOWN_PRESS,KEY_LEFT_PRESS,KEY_RIGHT_PRESS};
 static const KEY_INFO_T release[8]={KEY_A_RELEASE,KEY_B_RELEASE,KEY_SELECT_RELEASE,KEY_START_RELEASE,KEY_UP_RELEASE,KEY_DOWN_RELEASE,KEY_LEFT_RELEASE,KEY_RIGHT_RELEASE};
 // Read the first byte of the hardware key state.
 u8 now=(u8)READ_WORD(0x10000010);
 // Compare against the previous state to find changed keys.
 u8 changed=now ^ previous;
 if(!changed) return NO_INFO;
 for(u32 bit=0;bit<8;bit++) if(changed & (1u<<bit)) {
  // Update the stored state for the key being processed.
  previous ^= 1u<<bit;
  // Return the press or release event for the current key.
  return (now & (1u<<bit)) ? press[bit] : release[bit];
 }
 return NO_INFO;
}


/** Apply one debounced menu event and report whether it launches a cartridge. */
u32 nes_menu_handle_keys(KEY_INFO_T key_info){
	if(nes_rom_count == 0) return 0;
	switch (key_info){
		case KEY_UP_RELEASE:
			if (menu_focus_index == 0){

				nes_menu_clear();
				if (menu_current_page == 0){

					menu_current_page = menu_page_count - 1;

					menu_focus_index = (nes_rom_count - 1) % menu_page_capacity;
				}
				else {
					--menu_current_page;

					menu_focus_index = menu_page_capacity - 1;
				}
				nes_menu_draw_page();
			}
			else {
				--menu_focus_index;
			}
			nes_menu_render();
			break;
		case KEY_DOWN_RELEASE:
			if ((menu_focus_index == menu_page_capacity - 1)
				|| ((menu_current_page == menu_page_count - 1) && (menu_focus_index == ((nes_rom_count - 1)%menu_page_capacity)))){

				nes_menu_clear();
				if (menu_current_page == menu_page_count - 1){

					menu_current_page = 0;

					menu_focus_index = 0;
				}
				else {
					++menu_current_page;

					menu_focus_index = 0;
				}
				nes_menu_draw_page();
			}
			else {
				++menu_focus_index;
			}
			nes_menu_render();
			break;
		case KEY_LEFT_RELEASE:

			nes_menu_clear();
			if (menu_current_page == 0){

				menu_current_page = menu_page_count - 1;

				menu_focus_index = (nes_rom_count - 1) % menu_page_capacity;
			}
			else {
				--menu_current_page;
			}
			nes_menu_render();
			nes_menu_draw_page();
			break;
		case KEY_RIGHT_RELEASE:

			nes_menu_clear();
			if (menu_current_page == menu_page_count - 1){

				menu_current_page = 0;
			}
			else if (menu_current_page == menu_page_count - 2){
				menu_current_page = menu_page_count - 1;
				menu_focus_index = (nes_rom_count - 1)%menu_page_capacity;
			}
			else {
				++menu_current_page;
			}
			nes_menu_draw_page();
			nes_menu_render();
			break;
		case KEY_START_RELEASE:
		case KEY_A_RELEASE:

			if(nes_rom_count == 0) return 0;
			if(!nes_cartridge_load(menu_current_page * menu_page_capacity + menu_focus_index)) return 0;
			return 1;
			break;
		case NO_INFO:
			break;
		default:
			break;
	}
	return 0;
}

/** Poll menu controls until a valid selection transitions to game mode. */
void nes_menu_loop(){
	while (1){

		if (nes_menu_handle_keys(nes_input_sample())){


			CTRLREG -> status_regs |= BIT0;
			return;
		}
	}
}


/** Translate board-button events into the NES controller register convention. */
void nes_game_handle_keys(KEY_INFO_T key_info){
	switch (key_info){
		case KEY_UP_PRESS:
			CTRLREG -> button_regs |= BIT4;
			break;
		case KEY_UP_RELEASE:
			CTRLREG -> button_regs &= ~BIT4;
			break;

		case KEY_DOWN_PRESS:
			CTRLREG -> button_regs |= BIT5;
			break;
		case KEY_DOWN_RELEASE:
			CTRLREG -> button_regs &= ~BIT5;
			break;

		case KEY_LEFT_PRESS:
			CTRLREG -> button_regs |= BIT6;
			break;
		case KEY_LEFT_RELEASE:
			CTRLREG -> button_regs &= ~BIT6;
			break;

		case KEY_RIGHT_PRESS:
			CTRLREG -> button_regs |= BIT7;
			break;
		case KEY_RIGHT_RELEASE:
			CTRLREG -> button_regs &= ~BIT7;
			break;

		case KEY_A_PRESS:
			CTRLREG -> button_regs |= BIT0;
			break;
		case KEY_A_RELEASE:
			CTRLREG -> button_regs &= ~BIT0;
			break;

		case KEY_B_PRESS:
			CTRLREG -> button_regs |= BIT1;
			break;
		case KEY_B_RELEASE:
			CTRLREG -> button_regs &= ~BIT1;
			break;

		case KEY_START_PRESS:
			CTRLREG -> button_regs |= BIT3;
			break;
		case KEY_START_RELEASE:
			CTRLREG -> button_regs &= ~BIT3;
			break;

		case KEY_SELECT_PRESS:
			CTRLREG -> button_regs |= BIT2;
			break;
		case KEY_SELECT_RELEASE:
			CTRLREG -> button_regs &= ~BIT2;
			break;

		case NO_INFO:
			break;

		default:
			break;
	}
}


/** Continue servicing controller input while the NES hardware executes the game. */
void nes_game_loop(){
	while(1){
		nes_game_handle_keys(nes_input_sample());
	}
}
