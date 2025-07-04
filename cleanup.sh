#!/bin/bash

#================================================================
# 录播文件自动清理脚本 (最终版 v6 - 混合单位)
# 1. 宏观统计使用GB，单个文件删除时使用MB。
# 2. 清理过程中会排除指定的配置文件。
# 3. 操作结束后，会自动删除空的子目录。
# 4. 退出前增加延时，确保日志被完整捕获。
# 5. 增加了对find命令错误的容错，防止脚本意外退出。
#================================================================

# --- 配置区 ---

# 录制文件根目录 (请务必修改为您的实际路径!)
RECORDINGS_PATH="/opt/1/录播"

# 最大空间限制 (GB)
MAX_SIZE_GB=130

# 需要在清理中排除的文件名列表，用空格隔开
EXCLUDE_FILES=("config.json" "config.backup.json")

# 是否为试运行模式 (dry run)
DRY_RUN=false

# --- 脚本主体 (非专业人士请勿修改以下内容) ---

# 设置脚本在遇到错误时立即退出
set -euo pipefail

# 检查 bc 命令是否存在
if ! command -v bc &> /dev/null
then
    echo "错误: 本脚本需要 'bc' 命令来进行浮点数计算，但系统中未找到。"
    echo "请使用 'sudo apt-get install bc' 或 'sudo yum install bc' 安装它。"
    exit 1
fi

# 检查路径是否存在
if [ ! -d "$RECORDINGS_PATH" ]; then
    echo "错误: 目录不存在: $RECORDINGS_PATH"
    exit 1
fi

echo "================================================================"
echo "录播文件清理工具 (最终版 v6 - 混合单位)"
echo "检查路径: $RECORDINGS_PATH"
echo "空间限制: $MAX_SIZE_GB GB"
if [ "$DRY_RUN" = true ]; then
    echo "模式: !!! 试运行模式 - 不会删除任何文件 !!!"
else
    echo "模式: !!! 实际删除模式 - 文件将被永久移除 !!!"
fi
echo "================================================================"

# 构建 find 命令的排除参数
find_exclude_args=()
for file in "${EXCLUDE_FILES[@]}"; do
    find_exclude_args+=(-not -name "$file")
done

# 获取当前总大小 (单位: KB)
current_size_kb=$(du -sk "$RECORDINGS_PATH" | awk '{print $1}')
MAX_SIZE_KB=$((MAX_SIZE_GB * 1024 * 1024))

# 使用 bc 将KB转换为GB进行显示 (宏观)
current_size_gb=$(echo "scale=2; $current_size_kb / 1024 / 1024" | bc)
echo "当前总占用: $current_size_gb GB"

# --- 文件清理主循环 ---
echo -e "\n--- 开始检查并清理文件 ---"
while (( current_size_kb > MAX_SIZE_KB )); do
    
    oldest_file=$(find "$RECORDINGS_PATH" -type f "${find_exclude_args[@]}" -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2-) || true

    if [ -z "$oldest_file" ]; then
        echo "没有找到任何可删除的文件（已排除配置文件或遇到权限问题）。"
        break
    fi

    size_of_oldest_bytes=$(stat -c%s "$oldest_file")
    size_of_oldest_kb=$(( (size_of_oldest_bytes + 1023) / 1024 ))
    
    # [修改] 使用 bc 将被删除文件的大小转换为MB显示 (微观)
    size_of_oldest_mb=$(echo "scale=2; $size_of_oldest_kb / 1024" | bc)

    echo "空间超限，准备删除最旧的文件: $oldest_file (大小: ${size_of_oldest_mb} MB)"

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
    
    # 使用 bc 计算并显示预计剩余空间的GB值 (宏观)
    remaining_gb=$(echo "scale=2; $current_size_kb / 1024 / 1024" | bc)
    echo "预计剩余空间: $remaining_gb GB"
done
echo "--- 文件清理完成 ---"


# --- 清理空目录步骤 ---
echo -e "\n--- 开始检查并清理空目录 ---"
if [ "$DRY_RUN" = false ]; then
    echo "正在删除空目录..."
    find "$RECORDINGS_PATH" -mindepth 1 -type d -empty -delete -print
else
    echo "以下为空目录 (模拟删除):"
    find "$RECORDINGS_PATH" -mindepth 1 -type d -empty -print
fi
echo "--- 空目录清理完成 ---"


echo -e "\n================================================================"
echo "所有操作完成。"
# 使用 bc 计算并显示最终占用的GB值 (宏观)
final_size_kb=$(du -sk "$RECORDINGS_PATH" | awk '{print $1}')
final_size_gb=$(echo "scale=2; $final_size_kb / 1024 / 1024" | bc)
echo "最终占用: $final_size_gb GB"
echo "================================================================"


# --- 退出前延时 ---
echo -e "\n脚本将在5秒后自动退出..."
sleep 5

exit 0
