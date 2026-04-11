#!/bin/bash

# 服务管理脚本

set -e

# 切换到 python-backend 根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

show_help() {
    echo "========================================="
    echo "  TAN RSS Backend 服务管理"
    echo "========================================="
    echo ""
    echo "用法: ./manage.sh <命令>"
    echo ""
    echo "命令:"
    echo "  start       - 启动所有服务"
    echo "  stop        - 停止所有服务"
    echo "  restart     - 重启所有服务"
    echo "  status      - 查看服务状态"
    echo "  logs        - 查看所有日志"
    echo "  logs-backend - 查看 Backend 日志"
    echo "  logs-redis  - 查看 Redis 日志"
    echo "  logs-worker - 查看 Celery Worker 日志"
    echo "  clean       - 停止并删除容器"
    echo "  rebuild     - 重新构建并启动"
    echo "  shell       - 进入 Backend 容器"
    echo "  db-shell    - 进入数据库 SQLite Shell"
    echo ""
}

case "${1}" in
    start)
        echo "启动服务..."
        docker compose up -d
        echo "✓ 服务已启动"
        docker compose ps
        ;;
    stop)
        echo "停止服务..."
        docker compose stop
        echo "✓ 服务已停止"
        ;;
    restart)
        echo "重启服务..."
        docker compose restart
        echo "✓ 服务已重启"
        ;;
    status)
        echo "服务状态:"
        docker compose ps
        ;;
    logs)
        docker compose logs -f
        ;;
    logs-backend)
        docker compose logs -f tan-rss-backend
        ;;
    logs-redis)
        docker compose logs -f redis
        ;;
    logs-worker)
        docker compose logs -f celery-worker
        ;;
    clean)
        echo "清理容器..."
        docker compose down
        echo "✓ 容器已清理"
        ;;
    rebuild)
        echo "重新构建镜像..."
        docker compose build --no-cache
        echo ""
        echo "启动服务..."
        docker compose up -d
        echo "✓ 重建完成"
        ;;
    shell)
        echo "进入 Backend 容器..."
        docker exec -it tan-rss-backend /bin/bash
        ;;
    db-shell)
        echo "进入数据库 SQLite Shell..."
        docker exec -it tan-rss-backend sqlite3 /app/data/rss.db
        ;;
    *)
        show_help
        exit 1
        ;;
esac
