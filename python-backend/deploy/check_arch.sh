#!/bin/bash

# 检查服务器架构兼容性

echo "========================================="
echo "  服务器架构检查"
echo "========================================="
echo ""

# 检查架构
ARCH=$(uname -m)
echo "当前架构: ${ARCH}"

if [ "$ARCH" = "x86_64" ]; then
    echo "✅ 架构兼容: AMD64 (x86_64)"
    echo ""
    echo "可以运行本项目的所有 Docker 镜像和部署包。"
    COMPATIBLE=true
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "❌ 架构不兼容: ARM64 (aarch64)"
    echo ""
    echo "本项目仅支持 AMD64 架构。"
    echo ""
    echo "解决方案:"
    echo "  1. 使用 AMD64 服务器部署"
    echo "  2. 或修改 Dockerfile 支持 ARM64（需要重新构建）"
    echo ""
    echo "参考文档: PLATFORM.md"
    COMPATIBLE=false
else
    echo "⚠️  未知架构: ${ARCH}"
    echo "请确认是否为 AMD64 (x86_64) 架构"
    COMPATIBLE=false
fi

echo ""
echo "========================================="
echo "  系统信息"
echo "========================================="
echo ""

# 显示详细信息
echo "操作系统:"
uname -a
echo ""

echo "CPU 信息:"
if command -v lscpu &> /dev/null; then
    lscpu | grep -E "Architecture|CPU\(s\)|Model name"
elif command -v sysctl &> /dev/null; then
    sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "无法获取 CPU 信息"
fi
echo ""

echo "内存:"
if command -v free &> /dev/null; then
    free -h | grep Mem
elif command -v vm_stat &> /dev/null; then
    echo "macOS 系统，请使用 Activity Monitor 查看"
fi
echo ""

echo "磁盘空间:"
df -h / | tail -1
echo ""

# Docker 检查
if command -v docker &> /dev/null; then
    echo "========================================="
    echo "  Docker 信息"
    echo "========================================="
    echo ""
    
    echo "Docker 版本:"
    docker --version
    echo ""
    
    echo "Docker Compose 版本:"
    if command -v docker-compose &> /dev/null; then
        docker-compose --version
    elif docker compose version &> /dev/null; then
        docker compose version
    else
        echo "未安装"
    fi
    echo ""
    
    echo "Docker 架构支持:"
    docker info 2>/dev/null | grep -A 5 "Architecture" || echo "无法获取"
    echo ""
else
    echo "⚠️  Docker 未安装"
    echo ""
    echo "安装 Docker:"
    echo "  Ubuntu/Debian: sudo apt install docker.io docker-compose"
    echo "  CentOS/RHEL:   sudo yum install docker docker-compose"
    echo "  macOS:         安装 Docker Desktop"
    echo ""
fi

# 总结
echo "========================================="
echo "  检查结果"
echo "========================================="
echo ""

if [ "$COMPATIBLE" = true ]; then
    echo "✅ 服务器架构兼容，可以部署本项目"
    echo ""
    echo "下一步:"
    echo "  1. 确保 Docker 和 Docker Compose 已安装"
    echo "  2. 运行部署脚本: ./deploy/deploy.sh"
    echo "  3. 或解压部署包后运行: ./deploy.sh"
else
    echo "❌ 服务器架构不兼容"
    echo ""
    echo "需要 AMD64 (x86_64) 架构的服务器"
    echo "详见: PLATFORM.md"
fi

echo ""
