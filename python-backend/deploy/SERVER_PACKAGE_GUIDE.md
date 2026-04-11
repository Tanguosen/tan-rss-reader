# 服务器部署包使用说明

## 📦 什么是服务器部署包？

服务器部署包是包含**所有必需文件**的完整部署包，确保你一次性上传所有文件，不会缺斤少两。

## 🎯 解决的问题

❌ **之前的问题：**
- 需要手动复制多个文件
- 容易遗漏配置文件
- 不清楚需要哪些文件
- 多次上传麻烦

✅ **现在的解决方案：**
- 一键生成完整部署包
- 包含所有必需文件
- 一个目录/压缩包搞定
- 一次性上传即可

## 🚀 使用方法

### 步骤 1: 构建镜像

```bash
cd python-backend
./build.sh v1.0.0
```

### 步骤 2: 生成部署包

```bash
# 方式 1: 使用完整脚本
./deploy/generate_server_package.sh v1.0.0

# 方式 2: 使用快捷方式
./deploy/quick-server-package.sh v1.0.0

# 使用最新镜像
./deploy/generate_server_package.sh
```

### 步骤 3: 查看生成的文件

```bash
ls -lh deploy/server-deploy/
# 输出示例：
# tan-rss-server-20260411_120000/
```

### 步骤 4: 一次性上传到服务器

```bash
# 方式 1: 直接上传整个目录
scp -r deploy/server-deploy/tan-rss-server-* user@server:/opt/

# 方式 2: 打包后上传（推荐）
cd deploy/server-deploy
tar -czf tan-rss-server.tar.gz tan-rss-server-*/
scp tan-rss-server.tar.gz user@server:/opt/

# 方式 3: 使用 rsync
rsync -avz deploy/server-deploy/tan-rss-server-*/ user@server:/opt/tan-rss/
```

### 步骤 5: 在服务器上部署

```bash
# 如果使用压缩包，先解压
cd /opt/
tar -xzf tan-rss-server.tar.gz
cd tan-rss-server-*/

# 一键部署
chmod +x deploy.sh
./deploy.sh

# 或使用管理脚本
./manage.sh status
./manage.sh logs
```

## 📁 部署包内容

生成的部署包包含以下文件：

```
tan-rss-server-20260411_120000/
├── tan-rss-backend.tar          # Docker 镜像 (~600MB)
├── docker-compose.yml           # 服务编排配置
├── .env                         # 环境配置
├── data/
│   └── rss.db                   # 数据库 (62MB)
├── deploy.sh                    # 一键部署脚本 ⭐
├── manage.sh                    # 服务管理脚本
└── README.md                    # 部署说明
```

### 文件说明

| 文件 | 必需 | 说明 |
|------|------|------|
| `tan-rss-backend.tar` | ✅ | Docker 镜像，包含所有代码和依赖 |
| `docker-compose.yml` | ✅ | 服务编排配置，定义所有服务 |
| `.env` | ✅ | 环境变量配置，包含数据库、AI 服务等地址 |
| `data/rss.db` | ✅ | SQLite 数据库，包含所有数据 |
| `deploy.sh` | ✅ | 一键部署脚本，自动加载镜像并启动 |
| `manage.sh` | ✅ | 服务管理脚本，启动/停止/查看日志 |
| `README.md` | ⭕ | 部署说明文档 |

## 🔧 配置说明

### 部署前检查

在 `deploy.sh` 执行时会自动检查：

1. ✅ Docker 是否安装
2. ✅ Docker Compose 是否安装
3. ✅ 服务器架构是否为 AMD64
4. ✅ 镜像文件是否存在
5. ✅ 数据库是否存在

### 修改配置

如果需要修改配置，编辑 `.env` 文件：

```bash
# 数据库
DB_URL=""  # 留空使用 SQLite

# Milvus（如果服务器有 Milvus）
MILVUS_HOST="your-milvus-host"
MILVUS_PORT="19530"

# AI 服务（如果服务器有 AI 服务）
AURORA_AI_API_KEY="your-api-key"
AURORA_AI_BASE_URL="http://your-ai:9997/v1"
```

### 没有 Milvus 或 AI 服务？

完全没问题！RSS 核心功能可以独立运行：
- ✅ RSS 订阅
- ✅ 文章管理
- ✅ 分类和标签
- ❌ 向量搜索（需要 Milvus）
- ❌ AI 摘要/翻译（需要 AI 服务）

## 📊 部署包大小

典型部署包大小：

```
tan-rss-backend.tar    ~600MB  (Docker 镜像)
data/rss.db            ~62MB   (数据库)
其他文件               ~1MB    (配置和脚本)
─────────────────────────────────
总计                   ~663MB
```

压缩后（tar.gz）：约 **250-300MB**

## 🆚 与其他部署方式对比

| 特性 | 服务器部署包 | 内网部署包 | 直接部署 |
|------|-------------|-----------|---------|
| **适用场景** | 独立服务器 | 内网环境 | 本地开发 |
| **文件完整性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **上传便捷性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **包含数据库** | ✅ | ✅ | - |
| **包含镜像** | ✅ | ✅ | - |
| **一键部署** | ✅ | ✅ | ✅ |
| **管理脚本** | ✅ | ❌ | ✅ |

## 💡 最佳实践

### 1. 版本管理

```bash
# 为每个版本生成部署包
./deploy/generate_server_package.sh v1.0.0
./deploy/generate_server_package.sh v1.1.0

# 部署包会带时间戳，不会覆盖
deploy/server-deploy/tan-rss-server-20260411_120000/
deploy/server-deploy/tan-rss-server-20260412_150000/
```

### 2. 清理旧部署包

```bash
# 查看部署包
ls -lh deploy/server-deploy/

# 删除旧版本（保留最新）
ls -t deploy/server-deploy/ | tail -n +2 | xargs rm -rf
```

### 3. 服务器端备份

部署后，定期备份数据：

```bash
# 在服务器上
cd /opt/tan-rss-server-*/
./manage.sh stop

# 备份整个目录
tar -czf /backup/tan-rss-$(date +%Y%m%d).tar.gz .

# 或只备份数据库
cp data/rss.db /backup/rss-$(date +%Y%m%d).db

./manage.sh start
```

## 🐛 常见问题

### Q: 部署包生成失败？

A: 检查：
1. Docker 镜像是否已构建：`docker images | grep tan-rss-backend`
2. 磁盘空间是否充足：`df -h`
3. 权限是否正确：`ls -la deploy/server-deploy/`

### Q: 服务器上报架构错误？

A: 确保服务器是 AMD64 架构：
```bash
uname -m
# 应该输出: x86_64
```

### Q: 部署后无法访问？

A: 检查：
1. 服务状态：`./manage.sh status`
2. 服务日志：`./manage.sh logs-backend`
3. 端口占用：`lsof -i :27496`
4. 防火墙：`sudo ufw status`

### Q: 如何更新部署？

A: 
1. 生成新的部署包：`./deploy/generate_server_package.sh v1.1.0`
2. 上传到服务器
3. 停止旧服务：`./manage.sh stop`
4. 部署新版本：`./deploy.sh`

## 📞 需要帮助？

- 查看日志：`./manage.sh logs`
- 查看文档：`README.md`（部署包内）
- 架构说明：`PLATFORM.md`（项目根目录）
- 完整文档：`DOCKER_DEPLOY.md`（项目根目录）
