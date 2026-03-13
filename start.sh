#!/bin/bash

# TAN 启动脚本
# 依次启动后端（Python）和前端（Vue 3）

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
echo -e "${GREEN}[1/2] 启动 Python 后端...${NC}"
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

# 启动后端
python3 -m uvicorn app.main:app --host 127.0.0.1 --port 27496 --reload &
BACKEND_PID=$!
cd ..

echo -e "${GREEN}✓ 后端已启动 (PID: $BACKEND_PID)${NC}"
echo -e "  API: http://127.0.0.1:27496"
echo ""

# 等待后端启动
sleep 3

# 2. 启动前端
echo -e "${GREEN}[2/2] 启动 Vue 3 前端...${NC}"
cd rss-desktop

# 安装依赖（如果需要）
if [ ! -d "node_modules" ]; then
    echo "安装依赖..."
    pnpm install
fi

# 启动前端
pnpm run dev:frontend &
FRONTEND_PID=$!
cd ..

echo -e "${GREEN}✓ 前端已启动 (PID: $FRONTEND_PID)${NC}"
echo -e "  Web: http://127.0.0.1:5173"
echo ""

# 显示运行状态
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🚀 服务运行中${NC}"
echo ""
echo "📱 前端: http://127.0.0.1:5173"
echo "🔧 后端: http://127.0.0.1:27496"
echo ""
echo -e "${YELLOW}按 Ctrl+C 停止服务${NC}"
echo -e "${BLUE}========================================${NC}"

# 等待进程
wait
