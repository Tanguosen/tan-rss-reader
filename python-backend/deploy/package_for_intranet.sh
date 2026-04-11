#!/bin/bash

# 一键打包内网部署包脚本

set -e

# 切换到 python-backend 根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "========================================="
echo "  打包内网部署包"
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

# 创建打包目录
PACKAGE_DIR="deploy/packages"
WORK_DIR="${PACKAGE_DIR}/tan-rss-deploy-${TIMESTAMP}"
mkdir -p "$WORK_DIR"

echo ""
echo "检查镜像..."
if ! docker images | grep -q "${IMAGE_NAME}.*${TAG}"; then
    echo "错误: 镜像 ${FULL_TAG} 不存在"
    echo ""
    echo "请先构建镜像:"
    echo "  ./build.sh ${TAG}"
    exit 1
fi

echo "平台: ${PLATFORM} (AMD64/x86_64)"

# 导出镜像
echo ""
echo "导出镜像..."
docker save -o "${WORK_DIR}/${IMAGE_NAME}.tar" "$FULL_TAG"
echo "✓ 镜像已导出"

# 复制必要文件
echo ""
echo "准备部署文件..."

# docker-compose.yml
cp docker-compose.yml "$WORK_DIR/"

# .env 文件（如果存在）
if [ -f .env ]; then
    cp .env "$WORK_DIR/"
    echo "✓ 已复制 .env"
else
    echo "⚠ 未找到 .env，将使用默认配置"
fi

# 数据库文件
if [ -f data/rss.db ]; then
    mkdir -p "$WORK_DIR/data"
    cp data/rss.db "$WORK_DIR/data/"
    echo "✓ 已复制数据库 ($(du -h data/rss.db | cut -f1))"
else
    echo "⚠ 未找到数据库文件"
fi

# 生成部署说明
cat > "$WORK_DIR/README.md" << EOF
# TAN RSS Backend 内网部署包

## 📦 包含文件

- \`${IMAGE_NAME}.tar\` - Docker 镜像
- \`docker-compose.yml\` - 服务编排配置
- \`.env\` - 环境配置（如有）
- \`data/rss.db\` - 数据库（如有）
- \`deploy.sh\` - 部署脚本

## 🚀 部署步骤

### 方式一：一键部署（推荐）

\`\`\`bash
chmod +x deploy.sh
./deploy.sh
\`\`\`

### 方式二：手动部署

\`\`\`bash
# 1. 加载镜像
docker load -i ${IMAGE_NAME}.tar

# 2. 查看镜像
docker images | grep ${IMAGE_NAME}

# 3. 启动服务
docker compose up -d

# 4. 查看状态
docker compose ps

# 5. 查看日志
docker compose logs -f
\`\`\`

## ⚙️ 配置说明

编辑 \`.env\` 文件修改配置：

\`\`\`bash
# 数据库（留空使用 SQLite）
DB_URL=""

# Redis
REDIS_URL="redis://redis:6379/0"

# Milvus
MILVUS_HOST="your-milvus-host"
MILVUS_PORT="19530"

# AI 服务
AURORA_AI_API_KEY="your-api-key"
AURORA_AI_BASE_URL="your-ai-base-url"
\`\`\`

## 🌐 访问地址

- API: http://localhost:27496
- 文档: http://localhost:27496/docs

## 🔧 常用命令

\`\`\`bash
# 查看状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 进入容器
docker exec -it tan-rss-backend /bin/bash
\`\`\`

## 📊 服务组成

- **tan-rss-backend**: FastAPI 主服务 (:27496)
- **redis**: 缓存/消息队列 (:6379)
- **celery-worker**: 后台任务处理器

## ⚠️ 注意事项

1. 确保服务器已安装 Docker 和 Docker Compose
2. 确保端口 27496 未被占用
3. 首次启动会自动创建数据库
4. 如有现有数据，data/rss.db 会被自动加载
5. 定期备份 data 目录

## 🆘 故障排查

\`\`\`bash
# 查看日志
docker compose logs -f tan-rss-backend

# 检查端口
lsof -i :27496

# 测试 API
curl http://localhost:27496/
\`\`\`

## 📞 获取帮助

如有问题，请查看完整文档或联系开发团队。
EOF

# 生成部署脚本
cat > "$WORK_DIR/deploy.sh" << 'DEPLOY_SCRIPT'
#!/bin/bash

# 内网部署脚本

set -e

echo "========================================="
echo "  TAN RSS Backend 内网部署"
echo "========================================="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "错误: Docker Compose 未安装"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 加载镜像
IMAGE_FILE=$(find "$SCRIPT_DIR" -name "*.tar" -type f | head -1)
if [ -n "$IMAGE_FILE" ]; then
    echo "加载镜像: $(basename "$IMAGE_FILE")"
    docker load -i "$IMAGE_FILE"
    echo "✓ 镜像加载完成"
else
    echo "⚠ 未找到镜像文件"
fi

echo ""

# 检查数据库
if [ -f "data/rss.db" ]; then
    echo "✓ 找到数据库: $(du -h data/rss.db | cut -f1)"
else
    echo "⚠ 未找到数据库，将创建空数据库"
fi

echo ""
echo "启动服务..."
docker compose up -d

echo ""
echo "等待服务启动..."
sleep 5

echo ""
echo "服务状态:"
docker compose ps

echo ""
if curl -s http://localhost:27496/ | grep -q "RSS Backend API is running"; then
    echo "✓ 部署成功！"
    echo ""
    echo "访问地址:"
    echo "  API: http://localhost:27496"
    echo "  文档: http://localhost:27496/docs"
else
    echo "⚠ 服务可能未正常启动"
    echo "  查看日志: docker compose logs -f"
fi
echo ""
DEPLOY_SCRIPT

chmod +x "$WORK_DIR/deploy.sh"

# 打包
echo ""
echo "打包部署包..."
PACKAGE_FILE="${PACKAGE_DIR}/tan-rss-deploy-${TIMESTAMP}.tar.gz"
cd "$PACKAGE_DIR"
tar -czf "tan-rss-deploy-${TIMESTAMP}.tar.gz" "tan-rss-deploy-${TIMESTAMP}/"

echo ""
echo "✓ 打包完成！"
echo ""
echo "部署包: ${PACKAGE_FILE}"
echo "大小: $(du -h "$PACKAGE_FILE" | cut -f1)"
echo ""

# 显示内容
echo "部署包内容:"
tar -tzf "$PACKAGE_FILE" | head -20
echo "..."
echo ""

# 清理临时目录
rm -rf "$WORK_DIR"

echo "========================================="
echo "  使用说明"
echo "========================================="
echo ""
echo "1. 传输部署包到内网服务器:"
echo "   scp ${PACKAGE_FILE} user@server:/path/to/"
echo ""
echo "2. 在内网服务器上解压并部署:"
echo "   tar -xzf tan-rss-deploy-${TIMESTAMP}.tar.gz"
echo "   cd tan-rss-deploy-${TIMESTAMP}"
echo "   chmod +x deploy.sh"
echo "   ./deploy.sh"
echo ""
echo "或直接使用部署目录:"
echo "   tar -xzf ${PACKAGE_FILE}"
echo "   cd tan-rss-deploy-${TIMESTAMP}"
echo "   # 手动加载镜像"
echo "   docker load -i ${IMAGE_NAME}.tar"
echo "   # 启动服务"
echo "   docker compose up -d"
echo ""
