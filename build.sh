#!/bin/bash
# 編譯「動態壁紙」App
#   用法： ./build.sh          → 編譯到 build/動態壁紙.app
#          ./build.sh install  → 編譯後安裝到 ~/Applications
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
RES="$ROOT/resources"
BUILD="$ROOT/build"
APP="動態壁紙.app"
BIN="DynWall"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

rm -rf "$BUILD"
mkdir -p "$BUILD/$APP/Contents/MacOS" "$BUILD/$APP/Contents/Resources"

echo "==> 產生內建壁紙縮圖（給壁紙庫用）"
mkdir -p "$RES/thumbs"
if [ -x "$CHROME" ]; then
  for d in "$RES"/wallpapers/*/; do
    id="$(basename "$d")"
    if [ ! -f "$RES/thumbs/$id.jpg" ] || [ "$d/index.html" -nt "$RES/thumbs/$id.jpg" ]; then
      "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
        --window-size=640,400 --virtual-time-budget=4000 \
        --screenshot="/tmp/dyn_thumb_$id.png" "file://$d/index.html" >/dev/null 2>&1 || true
      if [ -f "/tmp/dyn_thumb_$id.png" ]; then
        sips -s format jpeg -s formatOptions 80 "/tmp/dyn_thumb_$id.png" --out "$RES/thumbs/$id.jpg" >/dev/null 2>&1 || true
        rm -f "/tmp/dyn_thumb_$id.png"
      fi
    fi
  done
  echo "    縮圖數量：$(ls -1 "$RES/thumbs" 2>/dev/null | wc -l | tr -d ' ')"
else
  echo "    （找不到 Chrome，縮圖改用即時渲染）"
fi

echo "==> 編譯 Objective-C 橋接"
clang -c -fobjc-arc -O2 -o "$BUILD/bridge.o" "$SRC/bridge.m"

echo "==> 編譯 Swift 主程式 + 圖形介面"
swiftc -swift-version 5 -O \
  -import-objc-header "$SRC/bridge.h" \
  -o "$BUILD/$APP/Contents/MacOS/$BIN" \
  "$SRC/main.swift" "$SRC/gui.swift" "$BUILD/bridge.o" \
  -framework Cocoa -framework AVFoundation -framework WebKit -framework SwiftUI \
  -framework UniformTypeIdentifiers

echo "==> 產生內建壁紙海報（關掉 App 後桌面用的靜態圖）"
mkdir -p "$RES/posters"
if [ -x "$CHROME" ]; then
  for d in "$RES"/wallpapers/*/; do
    id="$(basename "$d")"
    if [ ! -f "$RES/posters/$id.jpg" ] || [ "$d/index.html" -nt "$RES/posters/$id.jpg" ]; then
      "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
        --window-size=1470,956 --virtual-time-budget=5000 \
        --screenshot="/tmp/dyn_poster_$id.png" "file://$d/index.html" >/dev/null 2>&1 || true
      if [ -f "/tmp/dyn_poster_$id.png" ]; then
        sips -Z 2940 -s format jpeg -s formatOptions 88 "/tmp/dyn_poster_$id.png" --out "$RES/posters/$id.jpg" >/dev/null 2>&1 || true
        rm -f "/tmp/dyn_poster_$id.png"
      fi
    fi
  done
  echo "    海報數量：$(ls -1 "$RES/posters" 2>/dev/null | wc -l | tr -d ' ')"
fi

echo "==> 打包資源"
cp -R "$RES/wallpapers" "$BUILD/$APP/Contents/Resources/"
if [ -d "$RES/thumbs" ]; then cp -R "$RES/thumbs" "$BUILD/$APP/Contents/Resources/"; fi
if [ -d "$RES/posters" ]; then cp -R "$RES/posters" "$BUILD/$APP/Contents/Resources/"; fi
if [ -f "$RES/AppIcon.icns" ]; then cp "$RES/AppIcon.icns" "$BUILD/$APP/Contents/Resources/"; fi
cp "$ROOT/Info.plist" "$BUILD/$APP/Contents/Info.plist"

echo "==> 簽章（ad-hoc）"
codesign --force --deep --sign - "$BUILD/$APP" >/dev/null 2>&1 || echo "（簽章失敗，仍可嘗試執行）"

echo "==> 編譯診斷小工具"
swiftc -O "$ROOT/tools/winlist.swift" -o "$BUILD/winlist" -framework Cocoa 2>/dev/null || echo "（winlist 略過）"

echo "==> 完成：$BUILD/$APP"

if [ "${1:-}" = "install" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/$APP"
  cp -R "$BUILD/$APP" "$HOME/Applications/$APP"
  echo "==> 已安裝到 ~/Applications/$APP"
fi
