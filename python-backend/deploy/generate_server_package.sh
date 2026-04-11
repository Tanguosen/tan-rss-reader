#!/bin/bash

# 生成完整的服务器部署包
# 包含所有必需文件，确保一次性上传不缺文件

set -e

# 切换到 python-backend 根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "========================================="
echo "  生成完整服务器部署包"
echo "========================================="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

# 设置参数
IMAGE_NAME="tan-rss-backend"
TAG=${1:-latest}
FULL_TAG="${IMAGE_NAME}:${TAG}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
PLATFORM="linux/amd64"
DEPLOY_DIR="deploy/server-deploy"
PACKAGE_NAME="tan-rss-server-${TIMESTAMP}"
FULL_PACKAGE_DIR="${DEPLOY_DIR}/${PACKAGE_NAME}"

# Docker Compose 构建的镜像名称可能带有项目前缀
COMPOSE_IMAGE_NAME="python-backend-tan-rss-backend"

# 创建部署目录
mkdir -p "$FULL_PACKAGE_DIR"

echo ""
echo "目标目录: ${FULL_PACKAGE_DIR}"
echo "平台: ${PLATFORM} (AMD64/x86_64)"
echo ""

# 1. 检查并导出镜像
echo "[1/7] 检查 Docker 镜像..."
# 尝试多种镜像名称
IMAGE_TO_USE=""

# 尝试 1: 标准名称 tan-rss-backend:latest
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${FULL_TAG}$"; then
    IMAGE_TO_USE="${FULL_TAG}"
    echo "找到镜像: ${IMAGE_TO_USE}"
# 尝试 2: Docker Compose 名称 python-backend-tan-rss-backend:latest
elif docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${COMPOSE_IMAGE_NAME}:${TAG}$"; then
    IMAGE_TO_USE="${COMPOSE_IMAGE_NAME}:${TAG}"
    echo "使用 Docker Compose 构建的镜像: ${IMAGE_TO_USE}"
# 尝试 3: 任意包含 tan-rss-backend 的镜像
else
    IMAGE_TO_USE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "tan-rss-backend" | head -1)
    if [ -z "$IMAGE_TO_USE" ]; then
        echo "错误: 未找到 tan-rss-backend 镜像"
        echo ""
        echo "请先构建镜像:"
        echo "  ./build.sh ${TAG}"
        echo "  或"
        echo "  docker compose build"
        exit 1
    fi
    echo "找到镜像: ${IMAGE_TO_USE}"
fi

echo "导出镜像..."
docker save -o "${FULL_PACKAGE_DIR}/${IMAGE_NAME}.tar" "$IMAGE_TO_USE"
echo "✓ 镜像已导出: ${IMAGE_NAME}.tar ($(du -h "${FULL_PACKAGE_DIR}/${IMAGE_NAME}.tar" | cut -f1))"

# 2. 复制 docker-compose.yml
echo ""
echo "[2/7] 复制并修改 docker-compose.yml..."
# 复制原始文件
cp docker-compose.yml "${FULL_PACKAGE_DIR}/docker-compose.yml.original"

# 获取实际使用的镜像名称（去掉标签部分）
ACTUAL_IMAGE_NAME=$(echo "$IMAGE_TO_USE" | cut -d: -f1)
IMAGE_TAG=$(echo "$IMAGE_TO_USE" | cut -d: -f2)

echo "使用镜像: ${ACTUAL_IMAGE_NAME}:${IMAGE_TAG}"

# 生成服务器使用的 docker-compose.yml（使用镜像而不是构建）
cat > "${FULL_PACKAGE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  tan-rss-backend:
    image: ${ACTUAL_IMAGE_NAME}:${IMAGE_TAG}
    container_name: tan-rss-backend
    ports:
      - "27496:27496"
    environment:
      - DB_URL=\${DB_URL:-}
      - REDIS_URL=\${REDIS_URL:-redis://redis:6379/0}
      - MILVUS_HOST=\${MILVUS_HOST:-localhost}
      - MILVUS_PORT=\${MILVUS_PORT:-19530}
      - MILVUS_COLLECTION=\${MILVUS_COLLECTION:-rss_entries}
      - AURORA_AI_API_KEY=\${AURORA_AI_API_KEY:-}
      - AURORA_AI_BASE_URL=\${AURORA_AI_BASE_URL:-http://localhost:9997/v1}
      - AURORA_AI_MODEL=\${AURORA_AI_MODEL:-qwen3}
      - AURORA_AI_EMBEDDING_BASE_URL=\${AURORA_AI_EMBEDDING_BASE_URL:-http://localhost:9997/v1}
      - AURORA_AI_EMBEDDING_MODEL=\${AURORA_AI_EMBEDDING_MODEL:-Qwen3-Embedding-0.6B}
      - HOST=0.0.0.0
      - PORT=27496
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    restart: unless-stopped
    networks:
      - rss-network

  # 可选：Redis 服务（Celery 任务队列需要）
  redis:
    image: redis:7-alpine
    container_name: tan-rss-redis
    # 不暴露端口到宿主机，只供容器内部使用
    # ports:
    #   - "6379:6379"
    volumes:
      - redis-data:/data
    restart: unless-stopped
    networks:
      - rss-network

  # 可选：Celery Worker 服务（后台任务处理）
  celery-worker:
    image: ${ACTUAL_IMAGE_NAME}:${IMAGE_TAG}
    container_name: tan-rss-celery-worker
    command: celery -A app.celery_app worker --loglevel=info
    environment:
      - DB_URL=\${DB_URL:-}
      - REDIS_URL=\${REDIS_URL:-redis://redis:6379/0}
      - MILVUS_HOST=\${MILVUS_HOST:-localhost}
      - MILVUS_PORT=\${MILVUS_PORT:-19530}
      - MILVUS_COLLECTION=\${MILVUS_COLLECTION:-rss_entries}
      - AURORA_AI_API_KEY=\${AURORA_AI_API_KEY:-}
      - AURORA_AI_BASE_URL=\${AURORA_AI_BASE_URL:-http://localhost:9997/v1}
      - AURORA_AI_MODEL=\${AURORA_AI_MODEL:-qwen3}
      - AURORA_AI_EMBEDDING_BASE_URL=\${AURORA_AI_EMBEDDING_BASE_URL:-http://localhost:9997/v1}
      - AURORA_AI_EMBEDDING_MODEL=\${AURORA_AI_EMBEDDING_MODEL:-Qwen3-Embedding-0.6B}
    volumes:
      - ./data:/app/data
    depends_on:
      - redis
      - tan-rss-backend
    restart: unless-stopped
    networks:
      - rss-network

volumes:
  redis-data:

networks:
  rss-network:
    driver: bridge
EOF

echo "✓ docker-compose.yml 已生成（使用镜像: ${ACTUAL_IMAGE_NAME}:${IMAGE_TAG}）"

# 3. 复制 .env 文件
echo ""
echo "[3/7] 复制环境配置..."
if [ -f .env ]; then
    cp .env "${FULL_PACKAGE_DIR}/"
    echo "✓ .env 已复制"
else
    echo "⚠ .env 不存在，创建示例配置..."
    cat > "${FULL_PACKAGE_DIR}/.env" << 'EOF'
# ==========================================
# TAN RSS Backend Configuration
# ==========================================

# Database (留空使用 SQLite)
DB_URL=""

# Redis (使用本地容器)
REDIS_URL="redis://redis:6379/0"

# Vector Database (Milvus)
MILVUS_HOST="localhost"
MILVUS_PORT="19530"
MILVUS_COLLECTION="rss_entries"

# Default AI Services
AURORA_AI_API_KEY=""
AURORA_AI_BASE_URL="http://localhost:9997/v1"
AURORA_AI_MODEL="qwen3"
AURORA_AI_EMBEDDING_BASE_URL="http://localhost:9997/v1"
AURORA_AI_EMBEDDING_MODEL="Qwen3-Embedding-0.6B"

# Backend Server
HOST="0.0.0.0"
PORT="27496"
EOF
    echo "✓ 已创建 .env 示例文件（请根据实际情况修改）"
fi

# 4. 复制数据库
echo ""
echo "[4/7] 复制数据库..."
if [ -f data/rss.db ]; then
    mkdir -p "${FULL_PACKAGE_DIR}/data"
    cp data/rss.db "${FULL_PACKAGE_DIR}/data/"
    echo "✓ 数据库已复制: data/rss.db ($(du -h data/rss.db | cut -f1))"
else
    mkdir -p "${FULL_PACKAGE_DIR}/data"
    echo "⚠ 数据库文件不存在，将创建空 data 目录"
    echo "  容器启动后会自动创建数据库"
fi

# 5. 创建部署脚本
echo ""
echo "[5/7] 创建部署脚本..."
cat > "${FULL_PACKAGE_DIR}/deploy.sh" << 'DEPLOY_SCRIPT'
#!/bin/bash

# TAN RSS Backend 服务器部署脚本

set -e

echo "========================================="
echo "  TAN RSS Backend 服务器部署"
echo "========================================="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装，请先安装 Docker"
    echo ""
    echo "安装命令 (Ubuntu/Debian):"
    echo "  sudo apt update"
    echo "  sudo apt install docker.io docker-compose"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "错误: Docker Compose 未安装"
    echo ""
    echo "安装命令:"
    echo "  sudo apt install docker-compose"
    exit 1
fi

# 检查架构
ARCH=$(uname -m)
echo "检查架构: ${ARCH}"
if [ "$ARCH" != "x86_64" ]; then
    echo "⚠️  警告: 当前架构 ${ARCH} 不是 AMD64 (x86_64)"
    echo "  可能导致镜像无法运行"
    echo ""
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✓ 架构兼容: AMD64 (x86_64)"
fi

# 加载镜像
echo ""
echo "加载 Docker 镜像..."
IMAGE_FILE=$(find "$SCRIPT_DIR" -name "tan-rss-backend.tar" -type f | head -1)
if [ -z "$IMAGE_FILE" ]; then
    echo "错误: 未找到镜像文件 tan-rss-backend.tar"
    exit 1
fi

docker load -i "$IMAGE_FILE"
echo "✓ 镜像加载完成"

# 显示镜像
echo ""
echo "已加载的镜像:"
docker images | grep tan-rss-backend

# 检查数据库
echo ""
if [ -f "data/rss.db" ]; then
    echo "✓ 找到数据库: data/rss.db ($(du -h data/rss.db | cut -f1))"
else
    echo "⚠ 未找到数据库，启动时将自动创建"
fi

# 启动服务
echo ""
echo "启动服务..."
docker compose up -d

echo ""
echo "等待服务启动..."
sleep 5

# 检查状态
echo ""
echo "服务状态:"
docker compose ps

# 测试 API
echo ""
echo "测试 API 连接..."
if curl -s http://localhost:27496/ | grep -q "RSS Backend API is running"; then
    echo "✓ API 服务运行正常"
else
    echo "⚠ API 可能未正常启动"
    echo "  查看日志: docker compose logs -f tan-rss-backend"
fi

echo ""
echo "========================================="
echo "  部署完成！"
echo "========================================="
echo ""
echo "服务地址:"
echo "  API: http://localhost:27496"
echo "  文档: http://localhost:27496/docs"
echo ""
echo "管理命令:"
echo "  查看状态: docker compose ps"
echo "  查看日志: docker compose logs -f"
echo "  重启服务: docker compose restart"
echo "  停止服务: docker compose down"
echo ""
DEPLOY_SCRIPT

chmod +x "${FULL_PACKAGE_DIR}/deploy.sh"
echo "✓ deploy.sh 已创建"

# 6. 创建管理脚本
echo ""
echo "[6/7] 创建管理脚本..."
cat > "${FULL_PACKAGE_DIR}/manage.sh" << 'MANAGE_SCRIPT'
#!/bin/bash

# 服务管理脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
    echo "========================================="
    echo "  TAN RSS Backend 服务管理"
    echo "========================================="
    echo ""
    echo "用法: ./manage.sh <命令>"
    echo ""
    echo "命令:"
    echo "  start       - 启动服务"
    echo "  stop        - 停止服务"
    echo "  restart     - 重启服务"
    echo "  status      - 查看状态"
    echo "  logs        - 查看所有日志"
    echo "  logs-backend - 查看 Backend 日志"
    echo "  logs-redis  - 查看 Redis 日志"
    echo "  logs-worker - 查看 Celery Worker 日志"
    echo "  clean       - 停止并删除容器"
    echo "  shell       - 进入 Backend 容器"
    echo "  db-shell    - 进入数据库 Shell"
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
MANAGE_SCRIPT

chmod +x "${FULL_PACKAGE_DIR}/manage.sh"
echo "✓ manage.sh 已创建"

# 7. 创建 README
echo ""
echo "[7/7] 创建部署说明..."
cat > "${FULL_PACKAGE_DIR}/README.md" << EOF
# TAN RSS Backend 服务器部署包

## 📦 包含文件

- \`tan-rss-backend.tar\` - Docker 镜像 ($(du -h "${FULL_PACKAGE_DIR}/${IMAGE_NAME}.tar" | cut -f1))
- \`docker-compose.yml\` - 服务编排配置
- \`.env\` - 环境配置
- \`data/rss.db\` - 数据库 $([ -f data/rss.db ] && echo "($(du -h data/rss.db | cut -f1))" || echo "(将自动创建)")
- \`deploy.sh\` - 一键部署脚本
- \`manage.sh\` - 服务管理脚本
- \`README.md\` - 本文件

## 🖥️ 系统要求

- **架构**: AMD64 (x86_64) ⚠️ 重要
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **内存**: 建议 2GB+
- **磁盘**: 建议 5GB+

## 🚀 快速部署

### 一键部署（推荐）

\`\`\`bash
chmod +x deploy.sh
./deploy.sh
\`\`\`

### 手动部署

\`\`\`bash
# 1. 加载镜像
docker load -i tan-rss-backend.tar

# 2. 启动服务
docker compose up -d

# 3. 查看状态
docker compose ps

# 4. 查看日志
docker compose logs -f
\`\`\`

## ⚙️ 配置说明

编辑 \`.env\` 文件：

\`\`\`bash
# 数据库（留空使用 SQLite）
DB_URL=""

# Redis（使用本地容器）
REDIS_URL="redis://redis:6379/0"

# Milvus（如果内网有 Milvus）
MILVUS_HOST="your-milvus-host"
MILVUS_PORT="19530"

# AI 服务（如果内网有 AI 服务）
AURORA_AI_API_KEY="your-api-key"
AURORA_AI_BASE_URL="http://your-ai-host:9997/v1"
\`\`\`

## 🌐 访问地址

- **API**: http://localhost:27496
- **文档**: http://localhost:27496/docs

## 🔧 服务管理

使用 \`manage.sh\` 脚本：

\`\`\`bash
./manage.sh start        # 启动
./manage.sh stop         # 停止
./manage.sh restart      # 重启
./manage.sh status       # 状态
./manage.sh logs         # 日志
./manage.sh shell        # 进入容器
./manage.sh db-shell     # 数据库 Shell
\`\`\`

## 📊 服务组成

- **tan-rss-backend**: FastAPI 主服务 (:27496)
- **redis**: 缓存/消息队列 (:6379)
- **celery-worker**: 后台任务处理器

## 📝 注意事项

1. 确保服务器是 AMD64 (x86_64) 架构
2. 首次启动会自动创建数据库
3. 定期备份 \`data/\` 目录
4. 修改配置后需要重启: \`./manage.sh restart\`

## 🆘 故障排查

\`\`\`bash
# 查看详细日志
./manage.sh logs-backend

# 检查端口
lsof -i :27496

# 测试 API
curl http://localhost:27496/
\`\`\`

---

生成时间: $(date +"%Y-%m-%d %H:%M:%S")
镜像版本: ${TAG}
平台: ${PLATFORM}
EOF

echo "✓ README.md 已创建"

# 显示总结
echo ""
echo "========================================="
echo "  部署包生成完成！"
echo "========================================="
echo ""
echo "部署包位置: ${FULL_PACKAGE_DIR}"
echo ""
echo "文件列表:"
ls -lh "${FULL_PACKAGE_DIR}/"
echo ""
echo "总大小: $(du -sh "${FULL_PACKAGE_DIR}" | cut -f1)"
echo ""

# 自动打包到 server-deploy 目录
echo "正在打包..."
cd "${DEPLOY_DIR}"
tar -czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}/"
echo "✓ 打包完成: ${DEPLOY_DIR}/${PACKAGE_NAME}.tar.gz"
echo "  压缩包大小: $(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""

# 显示上传命令
echo "========================================="
echo "  上传到服务器"
echo "========================================="
echo ""
echo "方式 1: 上传压缩包（推荐）"
echo "  scp ${DEPLOY_DIR}/${PACKAGE_NAME}.tar.gz user@server:/opt/"
echo ""
echo "方式 2: 直接上传目录"
echo "  scp -r ${FULL_PACKAGE_DIR} user@server:/opt/"
echo ""
echo "方式 3: 使用 rsync"
echo "  rsync -avz ${FULL_PACKAGE_DIR}/ user@server:/opt/tan-rss/"
echo ""
echo "========================================="
echo "  服务器端部署"
echo "========================================="
echo ""
echo "# 如果使用压缩包"
echo "tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "cd ${PACKAGE_NAME}"
echo ""
echo "# 一键部署"
echo "chmod +x deploy.sh"
echo "./deploy.sh"
echo ""
