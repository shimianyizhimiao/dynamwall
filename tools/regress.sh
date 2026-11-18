#!/bin/bash
# 動態壁紙 回歸測試（會暫時改變桌面壁紙，結束後還原）
set -uo pipefail
APP="$HOME/Applications/動態壁紙.app/Contents/MacOS/DynWall"
CFG="$HOME/Library/Application Support/動態壁紙/config.json"
LOG="$HOME/Library/Logs/動態壁紙.log"
WEB="$HOME/Library/Application Support/動態壁紙/wallpapers/極光（可編輯）/index.html"
PASS=0; FAIL=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

cp "$CFG" /tmp/cfg-regress-bak.json
# 海報測試需要 poster=true，輪換會干擾測試：測試期間強制打開，C 段會還原使用者的設定
python3 - "$CFG" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["poster"] = True
d["rotationOn"] = False
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
EOF
pkill -f 'MacOS/DynWall' 2>/dev/null; sleep 2
: > "$LOG"

echo "── A. 壁紙庫 / 縮圖 / 預覽 / 套用 / 海報 ──"
DYN_DEBUG=1 "$APP" --gui-test >/dev/null 2>&1 &
P=$!
sleep 30
kill $P 2>/dev/null; sleep 2

ITEMS=$(grep -o "LIBRARY-OPEN items=[0-9]*" "$LOG" | head -1 | cut -d= -f2)
[ -n "${ITEMS:-}" ] && [ "$ITEMS" -gt 0 ] && ok "壁紙庫載入 $ITEMS 個項目" || bad "壁紙庫沒有載入項目"

THUMB=$(grep -o "GUITEST thumbs t=[0-9.]*s → [0-9]*/[0-9]*" "$LOG" | tail -1)
GOT=0
TOT=0
if [ -n "${THUMB:-}" ]; then
  GOT=$(python3 -c 'import re,sys; m=re.search(r"(\d+)/(\d+)", sys.argv[1]); print(m.group(1) if m else 0)' "$THUMB")
  TOT=$(python3 -c 'import re,sys; m=re.search(r"(\d+)/(\d+)", sys.argv[1]); print(m.group(2) if m else 0)' "$THUMB")
fi
if [ "$TOT" -gt 0 ] && [ "$GOT" = "$TOT" ]; then
  ok "縮圖全部完成（${GOT}/${TOT}）"
else
  bad "縮圖未完成（${GOT}/${TOT}）"
fi

grep -q "GUITEST applied current=true" "$LOG" && ok "套用壁紙成功（current=true）" || bad "套用壁紙失敗"
grep -q "GUITEST settings dim=0.3 rate=1.5 gravity=fit" "$LOG" && ok "設定項可調整（暗化／速度／縮放）" || bad "設定項沒有套用"
grep -q "POSTER screen=" "$LOG" && ok "靜態海報有產生" || bad "沒有海報紀錄"

echo "── B. HTML 熱重載 ──"
if [ -f "$WEB" ]; then
  : > "$LOG"
  DYN_DEBUG=1 "$APP" --set web "$WEB" >/dev/null 2>&1 &
  P=$!
  sleep 8
  MARK="<!-- regress $(date +%s) -->"
  printf '%s\n' "$MARK" >> "$WEB"
  sleep 4
  kill $P 2>/dev/null; sleep 2
  grep -q "RELOAD 熱重載" "$LOG" && ok "存檔後自動熱重載（$(grep -o 'RELOAD.*' "$LOG" | head -1)）" || bad "熱重載沒有觸發"
  # 把測試註解拿掉
  /usr/bin/sed -i '' "/regress [0-9]*/d" "$WEB"
else
  bad "找不到自訂範本 $WEB"
fi

echo "── C. 還原你的設定與壁紙 ──"
cp /tmp/cfg-regress-bak.json "$CFG"
pkill -f 'MacOS/DynWall' 2>/dev/null; sleep 2
open "$HOME/Applications/動態壁紙.app"; sleep 8
pgrep -f 'MacOS/DynWall' >/dev/null && ok "已還原並重新啟動壁紙" || bad "還原後 App 沒起來"

echo
echo "結果：通過 ${PASS}，失敗 ${FAIL}"
