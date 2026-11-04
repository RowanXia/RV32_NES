"""Read-only R4 status capture over the existing board UART (115200 8N1)."""
import argparse,json,re,time
from pathlib import Path

REGISTERS=[0x0530,0x0535,0x0532,0x0531,0x0507,0x0503,0x0048,0x0570,0x00a5,0x051d,0x0521,0x0522,0x0008]
EXPECTED=[(0xff,0),(0xff,0x12),(0xff,1),(0xff,0x84),(0xff,0),
          (1,0),(0x0f,0),(1,1),(0x18,0)]

def parse_line(line):
 if isinstance(line,bytes):line=line.decode('ascii',errors='replace')
 match=re.fullmatch(r'AUD4 ([0-9a-fA-F]{28})\r?\n?',line)
 if not match:return None
 raw=bytes.fromhex(match[1]);regs=dict(zip(REGISTERS,raw[:13]));flags=raw[13]
 return dict(raw_line=line.strip(),registers={f'{a:04X}':f'{v:02X}' for a,v in regs.items()},
  initialized=bool(flags&1),post_init_nack_seen=bool(flags&2),
  ten_config_fields_match=all((raw[i]&mask)==expected for i,(mask,expected) in enumerate(EXPECTED)) and (raw[12]&7)==0,
  hdmi_mode=(regs[0x0503]&1)==0,
  timing_stable_reference_bit=bool(regs[0x051d]&0x10),
  note='Raw receiver-side readings; register agreement/timing flag is not proof of audible HDMI audio.')

def self_test():
 values=bytes([0,0x12,1,0x84,0,0,0,0x81,0,0x10,0x30,0x10,0xf0,1])
 p=parse_line('AUD4 '+values.hex().upper()+'\r\n')
 assert p['ten_config_fields_match'] and p['initialized'] and not p['post_init_nack_seen']
 bad=bytearray(values);bad[5]=1
 assert not parse_line('AUD4 '+bad.hex()+'\n')['hdmi_mode']
 assert parse_line('AUD4 00\n') is None and parse_line('noise\n') is None
 print('PASS audio_status_parser register order/masks/flags/invalid packets')

def main():
 ap=argparse.ArgumentParser(description='R4音频状态读取，不向开发板发送命令。')
 ap.add_argument('--port');ap.add_argument('--list',action='store_true');ap.add_argument('--self-test',action='store_true')
 ap.add_argument('--timeout',type=float,default=25);ap.add_argument('--samples',type=int,default=3)
 ap.add_argument('--output',type=Path,default=Path(__file__).with_name('audio_status_R4.json'))
 args=ap.parse_args()
 if args.self_test:self_test();return
 try:
  import serial
  from serial.tools import list_ports
 except ImportError:
  raise SystemExit('缺少pyserial。请先运行：python -m pip install pyserial')
 ports=list(list_ports.comports())
 if args.list:
  print('\n'.join(f'{p.device}: {p.description}' for p in ports) or '未检测到串口。');return
 port=args.port
 if not port:
  if len(ports)==1:port=ports[0].device
  else:
   print('\n'.join(f'{p.device}: {p.description}' for p in ports) or '未检测到串口。')
   raise SystemExit('请指定原键盘控制使用的串口，例如：python software/audio_status_capture.py --port COM5；COM5替换为实际端口。')
 print('请先关闭占用串口的键盘控制程序/串口助手。')
 print(f'只读打开 {port}，115200。请按住板上 KEY4＋KEY1，直到收到3条数据。')
 packets=[]
 try:
  with serial.Serial(port,115200,timeout=0.5) as ser:
   ser.reset_input_buffer();deadline=time.monotonic()+args.timeout
   while time.monotonic()<deadline and len(packets)<args.samples:
    p=parse_line(ser.readline(256))
    if p:packets.append(p);print(p['raw_line'],flush=True)
 except serial.SerialException as e:
  raise SystemExit(f'串口打开/读取失败：{e}\n请确认端口并关闭其他占用串口的程序。')
 if not packets:
  raise SystemExit('未收到AUD4数据。请确认已下载R4、按住KEY4＋KEY1，且选择的是板卡UART串口。无需改HDMI接线；若现有USB连接没有UART串口，可先只反馈声音和LED状态。')
 args.output.write_text(json.dumps(dict(port=port,packets=packets),ensure_ascii=False,indent=2),encoding='utf-8')
 print('已保存：'+str(args.output.resolve()))
 print('可松开按键。请把上面的AUD4行或audio_status_R4.json反馈给我。')

if __name__=='__main__':main()
