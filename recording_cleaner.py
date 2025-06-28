import os
import time

def manage_recordings(
    recordings_root_path,
    max_total_size_gb,
    dry_run=True  # 默认为True，表示试运行，不会实际删除文件
):
    """
    管理录制文件，确保总大小不超过指定限制。
    如果超过限制，将删除最旧的视频文件及其关联文件（封面和弹幕），直至总大小符合要求。
    
    关联文件处理逻辑：
    - 视频文件: .flv, .mp4, .mkv 等
    - 封面图片: .jpg, .jpeg, .png, .gif, .webp 等
    - 弹幕文件: .xml

    Args:
        recordings_root_path (str): 录制文件所在的根目录路径。
        max_total_size_gb (int/float): 允许的最大总大小（GB）。
        dry_run (bool): 如果为True，则只打印将要删除的文件，不实际执行删除操作。
                        设置为False以启用实际删除。
    """

    # 文件类型定义
    video_extensions = ('.flv', '.mp4', '.mkv', '.ts', '.mov', '.avi')  # 常见视频格式
    image_extensions = ('.jpg', '.jpeg', '.png', '.gif', '.webp')       # 常见图像格式
    danmaku_extension = '.xml'  # 弹幕文件扩展名

    # 将 GB 转换为字节
    max_total_size_bytes = max_total_size_gb * (1024**3)

    print(f"\n{'='*50}")
    print(f"录制文件自动清理工具")
    print(f"检查路径: {recordings_root_path}")
    print(f"最大空间限制: {max_total_size_gb} GB")
    print(f"当前时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    if dry_run:
        print("!!! 试运行模式: 模拟删除操作，不会实际删除文件 !!!")
    else:
        print("!!! 实际删除模式: 文件将被永久移除 !!!")
    print(f"{'='*50}\n")

    # 检查根路径
    if not os.path.exists(recordings_root_path):
        print(f"错误: 路径 '{recordings_root_path}' 不存在")
        return
    if not os.path.isdir(recordings_root_path):
        print(f"错误: '{recordings_root_path}' 不是一个目录")
        return

    # 扫描所有视频文件并计算总大小
    file_groups = {}  # key: 文件基名 (如"录制-1917954821-20250520-090417-466-【甜v私皮】甜歌天花板"), value: 文件组字典
    current_total_size_bytes = 0
    total_video_files = 0
    directories_scanned = 0

    print("正在扫描视频文件...")
    start_time = time.time()
    
    for root, dirs, files in os.walk(recordings_root_path):
        directories_scanned += 1
        
        video_files = [f for f in files if os.path.splitext(f)[1].lower() in video_extensions]
        
        if not video_files:
            continue  # 跳过没有视频文件的目录
            
        for file in files:
            file_path = os.path.join(root, file)
            
            try:
                if any(file.lower().endswith(ext) for ext in video_extensions):
                    # 视频文件处理
                    file_size = os.path.getsize(file_path)
                    file_mtime = os.path.getmtime(file_path)
                    file_base = os.path.splitext(file)[0]  # 获取基名
                    
                    # 创建文件组
                    if file_base not in file_groups:
                        file_groups[file_base] = {
                            'video': None,
                            'image': None,
                            'danmaku': None,
                            'size': 0,
                            'mtime': None
                        }
                    
                    # 保存视频文件信息
                    file_groups[file_base]['video'] = {
                        'path': file_path,
                        'size': file_size
                    }
                    file_groups[file_base]['mtime'] = file_mtime
                    file_groups[file_base]['size'] += file_size
                    total_video_files += 1
                    current_total_size_bytes += file_size
                
                elif any(file.lower().endswith(ext) for ext in image_extensions):
                    # 封面图片处理
                    file_base = os.path.splitext(file)[0]
                    file_size = os.path.getsize(file_path)
                    
                    if file_base in file_groups:
                        file_groups[file_base]['image'] = {
                            'path': file_path,
                            'size': file_size
                        }
                        file_groups[file_base]['size'] += file_size
                        current_total_size_bytes += file_size
                
                elif file.lower().endswith(danmaku_extension):
                    # 弹幕文件处理
                    file_base = os.path.splitext(file)[0]
                    file_size = os.path.getsize(file_path)
                    
                    if file_base in file_groups:
                        file_groups[file_base]['danmaku'] = {
                            'path': file_path,
                            'size': file_size
                        }
                        file_groups[file_base]['size'] += file_size
                        current_total_size_bytes += file_size
            
            except OSError as e:
                print(f"警告: 无法访问文件 '{file_path}': {e}")
                continue

    scan_time = time.time() - start_time
    print(f"扫描完成: 处理了 {directories_scanned} 个目录，找到 {len(file_groups)} 个视频文件组")
    print(f"当前总空间使用量: {current_total_size_bytes / (1024**3):.2f} GB")
    print(f"扫描耗时: {scan_time:.2f} 秒\n")

    # 检查是否超过限制
    if current_total_size_bytes <= max_total_size_bytes:
        print("当前空间使用低于限制，无需删除文件")
        return

    exceeded_size = current_total_size_bytes - max_total_size_bytes
    print(f"空间超限: 超出 {(exceeded_size / (1024**3)):.2f} GB，需要删除旧文件\n")

    # 按最后修改时间排序（最旧的在前面）
    sorted_groups = sorted(file_groups.values(), key=lambda x: x['mtime'])
    
    deleted_groups = 0
    deleted_size_bytes = 0
    
    # 删除旧文件组直到满足空间需求
    for group in sorted_groups:
        # 如果当前总大小已在限制内，停止删除
        if current_total_size_bytes <= max_total_size_bytes:
            break
            
        # 记录要删除的信息
        delete_list = []
        if group['video']:
            delete_list.append(group['video']['path'])
        if group['image']:
            delete_list.append(group['image']['path'])
        if group['danmaku']:
            delete_list.append(group['danmaku']['path'])
            
        print(f"准备删除组 ({time.strftime('%Y-%m-%d %H:%M', time.localtime(group['mtime']))}):")
        for file_path in delete_list:
            print(f"  - {file_path}")
        
        # 实际执行删除或模拟删除
        if not dry_run:
            for file_path in delete_list:
                try:
                    os.remove(file_path)
                except OSError as e:
                    print(f"删除失败: {file_path}\n原因: {e}")
                    continue
        else:
            print("(模拟删除 - 实际运行不会保留)")
            
        # 更新总大小
        group_size = group['size']
        current_total_size_bytes -= group_size
        deleted_size_bytes += group_size
        deleted_groups += 1
        
        print(f"删除 {group_size/(1024**2):.2f} MB 数据\n")

    # 统计报告
    print(f"\n{'='*50}")
    print("清理操作完成")
    print(f"{'试运行模拟' if dry_run else '实际删除'}了 {deleted_groups} 个视频文件组")
    print(f"释放空间: {deleted_size_bytes/(1024**3):.2f} GB")
    print(f"当前总占用: {current_total_size_bytes/(1024**3):.2f} GB")
    
    if current_total_size_bytes > max_total_size_bytes:
        print(f"警告: 即使删除了最旧的文件，仍然超出限制 {(current_total_size_bytes - max_total_size_bytes)/ (1024**3):.2f} GB")
        print("可能需要调整保留策略或手动清理")

    print(f"{'='*50}")

# === 配置区 ===
# 录制文件根目录 (在Debian系统上的路径)
RECORDINGS_PATH = "/opt/1/录播"  # 必须修改为实际路径!

# 最大空间限制 (GB)
MAX_SIZE_GB = 90

# === 主程序 ===
if __name__ == "__main__":
    # 首次运行建议使用 dry_run=True 测试
    manage_recordings(
        recordings_root_path=RECORDINGS_PATH,
        max_total_size_gb=MAX_SIZE_GB,
        dry_run=False  # 改为 False 以实际删除文件
    )




