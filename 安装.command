#!/bin/bash
# fx-991CN X 科学计算器 — macOS 一键安装脚本
# 用法：双击本文件，或在终端执行 bash 安装.command
# 作用：清除隔离属性 → 安装到「应用程序」→ 启动

set -e

# 定位脚本所在目录（兼容中文路径与从任意位置双击）
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SELF_DIR"

APP="$SELF_DIR/Casio991.app"
DEST="/Applications/Casio991.app"

echo "================================================"
echo "  fx-991CN X 科学计算器 · macOS 安装"
echo "================================================"
echo ""

# 1) 检查源文件
if [ ! -d "$APP" ]; then
  echo "[错误] 没有找到 Casio991.app"
  echo "       请确保本脚本与 Casio991.app 放在同一个文件夹。"
  echo ""
  read -r -p "按回车键退出..." _
  exit 1
fi
echo "[1/4] 已找到 Casio991.app"

# 2) 关闭正在运行的旧版本，避免覆盖时报错
if pgrep -x Casio991 >/dev/null 2>&1; then
  echo "[2/4] 检测到旧版本正在运行，正在关闭..."
  osascript -e 'tell application "Casio991" to quit' >/dev/null 2>&1 || true
  sleep 1
else
  echo "[2/4] 无需关闭旧版本"
fi

# 3) 清除隔离属性（避免"无法打开/已损坏"提示）
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
echo "[3/4] 已清除隔离属性"

# 4) 安装到「应用程序」
echo "[4/4] 正在安装到 /Applications ..."
if [ -d "$DEST" ]; then
  rm -rf "$DEST" 2>/dev/null || {
    echo "[提示] 覆盖旧版需要管理员权限，请在弹出的窗口中输入密码。"
    sudo rm -rf "$DEST"
  }
fi
cp -R "$APP" "$DEST" 2>/dev/null || {
  echo "[提示] 写入「应用程序」需要管理员权限，请在弹出的窗口中输入密码。"
  sudo cp -R "$APP" "$DEST"
}
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo ""
echo "安装完成，正在启动 ..."
open "$DEST"

sleep 2
if pgrep -x Casio991 >/dev/null 2>&1; then
  echo "[成功] 应用已启动，请查看屏幕上的窗口。"
else
  echo "[注意] 若没有看到窗口，请到「启动台」或「应用程序」手动打开 Casio991。"
fi
echo ""
echo "卸载方法：删除 /Applications/Casio991.app 即可。"
echo "================================================"
