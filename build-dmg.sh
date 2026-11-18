#!/bin/bash
# 把 App 打包成 DMG（拖進去就安裝的排版：左邊 App、右邊 Applications、背景說明）
#   用法： ./build-dmg.sh "<App 路徑>" "<磁碟名稱>" ["標題文字"]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="${1:?請給 .app 路徑}"
VOLNAME="${2:?請給磁碟名稱}"
TITLE="${3:-$(basename "$APP_SRC" .app)}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

[ -d "$APP_SRC" ] || { echo "找不到 App：$APP_SRC"; exit 1; }
APPNAME="$(basename "$APP_SRC")"
WORK="$ROOT/build-dmg"
STAGE="$WORK/stage"
TMP_DMG="$WORK/tmp-rw.dmg"
OUT="$ROOT/$VOLNAME.dmg"
MOUNT="/Volumes/$VOLNAME"

rm -rf "$WORK"; mkdir -p "$STAGE/.background"

# ── 1. 內容：App ＋ Applications 連結 ＋ 說明
cp -R "$APP_SRC" "$STAGE/$APPNAME"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/使用說明.txt" <<TXT
$TITLE —— macOS 動態壁紙

安裝：把左邊的「${APPNAME}」拖到右邊的 Applications 資料夾，
      然後在「應用程式」裡雙擊它。

第一次打開：請在 App 上按右鍵 →「打開」→ 再按一次「打開」
（這是因為它不是從 App Store 下載的，macOS 會先擋一次；之後就正常了）

要移除：把 App 丟到垃圾桶，再刪掉
      ~/Library/Application Support/動態壁紙-<識別碼後綴>/
TXT

# ── 2. 背景圖（給 Finder 用的說明圖）
echo "==> 產生背景圖"
python3 "$ROOT/tools/dmg_background.py" "$TITLE" "$ROOT/$VOLNAME.dmg.bg" 2>/dev/null || true
if [ -f "$ROOT/$VOLNAME.dmg.bg/_page.html" ] && [ -x "$CHROME" ]; then
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size=1600,1000 --virtual-time-budget=2500 \
    --screenshot="$STAGE/.background/bg.png" \
    "file://$ROOT/$VOLNAME.dmg.bg/_page.html" >/dev/null 2>&1 || true
fi

# ── 3. 建立可讀寫 DMG 並掛載
echo "==> 建立 DMG"
hdiutil create -srcfolder "$STAGE" -volname "$VOLNAME" -fs HFS+ -format UDRW -ov "$TMP_DMG" >/dev/null
hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen >/dev/null
sleep 2

# ── 4. Finder 排版（失敗不影響 DMG 可用）
echo "==> 排版"
osascript <<AS || echo "（排版失敗，DMG 仍可用）"
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 1000, 660}
    set vo to the icon view options of container window
    set arrangement of vo to not arranged
    set icon size of vo to 128
    try
      set background picture of vo to file ".background:bg.png"
    end try
    set position of item "$APPNAME" of container window to {200, 300}
    set position of item "Applications" of container window to {600, 300}
    set position of item "使用說明.txt" of container window to {400, 470}
    update without registering applications
    delay 2
    close
  end tell
end tell
AS

# ── 5. 磁碟圖示（可選）
if [ -f "$APP_SRC/Contents/Resources/AppIcon.icns" ]; then
  cp "$APP_SRC/Contents/Resources/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
  SetFile -a C "$MOUNT" 2>/dev/null || true
fi
sync; sleep 1

# ── 6. 卸載 + 壓縮
echo "==> 壓縮"
hdiutil detach "$MOUNT" >/dev/null 2>&1 || hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
sleep 1
rm -f "$OUT"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null

echo "==> 驗證"
hdiutil verify "$OUT" | tail -1
hdiutil attach "$OUT" -readonly -noverify -noautoopen >/dev/null
sleep 2
if [ -d "$MOUNT/$APPNAME" ] && [ -L "$MOUNT/Applications" ]; then
  echo "    內容檢查：App ✓　Applications 連結 ✓　說明檔 $([ -f "$MOUNT/使用說明.txt" ] && echo ✓ || echo ✗)"
  codesign --verify --deep --strict "$MOUNT/$APPNAME" 2>/dev/null && echo "    簽章檢查：✓" || echo "    簽章檢查：✗"
else
  echo "    內容檢查：失敗"
fi
hdiutil detach "$MOUNT" >/dev/null 2>&1 || hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true

echo "==> 完成：${OUT}（$(du -h "$OUT" | cut -f1)）"
