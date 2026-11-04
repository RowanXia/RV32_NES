import os
import msvcrt
import win32file
import winioctlcon
import ctypes, sys
from contextlib import contextmanager

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except Exception as e:
        print(f"Error checking admin status: {e}")
        return False
if not is_admin():
    # 如果不是管理员，则重新启动并请求管理员权限
    ctypes.windll.shell32.ShellExecuteW(
        None,
        "runas",
        sys.executable,
        f'"{__file__}"',
        None,
        1
    )

@contextmanager
def lock_volume(vol):
    h_vol = msvcrt.get_osfhandle(vol.fileno())
    win32file.DeviceIoControl(h_vol, winioctlcon.FSCTL_LOCK_VOLUME, None, None)
    try:
        yield vol
    finally:
        try:
            vol.flush()
        finally:
            win32file.DeviceIoControl(h_vol, winioctlcon.FSCTL_UNLOCK_VOLUME, None, None)

def write_sector(device, sector_num, data):
    with open(device, 'r+b') as vol:
        with lock_volume(vol):
            vol.seek(sector_num * 512)
            vol.write(data)

def read_sector(device, sector_num):
    with open(device, 'rb') as vol:
        vol.seek(sector_num * 512)
        return vol.read(512)


if __name__ == "__main__":
    # 示例：读取和写入SD卡的第一个扇区
    device_path = r'\\.\PhysicalDrive2'  # 请根据实际情况修改设备路径
    sector_data = read_sector(device_path, 0)
    print(f'Read Sector Data: {sector_data[:64]}')  # 打印部分数据以验证
    
    new_data = bytes()
    for i in range(256):
        new_data += bytes.fromhex("{:02X}".format(i))
    for i in range(256):
        new_data += bytes.fromhex("{:02X}".format(i))
    print(new_data)
    write_sector(device_path, 0, new_data)