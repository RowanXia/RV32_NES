"""Two keyboard players over 115200 8N1; the input window must have focus."""
import argparse,time
from two_players import snapshot
from menu_controls import MenuControls

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--port',required=True,help='FPGA COM port, e.g. COM5')
    args=ap.parse_args()
    import pygame,serial
    pygame.init()
    screen=pygame.display.set_mode((900,300))
    pygame.display.set_caption('NES serial: P1 + P2 (Esc exits)')
    font=pygame.font.Font(None,28)
    mappings=((pygame.K_j,pygame.K_k,pygame.K_u,pygame.K_i,pygame.K_w,pygame.K_s,pygame.K_a,pygame.K_d),
              (pygame.K_KP1,pygame.K_KP2,pygame.K_KP4,pygame.K_KP5,pygame.K_UP,pygame.K_DOWN,pygame.K_LEFT,pygame.K_RIGHT))
    clock=pygame.time.Clock()
    menu=MenuControls()
    try:
        with serial.Serial(args.port,115200,timeout=.1,write_timeout=1) as ser:
            try:
                running=True
                while running:
                    for event in pygame.event.get():
                        if event.type==pygame.QUIT or (event.type==pygame.KEYDOWN and event.key==pygame.K_ESCAPE):running=False
                        if event.type==pygame.KEYDOWN and event.key==pygame.K_F1:menu.toggle()
                    keys=pygame.key.get_pressed()
                    states=[sum((1<<bit) for bit,key in enumerate(mapping) if keys[key]) for mapping in mappings] if pygame.key.get_focused() and running else [0,0]
                    if pygame.key.get_focused() and running:
                        states[0]=menu.apply(states[0],time.monotonic())
                    else:menu.release()
                    ser.write(snapshot(1,states[0])+snapshot(2,states[1]))
                    screen.fill((22,27,38))
                    for i,line in enumerate(('P1: WASD / A=J B=K Select=U Start=I',
                                              'P2: Arrows / A=Num1 B=Num2 Select=Num4 Start=Num5',
                                              f'P1={states[0]:02X}  P2={states[1]:02X}',
                                              f'F1: title Select adapter = {menu.enabled}; Start returns to normal',
                                              'Click this window to play. Losing focus releases all buttons.')):
                        screen.blit(font.render(line,True,(225,232,242)),(20,30+i*45))
                    pygame.display.flip();clock.tick(50)
            finally:
                if ser.is_open:ser.write(snapshot(1,0)+snapshot(2,0));ser.flush()
    finally:pygame.quit()

if __name__=='__main__':main()
