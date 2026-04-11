#!/bin/bash

# 快速生成服务器部署包（快捷方式）

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "  快速生成服务器部署包"
echo "========================================="
echo ""

cd "$PROJECT_DIR"
./deploy/generate_server_package.sh "$@"
