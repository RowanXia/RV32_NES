import os
import struct
from pathlib import Path
import ctypes, sys
from sdcard_rw import write_sector
import time

def pack_files(output_filename:str = "packed.bin"):
    """
    将当前文件夹下所有文件打包成一个大文件
    
    Args:
        output_filename: 输出文件名
    """
    # 获取当前目录下所有文件（排除目录和输出文件自身）
    files = []
    exclude_file_list = [output_filename, "Parse_File.py", "sdcard_rw.py"]
    for item in Path('.').iterdir():
        if item.is_file() and item.name not in exclude_file_list:
            files.append(item)
    
    if not files:
        print("当前文件夹没有可打包的文件")
        return
    
    # 按文件名排序以确保一致性
    files.sort(key=lambda x: x.name)
    
    with open(output_filename, 'wb') as outfile:
        # 第一阶段：收集文件信息并计算偏移量
        file_info = []
        name_strings = []
        
        # 计算文件信息区的总大小
        # 每个文件信息占8字节（两个32位整数），最后加8字节的结束标记
        info_section_size = len(files) * 8 + 8
        
        # 计算文件名字符串区的起始位置
        current_name_offset = info_section_size
        
        # 计算文件内容区的起始位置
        current_content_offset = info_section_size
        
        # 首先计算所有文件名字符串的总长度
        for file_path in files:
            # 获取不带后缀的文件名
            name_without_ext = file_path.stem
            name_bytes = name_without_ext.encode('utf-8') + b'\0'
            
            file_info.append({
                'path': file_path,
                'name': name_without_ext,
                'name_bytes': name_bytes,
                'name_offset': current_name_offset,
                'content_offset': 0,  # 稍后计算
                'size': file_path.stat().st_size
            })
            
            current_name_offset += len(name_bytes)
            current_content_offset += len(name_bytes)
        
        # 现在计算文件内容的偏移量
        for info in file_info:
            info['content_offset'] = current_content_offset
            current_content_offset += info['size']
        
        # 第二阶段：写入文件
        # 1. 写入文件信息区
        for info in file_info:
            # 写入文件名偏移（32位小端序）
            outfile.write(struct.pack('<I', info['name_offset']))
            # 写入文件内容偏移（32位小端序）
            outfile.write(struct.pack('<I', info['content_offset']))
        
        # 写入文件信息结束标记（两个32位0）
        outfile.write(struct.pack('<II', 0, 0))
        
        # 2. 写入文件名字符串区
        for info in file_info:
            outfile.write(info['name_bytes'])
        
        # 3. 写入文件内容区
        for info in file_info:
            with open(info['path'], 'rb') as infile:
                outfile.write(infile.read())
    
    print(f"打包完成！共打包了 {len(files)} 个文件")
    print(f"输出文件: {output_filename}")
    
    # 显示打包的文件列表
    print("\n打包的文件列表:")
    for info in file_info:
        print(f"  - {info['name']} (原文件: {info['path'].name})")

def write_to_sd_card(file_path, device_path):
    """
    将文件写入SD卡的指定位置
    
    Args:
        file_path: 要写入的文件路径
        device_path: SD卡设备路径
    """
    
    # 检查文件是否存在
    if not os.path.exists(file_path):
        print(f"错误: 文件 {file_path} 不存在")
        return False
    
    # 获取文件大小
    file_size = os.path.getsize(file_path)
    print(f"文件大小: {file_size} 字节")
    
    # 计算需要多少扇区
    sector_size = 512  # 标准扇区大小
    sectors_needed = (file_size + sector_size - 1) // sector_size
    print(f"需要 {sectors_needed} 个扇区 (从扇区 0 开始)")
    try:
        # 打开要写入的文件
        with open(file_path, 'rb') as input_file:
            bytes_written = 0
            sector_num = 0
            
            print("开始写入SD卡...")
            start_time = time.time()
            
            while sector_num < sectors_needed:
                # 读取一个扇区的数据
                data = input_file.read(sector_size)
                
                # 如果数据不足512字节，用0填充
                if len(data) < sector_size:
                    data += b'\x00' * (sector_size - len(data))
                
                # 写入扇区
                write_sector(device_path, sector_num, data)
                
                bytes_written += len(data)
                sector_num += 1
                
                # 显示进度
                progress = (bytes_written / file_size) * 100
                print(f"\r进度: {progress:.1f}% ({sector_num}/{sectors_needed} 扇区)", end='', flush=True)
            
            end_time = time.time()
            elapsed_time = end_time - start_time
            print(f"\n写入完成! 耗时: {elapsed_time:.2f} 秒")
            print(f"平均速度: {file_size / (1024 * 1024) / elapsed_time:.2f} MB/s")
            
            return True
                
    except Exception as e:
        print(f"写入过程中发生错误: {str(e)}")
        return False

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except Exception as e:
        print(f"Error checking admin status: {e}")
        return False

def main():
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

    pack_files("output.bin")
    device_path = r'\\.\PhysicalDrive2'
    write_to_sd_card("output.bin", device_path)

if __name__ == "__main__":
    main()