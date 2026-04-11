#!/bin/bash

# TAN RSS Backend Docker 部署脚本

set -e

# 切换到 python-backend 根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "========================================="
echo "  TAN RSS Backend Docker 部署"
echo "========================================="

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "错误: Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

# 检查 .env 文件
if [ ! -f .env ]; then
    echo "警告: .env 文件不存在，将使用默认配置"
    echo "建议复制 .env.example 并修改配置"
fi

# 检查数据库文件
if [ ! -f data/rss.db ]; then
    echo "警告: data/rss.db 数据库文件不存在"
    echo "容器启动后将创建新的空数据库"
else
    echo "✓ 找到现有数据库: data/rss.db"
    echo "  数据库大小: $(du -h data/rss.db | cut -f1)"
fi

echo ""
echo "请选择部署模式:"
echo "  1) 完整部署 (Backend + Redis + Celery Worker)"
echo "  2) 仅部署 Backend"
echo "  3) 仅构建镜像"
echo ""
read -p "请选择 [1-3] (默认: 1): " -n 1 -r
echo

MODE=${REPLY:-1}

case $MODE in
    1)
        echo ""
        echo "[模式 1] 完整部署..."
        # 停止现有容器
        echo "停止现有容器..."
        docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
        
        # 构建镜像
        echo ""
        echo "构建 Docker 镜像 (平台: linux/amd64)..."
        docker compose build --build-arg BUILDPLATFORM=linux/amd64
        
        # 启动服务
        echo ""
        echo "启动所有服务..."
        docker compose up -d
        
        SERVICES="tan-rss-backend redis celery-worker"
        ;;
    2)
        echo ""
        echo "[模式 2] 仅部署 Backend..."
        # 停止现有容器
        echo "停止现有容器..."
        docker compose down tan-rss-backend 2>/dev/null || docker-compose down tan-rss-backend 2>/dev/null || true
        
        # 构建镜像
        echo ""
        echo "构建 Docker 镜像 (平台: linux/amd64)..."
        docker compose build tan-rss-backend --build-arg BUILDPLATFORM=linux/amd64
        
        # 启动服务
        echo ""
        echo "启动 Backend 服务..."
        docker compose up -d tan-rss-backend
        
        SERVICES="tan-rss-backend"
        ;;
    3)
        echo ""
        echo "[模式 3] 仅构建镜像..."
        echo "平台: linux/amd64 (AMD64/x86_64)"
        docker compose build
        echo ""
        echo "镜像构建完成！"
        echo "使用 'docker images | grep tan-rss-backend' 查看镜像"
        exit 0
        ;;
    *)
        echo "无效选择，使用默认模式 1"
        MODE=1
        echo "停止现有容器..."
        docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
        
        echo ""
        echo "构建 Docker 镜像 (平台: linux/amd64)..."
        docker compose build
        
        echo ""
        echo "启动所有服务..."
        docker compose up -d
        
        SERVICES="tan-rss-backend redis celery-worker"
        ;;
esac

# 等待服务启动
echo ""
echo "等待服务启动..."
sleep 5

# 检查服务状态
echo ""
echo "检查服务状态..."
docker compose ps 2>/dev/null || docker-compose ps

# 测试 API
if [[ "$MODE" == "1" || "$MODE" == "2" ]]; then
    echo ""
    echo "测试 API 连接..."
    if curl -s http://localhost:27496/ | grep -q "RSS Backend API is running"; then
        echo "✓ API 服务运行正常"
    else
        echo "✗ API 服务可能未正常启动，请检查日志"
        echo "  查看日志: docker compose logs -f tan-rss-backend"
    fi
fi

echo ""
echo "========================================="
echo "  部署完成！"
echo "========================================="
echo ""
echo "服务访问地址:"
echo "  - Backend API: http://localhost:27496"
echo "  - API 文档:    http://localhost:27496/docs"
echo ""
echo "常用命令:"
echo "  查看日志:     docker compose logs -f"
echo "  停止服务:     docker compose down"
echo "  重启服务:     docker compose restart"
echo "  更新数据库:   替换 data/rss.db 后重启"
echo ""

if [[ "$MODE" == "1" ]]; then
    echo "已启动服务:"
    echo "  ✓ tan-rss-backend (FastAPI)"
    echo "  ✓ redis (缓存/消息队列)"
    echo "  ✓ celery-worker (后台任务)"
    echo ""
elif [[ "$MODE" == "2" ]]; then
    echo "已启动服务:"
    echo "  ✓ tan-rss-backend (FastAPI)"
    echo ""
    echo "注意: 未启动 Redis 和 Celery Worker"
    echo "  后台任务功能将不可用"
    echo ""
fi
