/*
 * NES menu renderer declarations. Coordinates are in the 256x240 graphics
 * RAM coordinate system; COLOR_T encodes the board display palette index.
 */


#ifndef GRAPHICS_H
#define GRAPHICS_H

#include "SOC_ADDR.h"


typedef u8 COLOR_T;

#define C_BLACK		((COLOR_T)0x0f)
#define C_WHITE 	((COLOR_T)0x30)
#define C_WGRAY 	((COLOR_T)0x20)
#define C_GRAY		((COLOR_T)0x10)
#define C_DGRAY 	((COLOR_T)0x00)
#define C_ORANGE 	((COLOR_T)0x28)


#define SCREEN_MAX_X 256
#define SCREEN_MAX_Y 240


typedef s32 POS_T;

typedef struct {
	POS_T x;
	POS_T y;
} POINT_T;


/** Plot one clipped pixel. Coordinates outside the visible 256x240 area are ignored. */
void graphics_plot_pixel(POINT_T point, COLOR_T COLOR);


/** Clear the complete graphics RAM surface to the menu background colour. */
void graphics_clear();


void graphics_fill_rectangle(POINT_T point0, POINT_T point1, COLOR_T COLOR);


void graphics_draw_line(POINT_T point0, POINT_T point1, COLOR_T COLOR);


void graphics_draw_frame(POINT_T point0, POINT_T point1, COLOR_T COLOR);


/** Draw one ASCII glyph and return its rendered width in pixels. */
u8 graphics_draw_character(POINT_T point0, char c, COLOR_T COLOR);


void graphics_draw_string(POINT_T point0, char* s, COLOR_T COLOR);


void graphics_draw_chinese_glyph(POINT_T point0, const u8* const* Chinese_tiles, u8 tile_x, u8 tile_y, COLOR_T COLOR);
extern const u8* const char_dot_Chinese_0[16];


#endif
