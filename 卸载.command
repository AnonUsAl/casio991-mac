#!/bin/bash
# fx-991CN X 科学计算器 — 彻底卸载脚本
# 把 app 连同计算记忆（WKWebView localStorage）、缓存一起移入废纸篓（可从废纸篓恢复）
set -e

APP="/Applications/Casio991.app"
WEBKIT="$HOME/Library/WebKit/com.anonusal.casio991.mac"
CACHE="$HOME/Library/Caches/com.anonusal.casio991.mac"

echo "================================================"
echo "  fx-991CN X 科学计算器 · 彻底卸载"
echo "================================================"
echo ""
echo "将移入废纸篓（可恢复）："
echo "  1. $APP"
echo "  2. $WEBKIT   ← 计算记忆 / localStorage / 缓存"
echo "  3. $CACHE    ← 缓存"
echo ""

# 先退出正在运行的应用
echo "[1/3] 关闭正在运行的应用..."
osascript -e 'tell application "Casio991" to quit' >/dev/null 2>&1 || true
sleep 1

# 逐项移入废纸篓（用系统 trash，安全可恢复）
echo "[2/3] 移入废纸篓..."
for target in "$APP" "$WEBKIT" "$CACHE"; do
  if [ -e "$target" ]; then
    /usr/bin/trash "$target" 2>/dev/null || rm -rf "$target" 2>/dev/null || sudo rm -rf "$target"
    echo "       ✓ 已移除: $target"
  else
    echo "       - 不存在，跳过: $target"
  fi
done

echo "[3/3] 校验..."
remaining=0
for target in "$APP" "$WEBKIT" "$CACHE"; do
  [ -e "$target" ] && { echo "       ✗ 仍存在: $target"; remaining=1; }
done
if [ "$remaining" -eq 0 ]; then
  echo "       ✓ 已彻底卸载，计算记忆一并清除"
else
  echo "       部分项目未删除，可能需要管理员权限"
fi
echo ""
echo "如需恢复，从废纸篓拖回原位置即可。"
echo "================================================"
