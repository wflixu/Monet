#!/bin/bash
# 本地测试构建脚本
# 用于验证 GitHub Actions workflow 的构建步骤

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== 1. 构建 App (使用 xcodebuild) ==="
xcodebuild -scheme Monet \
  -configuration Release \
  -derivedDataPath build \
  -destination "generic/platform=macOS" \
  ENABLE_HARDENED_RUNTIME=YES \
  build

echo "=== 2. 查找构建产物 ==="
# 使用 find 查找 App（兼容不同路径结构）
APP_PATH=$(find build -name "Monet.app" -type d -path "*/Products/Release/*" | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo "Error: App 未找到"
  echo "尝试查找所有 .app 目录:"
  find build -name "*.app" -type d || true
  exit 1
fi

echo "App 构建成功：$APP_PATH"

echo "=== 3. 检查 App 内容 ==="
ls -la "$APP_PATH/Contents"
ls -la "$APP_PATH/Contents/MacOS"

echo "=== 本地构建完成 ==="
echo "提示：如需测试签名，请手动运行:"
echo "  codesign --force --deep --options runtime --sign \"你的证书名称\" \"$APP_PATH\""
