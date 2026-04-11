#!/bin/bash

# 数据库恢复脚本

set -e

# 切换到 python-backend 根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "========================================="
echo "  数据库恢复"
echo "========================================="

BACKUP_DIR="deploy/backups"

# 检查备份目录
if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.db 2>/dev/null)" ]; then
    echo "错误: 备份目录中没有找到备份文件"
    exit 1
fi

# 显示可用的备份文件
echo "可用的备份文件:"
echo ""
ls -lht "$BACKUP_DIR"/*.db | head -10
echo ""

# 选择备份文件
echo "请选择要恢复的备份:"
echo "  1) 最新的备份"
echo "  2) 选择特定文件"
echo ""
read -p "请选择 [1-2] (默认: 1): " -n 1 -r
echo

if [[ $REPLY =~ ^[2]$ ]]; then
    echo ""
    echo "输入备份文件路径 (或直接输入文件名):"
    read -p "> " BACKUP_FILE
    
    if [[ ! "$BACKUP_FILE" == /* ]]; then
        BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILE}"
    fi
else
    BACKUP_FILE=$(ls -t "$BACKUP_DIR"/*.db | head -1)
fi

# 验证文件
if [ ! -f "$BACKUP_FILE" ]; then
    echo "错误: 文件不存在: $BACKUP_FILE"
    exit 1
fi

echo ""
echo "准备恢复数据库: $BACKUP_FILE"
echo "备份大小: $(du -h "$BACKUP_FILE" | cut -f1)"
echo ""

# 确认恢复
read -p "⚠ 警告: 这将覆盖现有数据库！是否继续？(y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消恢复"
    exit 0
fi

# 备份当前数据库
if [ -f data/rss.db ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    CURRENT_BACKUP="data/rss.db.backup_${TIMESTAMP}"
    echo ""
    echo "备份当前数据库..."
    cp data/rss.db "$CURRENT_BACKUP"
    echo "✓ 当前数据库已备份到: $CURRENT_BACKUP"
fi

# 恢复数据库
echo ""
echo "恢复数据库..."
cp "$BACKUP_FILE" data/rss.db
echo "✓ 数据库已恢复"

# 如果容器正在运行，重启以应用更改
if docker ps | grep -q tan-rss-backend; then
    echo ""
    echo "容器正在运行，重启服务以应用更改..."
    cd "$PROJECT_DIR"
    docker compose restart tan-rss-backend
    echo "✓ 服务已重启"
fi

echo ""
echo "========================================="
echo "  恢复完成！"
echo "========================================="
echo ""
