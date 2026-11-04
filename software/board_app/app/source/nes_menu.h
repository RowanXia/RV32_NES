/*
 * NES menu and game handoff interface. Initialization scans the SD catalogue;
 * the menu loop selects a cartridge, and the game loop services the selected
 * image through the existing NES hardware interface.
 */


#ifndef NES_MENU_H
#define NES_MENU_H

#include "uart.h"
#include "graphics.h"
#include "SOC_ADDR.h"
#include "sd_card.h"


/** Scan the cartridge catalogue and prepare the first menu page. */
void nes_menu_init();


/** Run menu input/rendering until a game is selected. */
void nes_menu_loop();


/** Run the selected game's input service loop after the NES display is active. */
void nes_game_loop();


#endif
