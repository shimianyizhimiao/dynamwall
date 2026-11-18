#!/usr/bin/env python3
"""圖片像素統計：判斷畫面是否為全黑/空白，並量測色彩豐富度與亮度。
用法： python3 tools/imgstats.py 圖1.png 圖2.png ...
（用 sips 轉成 BMP 後用標準庫解析，不需要 Pillow）
"""
import struct
import subprocess
import sys
import os
import tempfile


def to_bmp(path):
    fd, tmp = tempfile.mkstemp(suffix=".bmp")
    os.close(fd)
    subprocess.run(["sips", "-s", "format", "bmp", path, "--out", tmp],
                   check=True, capture_output=True)
    return tmp


def read_bmp(path):
    with open(path, "rb") as f:
        data = f.read()
    assert data[:2] == b"BM", "不是 BMP"
    offset = struct.unpack_from("<I", data, 10)[0]
    header = struct.unpack_from("<I", data, 14)[0]
    if header >= 40:
        w, h, planes, bpp = struct.unpack_from("<iiHH", data, 18)
        compression = struct.unpack_from("<I", data, 30)[0]
    else:
        w, h = struct.unpack_from("<hh", data, 18)
        planes, bpp = struct.unpack_from("<HH", data, 26)
        compression = 0
    assert compression in (0, 3), f"不支援的壓縮 {compression}"
    h = abs(h)
    stride = ((w * bpp // 8) + 3) // 4 * 4
    return data, offset, w, h, bpp // 8, stride


def stats(path):
    tmp = to_bmp(path)
    try:
        data, offset, w, h, bpp, stride = read_bmp(tmp)
    finally:
        os.unlink(tmp)
    n = 0
    sr = sg = sb = 0
    sr2 = sg2 = sb2 = 0
    colors = set()
    dark = 0
    step = max(1, (w * h) // 120000)  # 取樣上限，速度考量
    for y in range(0, h, 1):
        row = offset + y * stride
        for x in range(0, w, max(1, int(step ** 0.5))):
            p = row + x * bpp
            if p + 3 > len(data):
                continue
            b, g, r = data[p], data[p + 1], data[p + 2]
            n += 1
            sr += r; sg += g; sb += b
            sr2 += r * r; sg2 += g * g; sb2 += b * b
            colors.add((r >> 3, g >> 3, b >> 3))
            if r + g + b < 24:
                dark += 1
    if n == 0:
        return None
    mr, mg, mb = sr / n, sg / n, sb / n
    vr = sr2 / n - mr * mr
    vg = sg2 / n - mg * mg
    vb = sb2 / n - mb * mb
    return {
        "檔案": os.path.basename(path),
        "尺寸": f"{w}x{h}",
        "取樣點": n,
        "平均亮度": round((mr + mg + mb) / 3, 1),
        "色彩標準差": round((vr + vg + vb) ** 0.5, 1),
        "近似色數": len(colors),
        "全黑比例": round(dark / n, 3),
    }


for p in sys.argv[1:]:
    s = stats(p)
    print(" | ".join(f"{k}={v}" for k, v in s.items()))
