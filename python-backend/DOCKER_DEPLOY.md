# TAN RSS Backend Docker 部署指南

## 📦 文件说明

### 核心文件
- `Dockerfile` - Docker 镜像构建文件
- `docker-compose.yml` - Docker Compose 编排文件（包含 Backend、Redis、Celery Worker）
- `.dockerignore` - Docker 构建排除文件
- `data/rss.db` - SQLite 数据库文件（62MB，已包含现有数据）

### 部署脚本 (deploy/)
- `deploy/deploy.sh` - 一键部署脚本（支持多种部署模式）
- `deploy/manage.sh` - 服务管理脚本（启动/停止/日志等）
- `deploy/backup.sh` - 数据库备份脚本
- `deploy/restore.sh` - 数据库恢复脚本
- `deploy/export.sh` - 导出 Docker 镜像（内网部署）
- `deploy/package_for_intranet.sh` - 打包完整内网部署包
- `build.sh` - 镜像构建脚本（根目录）

## 🚀 快速开始

### 方式一：一键部署（推荐）

```bash
cd python-backend
./deploy/deploy.sh
```

部署脚本提供 3 种模式：
- **模式 1**: 完整部署 (Backend + Redis + Celery Worker)
- **模式 2**: 仅部署 Backend
- **模式 3**: 仅构建镜像

### 方式二：分步部署

#### 1. 构建镜像

```bash
cd python-backend
./build.sh
# 或指定版本标签
./build.sh v1.0.0
```

#### 2. 启动服务

```bash
# 使用部署脚本（推荐）
./deploy/deploy.sh

# 或使用 Docker Compose 启动所有服务（Backend + Redis + Celery Worker）
docker compose up -d

# 或仅启动 Backend
docker compose up -d tan-rss-backend
```

## ⚙️ 配置说明

### 环境变量配置

编辑 `.env` 文件或直接修改 `docker-compose.yml` 中的环境变量：

```bash
# 数据库配置（留空使用 SQLite）
DB_URL=""

# Redis 配置
REDIS_URL="redis://redis:6379/0"

# Milvus 向量数据库
MILVUS_HOST="10.110.3.25"
MILVUS_PORT="19530"

# AI 服务配置
AURORA_AI_API_KEY=""
AURORA_AI_BASE_URL="http://10.110.3.61:9997/v1"
AURORA_AI_MODEL="qwen3"
AURORA_AI_EMBEDDING_BASE_URL="http://10.110.3.61:9997/v1"
AURORA_AI_EMBEDDING_MODEL="Qwen3-Embedding-0.6B"
```

### 数据库迁移

现有数据库 `data/rss.db` 已自动包含在镜像中。

**更新数据库：**
```bash
# 方式 1: 替换数据库文件后重启
cp /path/to/new/rss.db data/rss.db
./deploy/manage.sh restart

# 方式 2: 使用恢复脚本
./deploy/restore.sh

# 方式 3: 使用 volume 挂载（推荐用于频繁更新）
# docker-compose.yml 中已配置 volume 挂载
```

## 🔧 服务管理

使用 `deploy/manage.sh` 脚本管理服务：

```bash
# 启动服务
./deploy/manage.sh start

# 停止服务
./deploy/manage.sh stop

# 重启服务
./deploy/manage.sh restart

# 查看状态
./deploy/manage.sh status

# 查看日志
./deploy/manage.sh logs           # 所有服务
./deploy/manage.sh logs-backend   # Backend 日志
./deploy/manage.sh logs-redis     # Redis 日志
./deploy/manage.sh logs-worker    # Celery Worker 日志

# 进入容器
./deploy/manage.sh shell          # 进入 Backend 容器
./deploy/manage.sh db-shell       # 进入数据库 SQLite Shell

# 重新构建
./deploy/manage.sh rebuild

# 清理容器
./deploy/manage.sh clean
```

## 💾 数据库管理

### 备份数据库

```bash
./deploy/backup.sh
```

备份文件保存在 `deploy/backups/` 目录，文件名格式：`rss_backup_YYYYMMDD_HHMMSS.db`

### 恢复数据库

```bash
./deploy/restore.sh
```

支持：
- 自动恢复最新备份
- 手动选择特定备份文件
- 恢复前自动备份当前数据库

## 📊 服务架构

```
┌─────────────────┐
│  tan-rss-backend│ :27496
│   (FastAPI)     │
└────────┬────────┘
         │
         ├───┐
         │   ▼
         │ ┌──────────┐
         │ │  Redis   │ :6379
         │ └────┬─────┘
         │      │
         │      ▼
         │ ┌──────────────┐
         └─│ Celery Worker│
           └──────────────┘
```

## 🔧 常用命令

## 🌐 内网部署

### 方式一：导出镜像（推荐）

#### 1. 在有外网的服务器上导出镜像

```bash
cd python-backend

# 导出镜像
./deploy/export.sh
# 或指定版本
./deploy/export.sh v1.0.0
```

导出文件：
- `deploy/exports/tan-rss-backend_latest_YYYYMMDD_HHMMSS.tar` - Docker 镜像
- `deploy/exports/load_and_deploy.sh` - 加载并部署脚本

#### 2. 传输到内网服务器

```bash
# 传输镜像和脚本
scp deploy/exports/tan-rss-backend_*.tar user@intranet-server:/path/to/deploy/
scp deploy/exports/load_and_deploy.sh user@intranet-server:/path/to/deploy/
scp docker-compose.yml user@intranet-server:/path/to/deploy/
scp .env user@intranet-server:/path/to/deploy/  # 如有自定义配置
scp -r data/ user@intranet-server:/path/to/deploy/  # 如有现有数据
```

#### 3. 在内网服务器上部署

```bash
cd /path/to/deploy/
chmod +x load_and_deploy.sh
./load_and_deploy.sh
```

### 方式二：一键打包（最简单）

#### 1. 打包完整部署包

```bash
cd python-backend

# 一键打包（包含镜像、配置、数据库）
./deploy/package_for_intranet.sh
# 或指定版本
./deploy/package_for_intranet.sh v1.0.0
```

生成文件：
- `deploy/packages/tan-rss-deploy-YYYYMMDD_HHMMSS.tar.gz` - 完整部署包

#### 2. 传输到内网服务器

```bash
# 只需传输一个文件
scp deploy/packages/tan-rss-deploy-*.tar.gz user@intranet-server:/path/to/
```

#### 3. 在内网服务器上部署

```bash
# 解压
tar -xzf tan-rss-deploy-*.tar.gz
cd tan-rss-deploy-*/

# 一键部署
chmod +x deploy.sh
./deploy.sh
```

### 内网服务器要求

- **架构**: AMD64 (x86_64) ⚠️ 重要
- Docker 20.10+
- Docker Compose 2.0+
- 端口 27496 可用
- 内存建议 2GB+
- 磁盘空间建议 5GB+

### 内网环境配置

编辑 `.env` 文件，确保服务地址正确：

```bash
# 数据库（内网 SQLite）
DB_URL=""

# Redis（使用本地容器）
REDIS_URL="redis://redis:6379/0"

# Milvus（如果内网有 Milvus）
MILVUS_HOST="your-internal-milvus-host"
MILVUS_PORT="19530"

# AI 服务（如果内网有 AI 服务）
AURORA_AI_API_KEY="your-api-key"
AURORA_AI_BASE_URL="http://your-internal-ai:9997/v1"
AURORA_AI_MODEL="qwen3"
```

如果没有 Milvus 或 AI 服务，相关功能将不可用，但 RSS 核心功能正常。

## 🌐 访问地址

- **API 服务**: http://localhost:27496
- **API 文档**: http://localhost:27496/docs
- **健康检查**: http://localhost:27496/

## 🔐 生产环境部署建议

### 1. 修改默认配置
- 修改端口映射（避免使用默认端口）
- 设置强密码和 API Key
- 配置防火墙规则

### 2. 数据持久化
```yaml
volumes:
  - /path/to/host/data:/app/data
  - /path/to/host/logs:/app/logs
```

### 3. 使用外部数据库（可选）
```bash
DB_URL="postgresql+asyncpg://user:password@host:5432/tan_rss"
```

### 4. Nginx 反向代理
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:27496;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 5. HTTPS 配置
使用 Let's Encrypt 或其他 SSL 证书：
```bash
certbot --nginx -d your-domain.com
```

## 🐛 故障排查

### 容器无法启动
```bash
# 查看详细日志
./deploy/manage.sh logs-backend

# 或使用 Docker 命令
docker compose logs tan-rss-backend

# 检查端口占用
lsof -i :27496
```

### 数据库问题
```bash
# 检查数据库文件权限
ls -la data/rss.db

# 进入容器检查
./deploy/manage.sh shell
ls -la /app/data/

# 直接查看数据库
./deploy/manage.sh db-shell
```

### Redis 连接失败
```bash
# 检查 Redis 服务
./deploy/manage.sh status

# 查看 Redis 日志
./deploy/manage.sh logs-redis

# 测试 Redis 连接
docker exec -it tan-rss-redis redis-cli ping
```

## 📝 注意事项

1. **数据库文件**: 首次构建会将 `data/rss.db` 打包进镜像
2. **数据持久化**: 建议使用 volume 挂载数据目录，避免数据丢失
3. **资源占用**: 62MB 数据库 + Python 依赖，镜像约 500MB-800MB
4. **Celery Worker**: 如果不需要后台任务，部署时选择模式 2（仅部署 Backend）
5. **Milvus**: 向量数据库需要单独部署，确保网络可达
6. **备份建议**: 定期使用 `./deploy/backup.sh` 备份数据库

## 🆘 获取帮助

如有问题，请查看：
- 容器日志: `docker compose logs -f`
- API 文档: http://localhost:27496/docs
- 项目文档: 查看主项目 README
