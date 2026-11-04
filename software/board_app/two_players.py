"""Two USB gamepads -> NES FPGA, 115200 8N1. No imports needed for --help."""
import argparse
import time

LEGACY_CODES = (5, 6, 8, 7, 1, 2, 3, 4)

# Two-player controller snapshot encoding.
def snapshot(player, state):
    # Select the command base for player 1 or player 2.
    base = 0x10 if player == 1 else 0x30
    # Pack the low and high controller-state nibbles into two bytes.
    return bytes((base | (state & 15), (base + 0x10) | (state >> 4)))


def read_state(joy, args):
    if joy is None or not joy.get_init():
        return 0
    state = 0
    for bit, index in enumerate((args.a, args.b, args.select, args.start)):
        if 0 <= index < joy.get_numbuttons() and joy.get_button(index):
            state |= 1 << bit
    x, y = joy.get_hat(0) if joy.get_numhats() else (0, 0)
    ax = joy.get_axis(0) if joy.get_numaxes() >= 1 else 0
    ay = joy.get_axis(1) if joy.get_numaxes() >= 2 else 0
    for bit, pressed in ((4, y > 0 or ay < -args.threshold),
                         (5, y < 0 or ay > args.threshold),
                         (6, x < 0 or ax < -args.threshold),
                         (7, x > 0 or ax > args.threshold)):
        if pressed:
            state |= 1 << bit
    return state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', help='FPGA COM port, e.g. COM5')
    parser.add_argument('--list', action='store_true', help='List serial ports and gamepads')
    parser.add_argument('--p1', type=int, default=0, help='P1 gamepad index')
    parser.add_argument('--p2', type=int, default=1, help='P2 gamepad index')
    parser.add_argument('--a', type=int, default=0)
    parser.add_argument('--b', type=int, default=1)
    parser.add_argument('--select', type=int, default=6)
    parser.add_argument('--start', type=int, default=7)
    parser.add_argument('--threshold', type=float, default=0.5)
    parser.add_argument('--verbose', action='store_true', help='Print changing P1/P2 state bytes')
    args = parser.parse_args()
    if not args.list and not args.port:
        parser.error('--port is required (or use --list)')
    if args.p1 == args.p2:
        parser.error('P1 and P2 must use different gamepad indices')
    if not 0 < args.threshold <= 1:
        parser.error('--threshold must be between 0 and 1')
    from menu_controls import MenuControls
    import pygame
    import serial
    from serial.tools import list_ports
    pygame.init()
    pygame.joystick.init()
    pads = [pygame.joystick.Joystick(i) for i in range(pygame.joystick.get_count())]
    for joy in pads:
        joy.init()
    try:
        for i, joy in enumerate(pads):
            print(f'Gamepad {i}: {joy.get_name()}, buttons={joy.get_numbuttons()}, '
                  f'axes={joy.get_numaxes()}, hats={joy.get_numhats()}')
        if args.list:
            for port in list_ports.comports():
                print(f'{port.device}: {port.description}')
            return
        if min(args.p1, args.p2) < 0 or max(args.p1, args.p2) >= len(pads):
            parser.error('Connect two gamepads; use --list to check their indices')
        players = [pads[args.p1], pads[args.p2]]
        screen=pygame.display.set_mode((900,180))
        pygame.display.set_caption('NES USB gamepads: F1 title-menu mode')
        font=pygame.font.Font(None,27)
        menu=MenuControls()
        previous = 0
        last_display = None
        with serial.Serial(args.port, 115200, timeout=0.1, write_timeout=1) as ser:
            print(f'P1={args.p1}, P2={args.p2}, port={ser.name}; Ctrl+C to stop')
            try:
                running=True
                while running:
                    started = time.monotonic()
                    for event in pygame.event.get():
                        if event.type==pygame.QUIT:running=False
                        if event.type==pygame.KEYDOWN and event.key==pygame.K_F1:menu.toggle()
                        if event.type == pygame.JOYDEVICEREMOVED:
                            for i, joy in enumerate(players):
                                if joy is not None and joy.get_instance_id() == event.instance_id:
                                    players[i] = None
                                    print(f'P{i+1} disconnected; restart after reconnecting')
                    states = [read_state(joy, args) for joy in players]
                    if not running:states=[0,0]
                    if players[0] is None:menu.release()
                    states[0]=menu.apply(states[0],started)
                    screen.fill((22,27,38))
                    for line,text in enumerate((f'P1={states[0]:02X} P2={states[1]:02X}',
                        f'F1: title Select adapter = {menu.enabled}; Start returns to normal',
                        'In title-menu mode, tap any P1 direction to select 1P/2P.')):
                        screen.blit(font.render(text,True,(225,232,242)),(20,25+line*45))
                    pygame.display.flip()
                    if args.verbose and states != last_display:
                        print(f'P1=0x{states[0]:02X} P2=0x{states[1]:02X}')
                        last_display = states.copy()
                    # Firmware menus still consume the original P1 edge commands.
                    # Space them out for the original one-byte firmware mailbox.
                    changed = states[0] ^ previous
                    for bit, code in enumerate(LEGACY_CODES):
                        if changed & (1 << bit):
                            ser.write(bytes((code if states[0] & (1 << bit) else code | 0x80,)))
                            ser.flush()
                            time.sleep(0.003)
                    previous = states[0]
                    # Periodically transmit the current state of both controller ports.
                    ser.write(snapshot(1, states[0]) + snapshot(2, states[1]))
                    # Limit controller updates to a 20 ms period (50 Hz).
                    time.sleep(max(0, 0.02 - (time.monotonic() - started)))
            except KeyboardInterrupt:
                pass
            finally:
                ser.write(snapshot(1, 0) + snapshot(2, 0))
                ser.flush()
    finally:
        pygame.quit()


if __name__ == '__main__':
    main()
