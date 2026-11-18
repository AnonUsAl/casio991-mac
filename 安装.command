#!/bin/bash
# 双击运行：把 Casio991.app 安装到“应用程序”并清除隔离属性
cd "$(dirname "$0")"
APP="$(pwd)/Casio991.app"
DEST="/Applications/Casio991.app"

echo "正在安装 fx-991CN X 科学计算器到 应用程序 ..."

# 清除隔离属性（避免“无法打开/已损坏”提示）
xattr -dr com.apple.quarantine "$APP" 2>/dev/null

# 拷贝（覆盖旧版）
if [ -d "$DEST" ]; then
  rm -rf "$DEST"
fi
cp -R "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null

echo "安装完成，正在启动 ..."
open "$DEST"
echo "如果没反应，请到 启动台/应用程序 手动打开 Casio991。"
