/* NES menu rendering and pixel drawing through the board graphic RAM interface. */
#include "graphics.h"


/** Return the magnitude used by the integer line rasteriser. */
u32 graphics_abs_signed(s32 in){
	return (in > 0) ? in: -in;
}


/** Exchange two endpoint coordinates when a primitive is supplied backwards. */
void graphics_swap_coordinates(POS_T* x, POS_T* y){
	*x ^= *y;
	*y ^= *x;
	*x ^= *y;
}


/**
 * Write one palette-indexed pixel to the 256x240 graphics RAM aperture.
 * Out-of-range coordinates are intentionally ignored so menu layout code does
 * not need a separate clipping pass.
 */
void graphics_plot_pixel(POINT_T point, COLOR_T COLOR){
	if (point.x >= 256 || point.y >= 240
		|| point.x < 0 || point.y < 0){

		return;
	}
	if (COLOR & 0xFFFFFFC0){
		COLOR = COLOR % 64;
	}
	u32 addr = GRAPHIC_RAM_BASE + (u32)point.y * 256 + (u32)point.x;
	WRITE_BYTE(addr, COLOR);
}


/** Clear every visible pixel before a complete menu redraw. */
void graphics_clear(){
	for (POS_T y = 0; y != SCREEN_MAX_Y; ++y){
		for (POS_T x = 0; x != SCREEN_MAX_X; ++x){
			POINT_T p = {x, y};
			graphics_plot_pixel(p, C_BLACK);
		}
	}
}


/** Fill an inclusive rectangle; endpoint order is normalised locally. */
void graphics_fill_rectangle(POINT_T start_point, POINT_T end_point, COLOR_T COLOR){

	if (start_point.x > end_point.x){
		graphics_swap_coordinates(&start_point.x, &end_point.x);
	}
	if (start_point.y > end_point.y){
		graphics_swap_coordinates(&start_point.y, &end_point.y);
	}

	for (POS_T y = start_point.y; y <= end_point.y; ++y){
		for(POS_T x = start_point.x; x <= end_point.x; ++x){
			POINT_T p = {x, y};
			graphics_plot_pixel(p, COLOR);
		}
	}
}


/** Draw an integer line using a fixed-point slope to avoid floating point support. */
void graphics_draw_line(POINT_T start_point, POINT_T end_point, COLOR_T COLOR){


	u8 steep = graphics_abs_signed(end_point.y - start_point.y) > graphics_abs_signed(end_point.x - start_point.x);
	if (steep){

		graphics_swap_coordinates(&start_point.x, &start_point.y);
		graphics_swap_coordinates(&end_point.x, &end_point.y);
	}

	if (start_point.x > end_point.x){
		graphics_swap_coordinates(&start_point.x, &end_point.x);
		graphics_swap_coordinates(&start_point.y, &end_point.y);
	}

	u32 delta_x = end_point.x - start_point.x;
	u32 delta_y = graphics_abs_signed(end_point.y - start_point.y);

	s32 slope_x1024 = delta_y * 1024 / delta_x;
	s32 error;


	s8 y_step = (end_point.y > start_point.y) ? 1 : -1;


	POS_T xk = start_point.x;
	POS_T yk = start_point.y;
	POINT_T p;
	for (; xk < end_point.x; ++xk){
		if (steep){
			p.x = yk;
			p.y = xk;
		}
		else{
			p.x = xk;
			p.y = yk;
		}
		graphics_plot_pixel(p, COLOR);

		error += slope_x1024;
		if (error >= 512){

			yk += y_step;
			error -= 1024;
		}
	}
}


/** Draw the four edges of an inclusive rectangle without filling its interior. */
void graphics_draw_frame(POINT_T start_point, POINT_T end_point, COLOR_T COLOR){

	if (start_point.x > end_point.x){
		graphics_swap_coordinates(&start_point.x, &end_point.x);
	}
	if (start_point.y > end_point.y){
		graphics_swap_coordinates(&start_point.y, &end_point.y);
	}

	POINT_T p = start_point;

	for (; p.x <= end_point.x; ++p.x){
		graphics_plot_pixel(p, COLOR);
	}
	--p.x;


	for (; p.y <= end_point.y; ++p.y){
		graphics_plot_pixel(p, COLOR);
	}
	--p.y;


	for (; p.x >= start_point.x; --p.x){
		graphics_plot_pixel(p, COLOR);
	}
	++p.x;


	for (; p.y >= start_point.y; --p.y){
		graphics_plot_pixel(p, COLOR);
	}
}

#include "char_dots.data"

/** Render one bitmap glyph whose rows are encoded as packed one-bit pixels. */
void graphics_draw_glyph_dots(POINT_T start_point, const u8* c, COLOR_T COLOR){

	for (u8 y = 0; y < 8; ++y){
		u8 row = c[y];
		for (u8 x = 0; x < 8; ++x){
			if (row & 0x80){
				POINT_T p = {start_point.x + x, start_point.y + y};
				graphics_plot_pixel(p, COLOR);
			}
			row <<= 1;
		}
	}
}


/** Draw one supported ASCII character and return the horizontal advance in pixels. */
u8 graphics_draw_character(POINT_T start_point, char c, COLOR_T COLOR){
	u8 width;
	switch (c){
		case ' ':
			width = 8;
			break;
		case '0':
			graphics_draw_glyph_dots(start_point, char_dot_0, COLOR);
			width = 8;
			break;
		case '1':
			graphics_draw_glyph_dots(start_point, char_dot_1, COLOR);
			width = 7;
			break;
		case '2':
			graphics_draw_glyph_dots(start_point, char_dot_2, COLOR);
			width = 8;
			break;
		case '3':
			graphics_draw_glyph_dots(start_point, char_dot_3, COLOR);
			width = 8;
			break;
		case '4':
			graphics_draw_glyph_dots(start_point, char_dot_4, COLOR);
			width = 8;
			break;
		case '5':
			graphics_draw_glyph_dots(start_point, char_dot_5, COLOR);
			width = 8;
			break;
		case '6':
			graphics_draw_glyph_dots(start_point, char_dot_6, COLOR);
			width = 8;
			break;
		case '7':
			graphics_draw_glyph_dots(start_point, char_dot_7, COLOR);
			width = 8;
			break;
		case '8':
			graphics_draw_glyph_dots(start_point, char_dot_8, COLOR);
			width = 8;
			break;
		case '9':
			graphics_draw_glyph_dots(start_point, char_dot_9, COLOR);
			width = 8;
			break;

		case 'A':
		case 'a':
			graphics_draw_glyph_dots(start_point, char_dot_A, COLOR);
			width = 8;
			break;
		case 'B':
		case 'b':
			graphics_draw_glyph_dots(start_point, char_dot_B, COLOR);
			width = 8;
			break;
		case 'C':
		case 'c':
			graphics_draw_glyph_dots(start_point, char_dot_C, COLOR);
			width = 8;
			break;
		case 'D':
		case 'd':
			graphics_draw_glyph_dots(start_point, char_dot_D, COLOR);
			width = 8;
			break;
		case 'E':
		case 'e':
			graphics_draw_glyph_dots(start_point, char_dot_E, COLOR);
			width = 8;
			break;
		case 'F':
		case 'f':
			graphics_draw_glyph_dots(start_point, char_dot_F, COLOR);
			width = 8;
			break;
		case 'G':
		case 'g':
			graphics_draw_glyph_dots(start_point, char_dot_G, COLOR);
			width = 8;
			break;
		case 'H':
		case 'h':
			graphics_draw_glyph_dots(start_point, char_dot_H, COLOR);
			width = 8;
			break;
		case 'I':
		case 'i':
			graphics_draw_glyph_dots(start_point, char_dot_I, COLOR);
			width = 7;
			break;
		case 'J':
		case 'j':
			graphics_draw_glyph_dots(start_point, char_dot_J, COLOR);
			width = 8;
			break;
		case 'K':
		case 'k':
			graphics_draw_glyph_dots(start_point, char_dot_K, COLOR);
			width = 8;
			break;
		case 'L':
		case 'l':
			graphics_draw_glyph_dots(start_point, char_dot_L, COLOR);
			width = 8;
			break;
		case 'M':
		case 'm':
			graphics_draw_glyph_dots(start_point, char_dot_M, COLOR);
			width = 8;
			break;
		case 'N':
		case 'n':
			graphics_draw_glyph_dots(start_point, char_dot_N, COLOR);
			width = 8;
			break;
		case 'O':
		case 'o':
			graphics_draw_glyph_dots(start_point, char_dot_O, COLOR);
			width = 8;
			break;
		case 'P':
		case 'p':
			graphics_draw_glyph_dots(start_point, char_dot_P, COLOR);
			width = 8;
			break;
		case 'Q':
		case 'q':
			graphics_draw_glyph_dots(start_point, char_dot_Q, COLOR);
			width = 8;
			break;
		case 'R':
		case 'r':
			graphics_draw_glyph_dots(start_point, char_dot_R, COLOR);
			width = 8;
			break;
		case 'S':
		case 's':
			graphics_draw_glyph_dots(start_point, char_dot_S, COLOR);
			width = 8;
			break;
		case 'T':
		case 't':
			graphics_draw_glyph_dots(start_point, char_dot_T, COLOR);
			width = 7;
			break;
		case 'U':
		case 'u':
			graphics_draw_glyph_dots(start_point, char_dot_U, COLOR);
			width = 8;
			break;
		case 'V':
		case 'v':
			graphics_draw_glyph_dots(start_point, char_dot_V, COLOR);
			width = 8;
			break;
		case 'W':
		case 'w':
			graphics_draw_glyph_dots(start_point, char_dot_W, COLOR);
			width = 8;
			break;
		case 'X':
		case 'x':
			graphics_draw_glyph_dots(start_point, char_dot_X, COLOR);
			width = 8;
			break;
		case 'Y':
		case 'y':
			graphics_draw_glyph_dots(start_point, char_dot_Y, COLOR);
			width = 8;
			break;
		case 'Z':
		case 'z':
			graphics_draw_glyph_dots(start_point, char_dot_Z, COLOR);
			width = 8;
			break;

		case '(':
			graphics_draw_glyph_dots(start_point, char_dot_leftbracket, COLOR);
			width = 4;
			break;

		case ')':
			graphics_draw_glyph_dots(start_point, char_dot_rightbracket, COLOR);
			width = 4;
			break;

		case '-':
			graphics_draw_glyph_dots(start_point, char_dot_minus, COLOR);
			width = 8;
			break;

		case '+':
			graphics_draw_glyph_dots(start_point, char_dot_plus, COLOR);
			width = 8;
			break;

		case '_':
			graphics_draw_glyph_dots(start_point, char_dot_underline, COLOR);
			width = 8;
			break;

		case '\'':
			graphics_draw_glyph_dots(start_point, char_dot_single_quote, COLOR);
			width = 4;
			break;

		case '\"':
			graphics_draw_glyph_dots(start_point, char_dot_double_quote, COLOR);
			width = 6;
			break;

		default:
			width = 8;
			break;
	}
	return width;
}


/** Draw a NUL-terminated ASCII string on one baseline. */
void graphics_draw_string(POINT_T start_point, char* s, COLOR_T COLOR){
	u32 idx = 0;
	POINT_T now_pos = start_point;
	while (s[idx] != '\0'){
		u8 char_width = graphics_draw_character(now_pos, s[idx], COLOR);
		now_pos.x += char_width;
		++idx;
	}
}

/** Draw text with the menu's fixed-width wrapping policy. */
void graphics_draw_text_box(POINT_T start_point, char* s, COLOR_T COLOR){
	u32 idx = 0;
	POINT_T now_pos = start_point;
	while (s[idx] != '\0'){
		u8 char_width = graphics_draw_character(now_pos, s[idx], COLOR);
		if ((u32)now_pos.x + char_width > SCREEN_MAX_X){
			now_pos.y += 10;
			now_pos.x = start_point.x;
		}
		else {
			now_pos.x += char_width;
		}
		++idx;
	}
}


/** Draw a tiled Chinese glyph assembled from the supplied character-dot table. */
void graphics_draw_chinese_glyph(POINT_T start_point, const u8* const* Chinese_tiles, u8 tile_x, u8 tile_y, COLOR_T COLOR){
	POINT_T p = start_point;
	for (u8 y = 0; y < tile_y; ++y){
		for (u8 x = 0; x < tile_x; ++x){
			u8 tile_idx = y * tile_x + x;
			graphics_draw_glyph_dots(p, Chinese_tiles[tile_idx], COLOR);
			p.x += 8;
		}
		p.x = start_point.x;
		p.y += 8;
	}
}
