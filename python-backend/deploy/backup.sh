#!/bin/bash

# 数据库备份脚本

set -e

# 切换到 python-backend 根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

BACKUP_DIR="deploy/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/rss_backup_${TIMESTAMP}.db"

echo "========================================="
echo "  数据库备份"
echo "========================================="

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 检查数据库文件
if [ ! -f data/rss.db ]; then
    echo "错误: data/rss.db 不存在"
    exit 1
fi

echo "数据库大小: $(du -h data/rss.db | cut -f1)"
echo ""

# 如果容器正在运行，先从容器复制
if docker ps | grep -q tan-rss-backend; then
    echo "容器运行中，从容器复制数据库..."
    docker exec tan-rss-backend cp /app/data/rss.db /app/data/rss_backup_temp.db
    docker cp tan-rss-backend:/app/data/rss_backup_temp.db "$BACKUP_FILE"
    docker exec tan-rss-backend rm -f /app/data/rss_backup_temp.db
else
    echo "容器未运行，直接复制本地数据库..."
    cp data/rss.db "$BACKUP_FILE"
fi

echo ""
echo "✓ 备份完成: $BACKUP_FILE"
echo "  备份大小: $(du -h "$BACKUP_FILE" | cut -f1)"
echo ""

# 显示最近的备份
echo "最近的备份文件:"
ls -lht "$BACKUP_DIR"/*.db 2>/dev/null | head -5 || echo "  无备份文件"
echo ""
