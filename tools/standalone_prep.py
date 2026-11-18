#!/usr/bin/env python3
"""把要打包的媒體檔換算成「類型、副檔名、App 內部安全檔名」。
輸出：一行三個值（空白分隔）：kind ext destname
"""
import os
import re
import sys

media, title = sys.argv[1], sys.argv[2]
ext = os.path.splitext(media)[1].lstrip(".").lower()
VIDEO = {"mp4", "mov", "m4v", "avi", "mkv"}
IMAGE = {"gif", "png", "jpg", "jpeg", "heic", "webp", "bmp", "tiff"}

kind = "video" if ext in VIDEO else ("image" if ext in IMAGE else "video")
safe = re.sub(r'[\\/:*?"<>|()\s\u3000]+', "", title) or "wallpaper"
print(f"{kind} {ext} {safe}.{ext}")
