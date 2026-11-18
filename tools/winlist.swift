// 小工具：列出目前系統所有視窗（含圖層層級），用來檢查壁紙視窗的疊放順序
// 編譯： swiftc -O tools/winlist.swift -o build/winlist -framework Cocoa
import Cocoa

let all = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

print("=== 全部視窗（前 → 後）===")
for (idx, w) in all.enumerated() {
    let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
    let name = w[kCGWindowName as String] as? String ?? ""
    let layer = w[kCGWindowLayer as String] as? Int ?? -9999
    let num = w[kCGWindowNumber as String] as? Int ?? -1
    let alpha = w[kCGWindowAlpha as String] as? Double ?? -1
    let onsc = (w[kCGWindowIsOnscreen as String] as? Bool) ?? false
    var b = CGRect.zero
    if let d = w[kCGWindowBounds as String] as? [String: Any],
       let r = CGRect(dictionaryRepresentation: d as CFDictionary) { b = r }
    print(String(format: "idx=%3d id=%-7d layer=%-12d alpha=%.2f onscreen=%@ %@%@ bounds=%.0f,%.0f,%.0fx%.0f",
                 idx, num, layer, alpha, onsc ? "Y" : "N", owner, name.isEmpty ? "" : " / \(name)",
                 b.origin.x, b.origin.y, b.width, b.height))
}

print("=== 螢幕上（不含桌面元素）===")
for (idx, w) in onScreen.enumerated() {
    let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
    let name = w[kCGWindowName as String] as? String ?? ""
    let layer = w[kCGWindowLayer as String] as? Int ?? -9999
    let num = w[kCGWindowNumber as String] as? Int ?? -1
    print("idx=\(idx) id=\(num) layer=\(layer) \(owner) / \(name)")
}
