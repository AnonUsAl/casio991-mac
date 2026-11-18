#!/bin/bash
# fx-991CN X 科学计算器 — macOS 一键安装脚本（含强制更新）
# 双击运行；把最新版安装到「应用程序」并确保覆盖旧版
set -e

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SELF_DIR"
APP="$SELF_DIR/Casio991.app"
DEST="/Applications/Casio991.app"

echo "================================================"
echo "  fx-991CN X 科学计算器 · macOS 安装 / 更新"
echo "================================================"
echo ""

if [ ! -d "$APP" ]; then
  echo "[错误] 没找到 Casio991.app，请确保它和本脚本在同一文件夹。"
  read -r -p "按回车退出..." _; exit 1
fi
echo "[1/5] 已找到安装源"

# 关闭正在运行的旧版（否则覆盖时旧文件残留）
echo "[2/5] 关闭正在运行的旧版..."
osascript -e 'tell application "Casio991" to quit' >/dev/null 2>&1 || true
sleep 1

# 校验安装源是否为最新版（含按键清晰度修复）
echo "[3/5] 校验安装源..."
if grep -q "无需抠" "$APP/Contents/Resources/site/app.js" 2>/dev/null; then
  echo "       ✓ 安装源为最新版（按键清晰）"
else
  echo "       ⚠ 安装源较旧，按键可能发白，建议重新下载 zip"
fi

# 彻底删除旧版再装（避免 cp 嵌套/残留旧文件）
echo "[4/5] 安装到 /Applications ..."
rm -rf "$DEST" 2>/dev/null || sudo rm -rf "$DEST"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
ditto "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
echo "       ✓ 安装完成"

# 校验安装结果
echo "[5/5] 校验安装结果..."
if grep -q "无需抠" "$DEST/Contents/Resources/site/app.js" 2>/dev/null; then
  echo "       ✓ 已安装最新版"
else
  echo "       ✗ 校验失败，安装可能不完整"
fi

echo ""
echo "正在启动 ..."
open "$DEST"
sleep 2
if pgrep -x Casio991 >/dev/null 2>&1; then
  echo "[成功] 应用已启动。"
else
  echo "[注意] 请到「启动台」手动打开 Casio991。"
fi
echo ""
echo "若按键仍发白：先按 ⌘Q 完全退出应用，再重新双击本脚本。"
echo "================================================"
