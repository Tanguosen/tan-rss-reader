#!/bin/bash

# =================================================================
# TAN RSS Mobile APK 一键打包脚本
# 说明：此脚本用于自动化构建 Flutter Android 应用程序的 APK 文件。
# 产物：构建成功后，APK 文件将被复制到项目根目录的 release/ 文件夹下。
# =================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}      TAN RSS Mobile APK 打包工具      ${NC}"
echo -e "${BLUE}=======================================${NC}"

# 获取项目根目录路径
ROOT_DIR=$(pwd)
APP_DIR="$ROOT_DIR/tan_rss_mobile"
RELEASE_DIR="$ROOT_DIR/release"

# 检查是否在项目根目录运行
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}错误：找不到 tan_rss_mobile 目录。请在项目根目录执行此脚本！${NC}"
    exit 1
fi

# 检测 Flutter 路径
if command -v flutter &> /dev/null; then
    FLUTTER_CMD="flutter"
    echo -e "${GREEN}✓ 找到 Flutter: $(which flutter)${NC}"
elif [ -d "/Users/mac/development/flutter/bin" ]; then
    FLUTTER_CMD="/Users/mac/development/flutter/bin/flutter"
    echo -e "${GREEN}✓ 使用 Flutter: $FLUTTER_CMD${NC}"
else
    echo -e "${RED}错误：找不到 Flutter。请确保 Flutter 已安装并在 PATH 中，或修改脚本中的 Flutter 路径${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/4] 进入移动端项目目录...${NC}"
cd "$APP_DIR" || exit 1

echo -e "${YELLOW}[2/4] 清理旧的构建缓存...${NC}"
$FLUTTER_CMD clean
$FLUTTER_CMD pub get

echo -e "${YELLOW}[3/4] 开始构建 Release 版 APK...${NC}"
# 执行 flutter build
$FLUTTER_CMD build apk --release

# 检查构建是否成功
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Flutter 构建成功！${NC}"
else
    echo -e "${RED}Flutter 构建失败，请检查上面的错误信息。${NC}"
    exit 1
fi

echo -e "${YELLOW}[4/4] 提取并重命名 APK 文件...${NC}"
# 创建 release 目录
mkdir -p "$RELEASE_DIR"

# 源文件路径
SOURCE_APK="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
# 目标文件路径 (带时间戳)
TIMESTAMP=$(date +"%Y%m%d_%H%M")
TARGET_APK="$RELEASE_DIR/TAN_RSS_v1.0.0_$TIMESTAMP.apk"

if [ -f "$SOURCE_APK" ]; then
    cp "$SOURCE_APK" "$TARGET_APK"
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}🎉 打包完成！${NC}"
    echo -e "${GREEN}APK 文件已保存至: ${NC}"
    echo -e "${BLUE}$TARGET_APK${NC}"
    echo -e "${GREEN}=======================================${NC}"
else
    echo -e "${RED}错误：找不到构建产物 $SOURCE_APK${NC}"
    exit 1
fi
