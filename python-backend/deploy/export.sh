#!/bin/bash

# 导出 Docker 镜像脚本（用于内网部署）

set -e

# 切换到 python-backend 根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "========================================="
echo "  导出 Docker 镜像（内网部署）"
echo "========================================="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

# 设置镜像名称和版本
IMAGE_NAME="tan-rss-backend"
TAG=${1:-latest}
FULL_TAG="${IMAGE_NAME}:${TAG}"
PLATFORM="linux/amd64"

# 检查镜像是否存在
if ! docker images | grep -q "${IMAGE_NAME}.*${TAG}"; then
    echo "错误: 镜像 ${FULL_TAG} 不存在"
    echo ""
    echo "请先构建镜像:"
    echo "  ./build.sh ${TAG}"
    echo "  或"
    echo "  ./deploy/deploy.sh (选择模式 3)"
    exit 1
fi

# 创建导出目录
EXPORT_DIR="deploy/exports"
mkdir -p "$EXPORT_DIR"

# 生成导出文件名
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXPORT_FILE="${EXPORT_DIR}/${IMAGE_NAME}_${TAG}_${TIMESTAMP}.tar"

echo ""
echo "镜像信息:"
docker images | grep "${IMAGE_NAME}" | grep "${TAG}"
echo ""
echo "平台: ${PLATFORM} (AMD64/x86_64)"
IMAGE_SIZE=$(docker images --format "{{.Size}}" "${FULL_TAG}")
echo "镜像大小: ${IMAGE_SIZE}"
echo ""

echo "开始导出镜像..."
echo "目标文件: ${EXPORT_FILE}"
echo ""

# 导出镜像
docker save -o "$EXPORT_FILE" "$FULL_TAG"

echo ""
echo "✓ 镜像导出完成！"
echo ""
echo "导出文件: ${EXPORT_FILE}"
echo "文件大小: $(du -h "$EXPORT_FILE" | cut -f1)"
echo ""

# 生成加载脚本
LOAD_SCRIPT="${EXPORT_DIR}/load_and_deploy.sh"
cat > "$LOAD_SCRIPT" << 'EOF'
#!/bin/bash

# 加载并部署镜像脚本（内网服务器使用）

set -e

echo "========================================="
echo "  TAN RSS Backend - 加载并部署"
echo "========================================="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "错误: Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 查找镜像文件
IMAGE_FILE=$(find "$SCRIPT_DIR" -name "tan-rss-backend_*.tar" -type f | head -1)

if [ -z "$IMAGE_FILE" ]; then
    echo "错误: 未找到镜像文件 (*.tar)"
    echo "请将导出的 .tar 文件放在此目录"
    exit 1
fi

echo "找到镜像文件: $(basename "$IMAGE_FILE")"
echo "文件大小: $(du -h "$IMAGE_FILE" | cut -f1)"
echo ""

# 加载镜像
echo "加载镜像..."
docker load -i "$IMAGE_FILE"
echo "✓ 镜像加载完成"
echo ""

# 显示加载的镜像
echo "已加载的镜像:"
docker images | grep tan-rss-backend
echo ""

# 检查配置文件
if [ ! -f "docker-compose.yml" ]; then
    echo "错误: 未找到 docker-compose.yml"
    echo "请将 docker-compose.yml 和相关配置文件放在此目录"
    exit 1
fi

# 检查数据库
if [ ! -d "data" ]; then
    echo "警告: 未找到 data 目录"
    echo "容器启动后将创建空数据库"
else
    if [ -f "data/rss.db" ]; then
        echo "✓ 找到数据库: data/rss.db ($(du -h data/rss.db | cut -f1))"
    else
        echo "⚠ data 目录存在但无数据库文件"
    fi
fi

echo ""
echo "准备部署服务..."
echo ""

# 部署服务
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
echo "测试 API..."
if curl -s http://localhost:27496/ | grep -q "RSS Backend API is running"; then
    echo "✓ API 服务运行正常"
else
    echo "⚠ API 可能未正常启动，请检查日志"
    echo "  docker compose logs -f tan-rss-backend"
fi

echo ""
echo "========================================="
echo "  部署完成！"
echo "========================================="
echo ""
echo "服务地址:"
echo "  - API: http://localhost:27496"
echo "  - 文档: http://localhost:27496/docs"
echo ""
echo "管理命令:"
echo "  查看状态: docker compose ps"
echo "  查看日志: docker compose logs -f"
echo "  停止服务: docker compose down"
echo ""
EOF

chmod +x "$LOAD_SCRIPT"

echo "已生成加载脚本: ${LOAD_SCRIPT}"
echo ""
echo "========================================="
echo "  内网部署说明"
echo "========================================="
echo ""
echo "目标平台: ${PLATFORM} (AMD64/x86_64)"
echo ""
echo "1. 将以下文件传输到内网服务器:"
echo "   - ${EXPORT_FILE}"
echo "   - ${LOAD_SCRIPT}"
echo "   - docker-compose.yml"
echo "   - .env (如有自定义配置)"
echo "   - data/rss.db (如有现有数据)"
echo ""
echo "2. 在内网服务器上执行:"
echo "   chmod +x load_and_deploy.sh"
echo "   ./load_and_deploy.sh"
echo ""
echo "传输示例:"
echo "  scp ${EXPORT_FILE} user@server:/path/to/deploy/"
echo "  scp ${LOAD_SCRIPT} user@server:/path/to/deploy/"
echo "  scp docker-compose.yml user@server:/path/to/deploy/"
echo "  scp -r data/ user@server:/path/to/deploy/"
echo ""
