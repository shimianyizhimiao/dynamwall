#!/usr/bin/env python3
"""產生 DMG 背景圖用的 HTML（給 headless Chrome 截圖）。
用法： dmg_background.py "<標題>" "<輸出資料夾>"
背景圖尺寸 1600x1000（對應 Finder 視窗 800x500 點，Retina 也清楚）。
"""
import os
import sys

title, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)

html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
  html, body {{ margin: 0; padding: 0; width: 1600px; height: 1000px; }}
  body {{
    background: radial-gradient(circle at 50% 0%, #1d2a4a 0%, #0d1220 55%, #070a12 100%);
    font-family: -apple-system, "PingFang TC", "Heiti TC", sans-serif;
    color: #e8eefc; position: relative; overflow: hidden;
  }}
  .glow {{ position: absolute; width: 900px; height: 900px; border-radius: 50%;
          background: radial-gradient(circle, rgba(80,160,255,.22), transparent 70%);
          left: 350px; top: -420px; }}
  h1 {{ position: absolute; top: 52px; width: 100%; text-align: center;
       font-size: 54px; font-weight: 700; letter-spacing: 2px; margin: 0; }}
  .sub {{ position: absolute; top: 128px; width: 100%; text-align: center;
         font-size: 26px; color: #9fb4d8; letter-spacing: 1px; }}
  .arrow {{ position: absolute; left: 470px; top: 275px; width: 640px; height: 60px; }}
  .arrow svg {{ width: 100%; height: 100%; }}
  .tip {{ position: absolute; top: 620px; width: 100%; text-align: center;
         font-size: 27px; color: #ffd479; }}
  .tip2 {{ position: absolute; top: 668px; width: 100%; text-align: center;
          font-size: 22px; color: #8fa3c4; }}
  .foot {{ position: absolute; bottom: 40px; width: 100%; text-align: center;
          font-size: 21px; color: #6d80a0; letter-spacing: 1px; }}
</style></head><body>
  <div class="glow"></div>
  <h1>{title}</h1>
  <div class="sub">macOS 動態壁紙・影片／HTML 動畫／GIF</div>
  <div class="arrow">
    <svg viewBox="0 0 640 60" preserveAspectRatio="none">
      <defs><linearGradient id="g" x1="0" x2="1">
        <stop offset="0" stop-color="#4f9dff" stop-opacity=".25"/>
        <stop offset="1" stop-color="#7ce7c0" stop-opacity=".95"/>
      </linearGradient></defs>
      <path d="M10 30 H 540" stroke="url(#g)" stroke-width="9" stroke-linecap="round"
            stroke-dasharray="26 20"/>
      <path d="M540 8 L 618 30 L 540 52 Z" fill="#7ce7c0"/>
    </svg>
  </div>
  <div class="tip">把左邊的 App 拖到右邊的 Applications 就安裝好了</div>
  <div class="tip2">第一次打開請按右鍵 →「打開」→ 再按一次「打開」</div>
  <div class="foot">拖曳安裝 · 完全離線 · 不需要任何權限</div>
</body></html>
"""

path = os.path.join(outdir, "_page.html")
with open(path, "w", encoding="utf-8") as f:
    f.write(html)
print(path)
