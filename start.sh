#!/bin/bash

# TAN 启动脚本
# 只启动后端（Python）

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   TAN 启动 (Python Backend)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 清理函数
cleanup() {
    echo -e "\n${YELLOW}正在停止服务...${NC}"
    kill $(jobs -p) 2>/dev/null || true
    exit 0
}

trap cleanup INT TERM

# 1. 启动后端
echo -e "${GREEN}[1/1] 启动 Python 后端...${NC}"
cd python-backend

# 检查 Python 环境
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}错误: 未找到 python3${NC}"
    exit 1
fi

# 安装依赖
if [ ! -d "venv" ]; then
    echo "创建 Python 虚拟环境..."
    python3 -m venv venv
fi

source venv/bin/activate

echo "安装/检查依赖..."
pip install -r requirements.txt > /dev/null 2>&1

# 启动后端并绑定到 0.0.0.0 以允许手机访问
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 27496 --reload &
BACKEND_PID=$!
cd ..

echo -e "${GREEN}✓ 后端已启动 (PID: $BACKEND_PID)${NC}"
echo -e "  API: http://127.0.0.1:27496"
echo -e "  局域网 API: http://0.0.0.0:27496"
echo ""

# 显示运行状态
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🚀 后端服务运行中${NC}"
echo ""
echo "🔧 后端: http://127.0.0.1:27496"
echo ""
echo -e "${YELLOW}按 Ctrl+C 停止服务${NC}"
echo -e "${BLUE}========================================${NC}"

# 等待进程
wait