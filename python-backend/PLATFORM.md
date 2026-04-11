# 平台架构说明

## ⚠️ 重要：AMD64 架构

本项目的所有 Docker 镜像和部署包都是为 **AMD64 (x86_64)** 平台构建的。

### 🖥️ 支持的平台

| 架构 | 平台标识 | 支持状态 | 说明 |
|------|---------|---------|------|
| **AMD64** | `linux/amd64` | ✅ 完全支持 | Intel/AMD 64位处理器 |
| ARM64 | `linux/arm64` | ❌ 不支持 | Apple Silicon/ARM 服务器 |
| ARMv7 | `linux/arm/v7` | ❌ 不支持 | Raspberry Pi 等 |

### 🔍 如何检查服务器架构

```bash
# 方法 1: 使用 uname
uname -m
# 输出: x86_64 (AMD64) 或 aarch64 (ARM64)

# 方法 2: 使用 arch
arch
# 输出: x86_64 或 aarch64

# 方法 3: 查看 CPU 信息
lscpu | grep Architecture
# 输出: Architecture: x86_64
```

### 📋 常见服务器架构

#### AMD64 (x86_64) - ✅ 支持
- Intel Xeon 系列
- Intel Core 系列 (i3/i5/i7/i9)
- AMD EPYC 系列
- AMD Ryzen 系列
- 大多数云服务器（阿里云、腾讯云、AWS 等）

#### ARM64 (aarch64) - ❌ 不支持
- Apple M1/M2/M3 (Mac)
- AWS Graviton
- 华为鲲鹏
- Ampere Altra
- Raspberry Pi 4/5 (64位模式)

### 🛠️ 构建配置

所有构建脚本已配置为 AMD64 平台：

**Dockerfile:**
```dockerfile
FROM --platform=linux/amd64 python:3.11-slim
```

**build.sh:**
```bash
docker build --platform linux/amd64 -t tan-rss-backend .
```

**docker-compose.yml:**
```yaml
build:
  context: .
  dockerfile: Dockerfile
  platforms:
    - linux/amd64
```

### ⚠️ 注意事项

1. **Mac 用户注意**
   - Apple Silicon (M1/M2/M3) 默认是 ARM64 架构
   - 构建时会使用 Rosetta 2 模拟 AMD64
   - 构建的镜像可以在 AMD64 服务器上正常运行
   - 构建命令：`docker build --platform linux/amd64 .`

2. **跨平台构建**
   - 如果在 ARM 服务器上部署，需要重新构建 ARM64 镜像
   - 修改 Dockerfile 中的 `--platform=linux/arm64`
   - 或移除 `--platform` 参数使用本机架构

3. **性能影响**
   - AMD64 镜像在 AMD64 服务器上性能最佳
   - 跨架构运行会有性能损失或不支持

### 🔧 如需 ARM64 支持

如果需要在 ARM64 服务器上部署，需要修改以下文件：

**Dockerfile:**
```dockerfile
# 改为 ARM64
FROM --platform=linux/arm64 python:3.11-slim
```

**build.sh:**
```bash
# 移除或修改平台参数
docker build --platform linux/arm64 -t tan-rss-backend .
```

**docker-compose.yml:**
```yaml
build:
  platforms:
    - linux/arm64
```

### ✅ 验证架构

部署后，可以验证容器架构：

```bash
# 检查镜像架构
docker inspect tan-rss-backend | grep Architecture
# 输出: "Architecture": "amd64"

# 检查容器内的架构
docker exec tan-rss-backend uname -m
# 输出: x86_64
```

### 📊 当前配置

- **构建平台**: linux/amd64
- **目标服务器**: AMD64 (x86_64)
- **基础镜像**: python:3.11-slim (AMD64)
- **状态**: ✅ 已配置并测试

---

## 🆘 常见问题

### Q: 我在 Mac (M1/M2) 上构建，能在 AMD64 服务器运行吗？

A: 可以！使用 `--platform linux/amd64` 参数构建的镜像是 AMD64 架构，可以在任何 AMD64 服务器上运行。

### Q: 部署时提示架构不匹配怎么办？

A: 确保：
1. 服务器是 AMD64 架构（`uname -m` 输出 `x86_64`）
2. 使用正确的平台参数构建镜像
3. 如果使用打包部署，确认包是在 AMD64 平台构建的

### Q: 如何支持多架构？

A: 可以使用 Docker Buildx 构建多架构镜像：
```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t tan-rss-backend:latest .
```

但这需要额外的配置和测试，当前版本仅支持 AMD64。
