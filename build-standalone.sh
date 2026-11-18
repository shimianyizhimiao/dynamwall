#!/bin/bash
# 把你的影片／圖片包成一支「獨立的小 App」
#   用法： ./build-standalone.sh "App 名稱" "識別碼後綴" "媒體檔案路徑" ["顯示用標題"]
#   例：   ./build-standalone.sh "我的壁紙" "mywall" "/Users/me/Movies/clip.mp4" "我的壁紙"
#
# 產出：~/Applications/<App 名稱>.app  ＋  <App 名稱>.app.zip（可以直接給別人）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
RES="$ROOT/resources"
BUILD="$ROOT/build-standalone"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

APPNAME="${1:?請給 App 名稱}"
SUFFIX="${2:?請給識別碼後綴（英文數字）}"
MEDIA="${3:?請給影片或圖片路徑}"
TITLE="${4:-$APPNAME}"

[ -f "$MEDIA" ] || { echo "找不到檔案：$MEDIA"; exit 1; }
BUNDLEID="com.dynwall.$SUFFIX"
APPDIR="$BUILD/$APPNAME.app"
MEDIA_DIR="$APPDIR/Contents/Resources/media"

rm -rf "$APPDIR"
mkdir -p "$APPDIR/Contents/MacOS" "$MEDIA_DIR"

# ── 1. 決定類型 + 內部檔名（用 ASCII 安全的檔名，避免路徑問題）
read -r KIND EXT DESTNAME < <(python3 "$ROOT/tools/standalone_prep.py" "$MEDIA" "$TITLE")
echo "==> 類型：${KIND}　內部檔名：${DESTNAME}"

cp "$MEDIA" "$MEDIA_DIR/$DESTNAME"

# ── 2. 寫預設設定（指向 App 內部的檔案）
python3 - "$APPDIR/Contents/Resources/preset.json" "$KIND" "media/$DESTNAME" <<'PY'
import json, sys
path, kind, ref = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = {"autoStart": False, "dim": 0.0, "gravity": "fill", "interactive": False,
       "kind": kind, "mute": True, "paused": False, "rate": 1.0, "ref": "@bundle:" + ref}
open(path, "w", encoding="utf-8").write(json.dumps(cfg, indent=2, ensure_ascii=False, sort_keys=True))
PY

# ── 3. 編譯（同一份引擎原始碼）
echo "==> 編譯"
clang -c -fobjc-arc -O2 -o "$BUILD/bridge.o" "$SRC/bridge.m"
swiftc -swift-version 5 -O \
  -import-objc-header "$SRC/bridge.h" \
  -o "$APPDIR/Contents/MacOS/DynWall" \
  "$SRC/main.swift" "$SRC/gui.swift" "$BUILD/bridge.o" \
  -framework Cocoa -framework AVFoundation -framework WebKit -framework SwiftUI \
  -framework UniformTypeIdentifiers

# ── 4. 資源：內建壁紙（讓壁紙庫仍可用）＋ 縮圖
cp -R "$RES/wallpapers" "$APPDIR/Contents/Resources/"
[ -d "$RES/thumbs" ] && cp -R "$RES/thumbs" "$APPDIR/Contents/Resources/"
[ -d "$RES/posters" ] && cp -R "$RES/posters" "$APPDIR/Contents/Resources/"

# ── 5. 用影片畫面做 App 圖示
if [ -x "$CHROME" ]; then
  echo "==> 產生 App 圖示"
  swiftc -O "$ROOT/tools/vidinfo.swift" -o "$BUILD/vidinfo" -framework AVFoundation -framework Cocoa 2>/dev/null || true
  FRAME=""
  if [ "$KIND" = "video" ] && [ -x "$BUILD/vidinfo" ]; then
    "$BUILD/vidinfo" "$MEDIA" 3 "$BUILD/frame.png" >/dev/null 2>&1 || true
    [ -f "$BUILD/frame.png" ] && FRAME="$BUILD/frame.png"
  elif [ "$KIND" = "image" ]; then
    FRAME="$MEDIA"
  fi
  if [ -n "$FRAME" ]; then
    cat > "$BUILD/icon.html" <<HTML
<html><body style="margin:0;background:transparent">
<div style="width:1024px;height:1024px;border-radius:215px;overflow:hidden;background:#000">
<img src="file://$FRAME" style="width:1024px;height:1024px;object-fit:cover">
</div></body></html>
HTML
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
      --default-background-color=00000000 --window-size=1024,1024 --virtual-time-budget=2500 \
      --screenshot="$BUILD/icon.png" "file://$BUILD/icon.html" >/dev/null 2>&1 || true
    if [ -f "$BUILD/icon.png" ]; then
      rm -rf "$BUILD/AppIcon.iconset"; mkdir -p "$BUILD/AppIcon.iconset"
      for s in 16 32 64 128 256 512; do
        sips -z $s $s "$BUILD/icon.png" --out "$BUILD/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
      done
      cp "$BUILD/AppIcon.iconset/icon_32x32.png"  "$BUILD/AppIcon.iconset/icon_16x16@2x.png"
      cp "$BUILD/AppIcon.iconset/icon_64x64.png"  "$BUILD/AppIcon.iconset/icon_32x32@2x.png"
      cp "$BUILD/AppIcon.iconset/icon_256x256.png" "$BUILD/AppIcon.iconset/icon_128x128@2x.png"
      cp "$BUILD/AppIcon.iconset/icon_512x512.png" "$BUILD/AppIcon.iconset/icon_256x256@2x.png"
      sips -z 1024 1024 "$BUILD/icon.png" --out "$BUILD/AppIcon.iconset/icon_512x512@2x.png" >/dev/null
      iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APPDIR/Contents/Resources/AppIcon.icns" || true
    fi
  fi
fi
[ -f "$APPDIR/Contents/Resources/AppIcon.icns" ] || cp "$RES/AppIcon.icns" "$APPDIR/Contents/Resources/AppIcon.icns"

# ── 6. Info.plist（換名字與識別碼）
cp "$ROOT/Info.plist" "$APPDIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APPNAME" "$APPDIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APPNAME" "$APPDIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLEID" "$APPDIR/Contents/Info.plist"

# ── 7. 簽章 + 安裝 + 打包
echo "==> 簽章"
codesign --force --deep --sign - "$APPDIR" >/dev/null 2>&1 || echo "（簽章失敗，仍可執行）"

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/$APPNAME.app"
cp -R "$APPDIR" "$HOME/Applications/$APPNAME.app"

# 重新註冊開機啟動：App 重新簽章後，launchd 記住的舊簽章會讓 job spawn failed（EX_CONFIG 78）
AGENT="$HOME/Library/LaunchAgents/$BUNDLEID.plist"
if [ -f "$AGENT" ]; then
  launchctl bootout "gui/$(id -u)/$BUNDLEID" 2>/dev/null || true
  sleep 0.5
  launchctl bootstrap "gui/$(id -u)" "$AGENT" >/dev/null 2>&1 && echo "    已重新註冊開機啟動" || echo "    （開機啟動重新註冊失敗，登入時會再試）"
fi

rm -f "$ROOT/$APPNAME.app.zip"
ditto -c -k --sequesterRsrc --keepParent "$HOME/Applications/$APPNAME.app" "$ROOT/$APPNAME.app.zip"

echo "==> 完成"
echo "    App：~/Applications/${APPNAME}.app（識別碼 ${BUNDLEID}）"
echo "    分享檔：$ROOT/${APPNAME}.app.zip（$(du -h "$ROOT/${APPNAME}.app.zip" | cut -f1)）"
