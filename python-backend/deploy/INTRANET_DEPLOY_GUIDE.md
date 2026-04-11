# 内网部署完整流程

## 📋 两种部署方式对比

| 特性 | 方式一：导出镜像 | 方式二：一键打包 |
|------|-----------------|-----------------|
| **适用场景** | 手动控制传输文件 | 快速部署，最简单 |
| **传输文件数** | 3-5 个文件 | 1 个压缩包 |
| **灵活性** | 高（可选择性传输） | 中（全包） |
| **操作难度** | 中等 | 简单 |
| **推荐度** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 🔄 方式一：导出镜像部署流程

```
┌─────────────────────────────────────────────────────────────┐
│                    外网服务器（有网络）                        │
│                                                             │
│  1. 构建镜像                                                 │
│     ./build.sh v1.0.0                                       │
│          ↓                                                  │
│  2. 导出镜像                                                 │
│     ./deploy/export.sh v1.0.0                               │
│          ↓                                                  │
│  生成文件：                                                   │
│  - tan-rss-backend_v1.0.0_20260411_112000.tar (镜像)        │
│  - load_and_deploy.sh (加载脚本)                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
                    传输文件 (SCP/USB)
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                    内网服务器（无外网）                        │
│                                                             │
│  需要传输的文件：                                             │
│  ✓ tan-rss-backend_v1.0.0_*.tar                            │
│  ✓ load_and_deploy.sh                                       │
│  ✓ docker-compose.yml                                       │
│  ✓ .env (可选，自定义配置)                                   │
│  ✓ data/rss.db (可选，现有数据)                              │
│                                                             │
│  3. 加载并部署                                               │
│     chmod +x load_and_deploy.sh                             │
│     ./load_and_deploy.sh                                    │
│          ↓                                                  │
│  ✓ 自动加载镜像                                              │
│  ✓ 自动启动服务                                              │
│  ✓ 自动检查状态                                              │
│          ↓                                                  │
│  部署完成！                                                  │
│  API: http://localhost:27496                                │
└─────────────────────────────────────────────────────────────┘
```

**详细步骤：**

```bash
# ========== 外网服务器操作 ==========

# 1. 进入项目目录
cd /path/to/python-backend

# 2. 构建镜像（如果还未构建）
./build.sh v1.0.0

# 3. 导出镜像
./deploy/export.sh v1.0.0

# 4. 查看生成的文件
ls -lh deploy/exports/
# 输出：
# tan-rss-backend_v1.0.0_20260411_112000.tar
# load_and_deploy.sh

# 5. 传输到内网服务器
scp deploy/exports/tan-rss-backend_v1.0.0_*.tar user@192.168.1.100:/opt/tan-rss/
scp deploy/exports/load_and_deploy.sh user@192.168.1.100:/opt/tan-rss/
scp docker-compose.yml user@192.168.1.100:/opt/tan-rss/
scp .env user@192.168.1.100:/opt/tan-rss/  # 如果有自定义配置
scp -r data/ user@192.168.1.100:/opt/tan-rss/  # 如果有现有数据


# ========== 内网服务器操作 ==========

# 1. 进入部署目录
cd /opt/tan-rss/

# 2. 执行部署
chmod +x load_and_deploy.sh
./load_and_deploy.sh

# 3. 验证部署
curl http://localhost:27496/
docker compose ps

# 4. 查看日志（如有问题）
docker compose logs -f
```

---

## 📦 方式二：一键打包部署流程（推荐）

```
┌─────────────────────────────────────────────────────────────┐
│                    外网服务器（有网络）                        │
│                                                             │
│  1. 一键打包                                                 │
│     ./deploy/package_for_intranet.sh v1.0.0                 │
│          ↓                                                  │
│  自动生成：                                                   │
│  tan-rss-deploy-20260411_112000.tar.gz                      │
│  包含：镜像 + 配置 + 数据库 + 部署脚本                        │
└─────────────────────────────────────────────────────────────┘
                          ↓
                    传输单个文件 (SCP/USB)
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                    内网服务器（无外网）                        │
│                                                             │
│  2. 解压并部署                                               │
│     tar -xzf tan-rss-deploy-*.tar.gz                        │
│     cd tan-rss-deploy-*/                                    │
│     chmod +x deploy.sh                                      │
│     ./deploy.sh                                             │
│          ↓                                                  │
│  ✓ 自动加载镜像                                              │
│  ✓ 自动配置环境                                              │
│  ✓ 自动启动服务                                              │
│  ✓ 自动检查状态                                              │
│          ↓                                                  │
│  部署完成！                                                  │
│  API: http://localhost:27496                                │
└─────────────────────────────────────────────────────────────┘
```

**详细步骤：**

```bash
# ========== 外网服务器操作 ==========

# 1. 进入项目目录
cd /path/to/python-backend

# 2. 一键打包（包含镜像、配置、数据库）
./deploy/package_for_intranet.sh v1.0.0

# 3. 查看生成的部署包
ls -lh deploy/packages/
# 输出：
# tan-rss-deploy-20260411_112000.tar.gz (约 600MB)

# 4. 传输到内网服务器（只需一个文件）
scp deploy/packages/tan-rss-deploy-*.tar.gz user@192.168.1.100:/opt/


# ========== 内网服务器操作 ==========

# 1. 解压部署包
cd /opt/
tar -xzf tan-rss-deploy-*.tar.gz
cd tan-rss-deploy-*/

# 2. 查看内容
ls -la
# 输出：
# tan-rss-backend.tar    - Docker 镜像
# docker-compose.yml     - 服务配置
# .env                   - 环境配置
# data/rss.db            - 数据库
# deploy.sh              - 部署脚本
# README.md              - 部署说明

# 3. 一键部署
chmod +x deploy.sh
./deploy.sh

# 4. 验证部署
curl http://localhost:27496/
docker compose ps

# 5. 查看日志（如有问题）
docker compose logs -f
```

---

## 🔧 内网环境配置要点

### 1. 检查内网服务地址

编辑 `.env` 文件，确保所有服务地址在内网可访问：

```bash
# Redis - 使用本地容器（不需要改）
REDIS_URL="redis://redis:6379/0"

# Milvus - 如果内网有 Milvus 服务
MILVUS_HOST="192.168.1.50"  # 改为内网 IP
MILVUS_PORT="19530"

# AI 服务 - 如果内网有 AI 服务
AURORA_AI_BASE_URL="http://192.168.1.60:9997/v1"  # 改为内网 IP
AURORA_AI_EMBEDDING_BASE_URL="http://192.168.1.60:9997/v1"
```

### 2. 端口检查

确保内网服务器端口未被占用：

```bash
# 检查端口
lsof -i :27496
lsof -i :6379

# 如果被占用，修改 docker-compose.yml 中的端口映射
ports:
  - "27497:27496"  # 改为其他端口
```

### 3. 防火墙配置

如果需要外部访问：

```bash
# 开放端口（Ubuntu/Debian）
sudo ufw allow 27496/tcp

# 开放端口（CentOS/RHEL）
sudo firewall-cmd --permanent --add-port=27496/tcp
sudo firewall-cmd --reload
```

---

## ✅ 部署检查清单

部署完成后，逐项检查：

- [ ] Docker 服务运行正常
- [ ] 容器状态正常（`docker compose ps`）
- [ ] API 可访问（`curl http://localhost:27496/`）
- [ ] API 文档可访问（`http://localhost:27496/docs`）
- [ ] 数据库正常加载
- [ ] Redis 连接正常
- [ ] 日志无错误（`docker compose logs -f`）
- [ ] 端口防火墙已配置（如需外部访问）

---

## 🐛 常见问题

### Q1: 镜像加载失败
```bash
# 检查 Docker 版本
docker --version

# 检查磁盘空间
df -h

# 重新传输文件（可能文件损坏）
md5sum tan-rss-backend_*.tar  # 对比源文件和目标文件
```

### Q2: 服务启动失败
```bash
# 查看详细日志
docker compose logs tan-rss-backend

# 检查配置文件
cat docker-compose.yml
cat .env

# 检查数据库文件
ls -lh data/rss.db
```

### Q3: 无法访问 API
```bash
# 检查容器状态
docker compose ps

# 检查端口
lsof -i :27496

# 测试本地访问
curl http://localhost:27496/

# 检查防火墙
sudo ufw status
```

---

## 📞 技术支持

如遇到问题：
1. 查看日志：`docker compose logs -f`
2. 查看文档：`DOCKER_DEPLOY.md`
3. 联系开发团队
