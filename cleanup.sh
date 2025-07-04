#!/bin/bash

#================================================================
# 录播文件自动清理脚本 (最终版 v3)
# 1. 循环查找并删除最旧的文件，直到磁盘空间达标。
# 2. 清理过程中会排除指定的配置文件。
# 3. 操作结束后，会自动删除空的子目录。
# 4. 退出前增加延时，确保日志被完整捕获。
#================================================================

# --- 配置区 ---

# 录制文件根目录 (请务必修改为您的实际路径!)
RECORDINGS_PATH="/opt/1/录播"

# 最大空间限制 (GB)
MAX_SIZE_GB=130

# [新增] 需要在清理中排除的文件名列表，用空格隔开
# 使用通配符时需要引号，例如 "*.log"
EXCLUDE_FILES=("config.json" "config.backup.json")

# 是否为试运行模式 (dry run)
# true: 只打印要删除的文件和目录，不实际操作
# false: 真正执行删除操作
DRY_RUN=false

# --- 脚本主体 (非专业人士请勿修改以下内容) ---

# 设置脚本在遇到错误时立即退出
set -euo pipefail

# 检查路径是否存在
if [ ! -d "$RECORDINGS_PATH" ]; then
    echo "错误: 目录不存在: $RECORDINGS_PATH"
    exit 1
fi

# 将GB转换为KB，方便与`du`命令的输出进行比较
MAX_SIZE_KB=$((MAX_SIZE_GB * 1024 * 1024))

echo "================================================================"
echo "录播文件清理工具 (最终版 v3)"
echo "检查路径: $RECORDINGS_PATH"
echo "空间限制: $MAX_SIZE_GB GB (~$MAX_SIZE_KB KB)"
if [ "$DRY_RUN" = true ]; then
    echo "模式: !!! 试运行模式 - 不会删除任何文件 !!!"
else
    echo "模式: !!! 实际删除模式 - 文件将被永久移除 !!!"
fi
echo "================================================================"

# [修改] 构建 find 命令的排除参数
find_exclude_args=()
for file in "${EXCLUDE_FILES[@]}"; do
    find_exclude_args+=(-not -name "$file")
done

# 获取当前总大小 (单位: KB)
current_size_kb=$(du -sk "$RECORDINGS_PATH" | awk '{print $1}')

echo "当前总占用: $((current_size_kb / 1024)) MB"

# --- 文件清理主循环 ---
echo -e "\n--- 开始检查并清理文件 ---"
while (( current_size_kb > MAX_SIZE_KB )); do
    
    # [修改] 在查找时加入排除参数
    oldest_file=$(find "$RECORDINGS_PATH" -type f "${find_exclude_args[@]}" -printf '%T@ %p\n' | sort -n | head -1 | cut -d' ' -f2-) || true

    if [ -z "$oldest_file" ]; then
        echo "没有找到任何可删除的文件（已排除配置文件）。脚本终止。"
        break
    fi

    size_of_oldest_bytes=$(stat -c%s "$oldest_file")
    size_of_oldest_kb=$(( (size_of_oldest_bytes + 1023) / 1024 )) # 向上取整

    echo "空间超限，准备删除最旧的文件: $oldest_file (大小: ${size_of_oldest_kb}KB)"

    if [ "$DRY_RUN" = false ]; then
        rm -f "$oldest_file"
        if [ $? -eq 0 ]; then
            echo "状态: 已删除"
            current_size_kb=$((current_size_kb - size_of_oldest_kb))
        else
            echo "状态: 删除失败！"
            exit 1
        fi
    else
        echo "状态: (模拟删除)"
        current_size_kb=$((current_size_kb - size_of_oldest_kb))
    fi
    
    echo "预计剩余空间: $((current_size_kb / 1024)) MB"
done
echo "--- 文件清理完成 ---"


# --- [新增] 清理空目录步骤 ---
echo -e "\n--- 开始检查并清理空目录 ---"
if [ "$DRY_RUN" = false ]; then
    # 实际删除: -delete 选项会自动从最深的空目录开始删除
    echo "正在删除空目录..."
    find "$RECORDINGS_PATH" -mindepth 1 -type d -empty -delete -print
else
    # 模拟删除: 只打印将要被删除的空目录
    echo "以下为空目录 (模拟删除):"
    find "$RECORDINGS_PATH" -mindepth 1 -type d -empty -print
fi
echo "--- 空目录清理完成 ---"


echo -e "\n================================================================"
echo "所有操作完成。"
final_size_kb=$(du -sk "$RECORDINGS_PATH" | awk '{print $1}')
echo "最终占用: $((final_size_kb / 1024)) MB"
echo "================================================================"


# --- [新增] 退出前延时 ---
# 给予上层应用（如MCSM面板）足够的时间来捕获所有输出日志
echo -e "\n脚本将在5秒后自动退出..."
sleep 5

exit 0
