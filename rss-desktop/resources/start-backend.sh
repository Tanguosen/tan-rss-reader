#!/bin/bash
set -e

# 进入脚本所在目录，确保相对路径正确
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 设置生产模式环境变量
export RUST_ENV=production

# 启动 Python 后端（FastAPI）
PY_BACKEND_DIR="$SCRIPT_DIR/../../python-backend"
PY_BACKEND_PORT="${PY_BACKEND_PORT:-27496}"
if [ -d "$PY_BACKEND_DIR" ]; then
  (
    cd "$PY_BACKEND_DIR"
    # 在后台启动 uvicorn，避免阻塞当前脚本
    # 使用 python3 -m 方式以提升可移植性
    nohup python3 -m uvicorn app.main:app \
      --host 127.0.0.1 \
      --port "$PY_BACKEND_PORT" \
      --workers 1 \
      >/dev/null 2>&1 &
  ) || true
fi

# 启动 Rust 后端服务（二进制 tan-backend）
exec ./tan-backend
