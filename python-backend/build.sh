#!/bin/bash

# 构建 Docker 镜像脚本

set -e

echo "========================================="
echo "  构建 TAN RSS Backend Docker 镜像"
echo "========================================="

# 切换到 python-backend 目录
cd "$(dirname "$0")"

# 检查数据库文件
if [ ! -f data/rss.db ]; then
    echo "⚠ 警告: data/rss.db 数据库文件不存在"
    echo "  镜像将不包含数据库，启动时会创建空数据库"
    read -p "是否继续构建？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "取消构建"
        exit 1
    fi
else
    DB_SIZE=$(du -h data/rss.db | cut -f1)
    echo "✓ 找到数据库文件: data/rss.db ($DB_SIZE)"
fi

# 设置镜像标签
IMAGE_NAME="tan-rss-backend"
TAG=${1:-latest}
FULL_TAG="${IMAGE_NAME}:${TAG}"

echo ""
echo "开始构建镜像: ${FULL_TAG}"
echo "平台: linux/amd64 (AMD64/x86_64)"
echo "⚠️  注意: 在 Apple Silicon Mac 上会使用 Rosetta 2 模拟构建"
echo ""

# 构建镜像（指定 AMD64 平台）
echo "正在构建 AMD64 架构镜像..."
docker build --platform linux/amd64 -t "${FULL_TAG}" .

echo ""
echo "========================================="
echo "  构建完成！"
echo "========================================="
echo ""
echo "镜像信息:"
docker images | grep "${IMAGE_NAME}" | grep "${TAG}"
echo ""
echo "运行镜像:"
echo "  docker run -d -p 27496:27496 --name tan-rss-backend ${FULL_TAG}"
echo ""
echo "或使用部署脚本:"
echo "  ./deploy/deploy.sh"
echo ""
