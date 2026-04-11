# TAN RSS Backend 快速部署参考

## 📁 目录结构

```
python-backend/
├── Dockerfile              # Docker 镜像配置 (AMD64)
├── docker-compose.yml      # 服务编排配置
├── .dockerignore          # 构建排除规则
├── build.sh               # 镜像构建脚本
├── PLATFORM.md            # 平台架构说明 (AMD64)
├── data/
│   └── rss.db            # 数据库 (62MB)
└── deploy/               # 部署脚本目录
    ├── deploy.sh         # 一键部署
    ├── manage.sh         # 服务管理
    ├── backup.sh         # 数据库备份
    ├── restore.sh        # 数据库恢复
    ├── export.sh         # 导出镜像（内网部署）
    ├── package_for_intranet.sh  # 打包内网部署包
    ├── check_arch.sh     # 架构兼容性检查
    ├── generate_server_package.sh  # 生成服务器部署包
    ├── quick-server-package.sh     # 快速生成部署包
    └── server-deploy/    # 服务器部署包输出目录
```

## 🚀 快速部署

```bash
cd python-backend
./deploy/deploy.sh
```

## 🔧 常用命令

### 部署
```bash
./deploy/deploy.sh         # 交互式部署（3种模式）
./build.sh                 # 仅构建镜像
./build.sh v1.0.0          # 构建带版本标签
```

### 生成服务器部署包
```bash
./deploy/generate_server_package.sh         # 生成完整部署包
./deploy/generate_server_package.sh v1.0.0  # 指定版本
./deploy/quick-server-package.sh            # 快捷方式

# 输出到 deploy/server-deploy/ 目录
# 包含所有必需文件，一次性上传
```

### 内网部署
```bash
./deploy/export.sh              # 导出镜像
cd deploy/exports
./load_and_deploy.sh            # 在内网服务器加载并部署

# 或一键打包
./deploy/package_for_intranet.sh           # 打包完整部署包
# 传输到内网服务器后
./deploy.sh                   # 一键部署
```

### 服务管理
```bash
./deploy/manage.sh start      # 启动
./deploy/manage.sh stop       # 停止
./deploy/manage.sh restart    # 重启
./deploy/manage.sh status     # 状态
./deploy/manage.sh logs       # 日志
./deploy/manage.sh shell      # 进入容器
```

### 数据库
```bash
./deploy/backup.sh        # 备份数据库
./deploy/restore.sh       # 恢复数据库
./deploy/manage.sh db-shell  # SQLite Shell
```

## 🌐 访问地址

- API: http://localhost:27496
- 文档: http://localhost:27496/docs

## 🖥️ 平台要求

- **架构**: AMD64 (x86_64) ⚠️ 重要
- **检查**: `./deploy/check_arch.sh`
- **说明**: 详见 `PLATFORM.md`

## 📊 服务组成

- **tan-rss-backend**: FastAPI 主服务 (:27496)
- **redis**: 缓存/消息队列 (:6379)
- **celery-worker**: 后台任务处理器

## 💡 提示

- 部署模式 1: 完整服务（推荐生产环境）
- 部署模式 2: 仅 Backend（开发/测试）
- 定期备份: `./deploy/backup.sh`
- 查看日志: `./deploy/manage.sh logs-backend`
- 内网部署: `./deploy/package_for_intranet.sh`
- **服务器部署**: `./deploy/generate_server_package.sh` ⭐
