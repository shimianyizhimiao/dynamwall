#!/usr/bin/env python3
"""抓一批「沒有版權問題」的壁紙：NASA Image and Video Library（公有領域）。

用法：python3 tools/fetch_wallpapers.py [數量]
輸出：resources/wallpapers/static/*.jpg + CREDITS.md
"""
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "resources", "wallpapers", "static")
UA = {"User-Agent": "DynWall/1.0 (wallpaper pack; contact: local user)"}

# 每個主題抓幾張；NASA 的圖都是公有領域（NASA Media Usage Guidelines）
THEMES = [
    ("nebula", "星雲"),
    ("earth from space", "地球"),
    ("aurora from space", "極光"),
    ("galaxy stars", "星系"),
    ("moon surface", "月球"),
    ("saturn", "土星"),
    ("mars surface", "火星"),
    ("ocean from space", "海洋"),
    ("city lights at night", "夜景"),
    ("himalaya", "山脈"),
    ("jupiter", "木星"),
]


def api(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def candidates(theme_id):
    q = urllib.parse.quote(theme_id)
    d = api(f"https://images-api.nasa.gov/search?q={q}&media_type=image&page_size=8")
    out = []
    for it in d["collection"]["items"]:
        md = it["data"][0]
        for link in it.get("links", []):
            href = link.get("href", "")
            if href.endswith(("~orig.jpg", "~large.jpg")):
                out.append((md.get("nasa_id", ""), md.get("title", "").strip(), href))
                break
    return out


def download(url, dest):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r, open(dest, "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    return os.path.getsize(dest)


def is_jpeg(path):
    with open(path, "rb") as f:
        return f.read(3) == b"\xff\xd8\xff"


def main():
    want = int(sys.argv[1]) if len(sys.argv) > 1 else 8
    os.makedirs(OUT, exist_ok=True)
    credits = []
    got = 0
    for theme_id, theme_zh in THEMES:
        if got >= want:
            break
        try:
            cands = candidates(theme_id)
        except Exception as e:
            print(f"  跳過 {theme_id}：{e}")
            continue
        taken = 0
        for nasa_id, title, url in cands:
            if got >= want or taken >= 1:   # 每個主題只拿一張，保持多樣性
                break
            slug = f"{theme_id.split()[0]}-{nasa_id[:24]}".replace(" ", "-").lower()
            tmp = f"/tmp/nasa-{slug}.jpg"
            dest = os.path.join(OUT, slug + ".jpg")
            if os.path.exists(dest):      # 抓過的不要重抓
                got += 1
                taken += 1
                break
            try:
                size = download(url, tmp)
            except Exception as e:
                print(f"  下載失敗 {nasa_id}：{e}")
                continue
            if size < 200_000 or not is_jpeg(tmp):
                print(f"  跳過 {nasa_id}（{size/1e6:.1f}MB，不是有效 JPEG）")
                continue
            # 統一縮到 3840 寬、存成 JPEG 88
            subprocess.run(["sips", "-Z", "3840", "-s", "format", "jpeg",
                            "-s", "formatOptions", "88", tmp, "--out", dest],
                           capture_output=True)
            os.remove(tmp)
            w = subprocess.run(["sips", "-g", "pixelWidth", dest], capture_output=True, text=True).stdout
            width = int(w.split("pixelWidth:")[1].split()[0])
            if width < 1600:
                os.remove(dest)
                print(f"  跳過 {nasa_id}（太小 {width}px）")
                continue
            got += 1
            taken += 1
            credits.append({
                "file": slug + ".jpg",
                "title": title,
                "theme": theme_zh,
                "nasa_id": nasa_id,
                "source": f"https://images.nasa.gov/details/{nasa_id}",
                "license": "NASA — public domain (NASA Media Usage Guidelines)",
            })
            print(f"  ✓ {theme_zh}：{title[:40]} → {slug}.jpg（{width}px）")

    with open(os.path.join(OUT, "CREDITS.md"), "w", encoding="utf-8") as f:
        f.write("# 精選壁紙來源與授權\n\n")
        f.write("本資料夾的圖片全部來自 **NASA Image and Video Library**，"
                "依 [NASA Media Usage Guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/) 屬於**公有領域**，"
                "可自由使用、修改與再散布（NASA 不因此背書本專案）。\n\n")
        f.write("| 檔案 | 標題 | 主題 | 來源 |\n|---|---|---|---|\n")
        for c in credits:
            f.write(f"| `{c['file']}` | {c['title']} | {c['theme']} | [NASA {c['nasa_id']}]({c['source']}) |\n")
    print(f"\n共 {got} 張，寫入 {OUT}")


if __name__ == "__main__":
    main()
