// Required Notice: Copyright (c) 2026 shimianyizhimiao — 動態壁紙 / DynWall
// 授權：PolyForm Noncommercial 1.0.0 + Share-Alike 附加條款（見 LICENSE）
// 禁止商業使用；修改後散布必須以相同條款公開原始碼。

//  動態壁紙 — 圖形化壁紙庫（像 Wallpaper Engine 那樣）
//  左邊：壁紙庫（縮圖格狀）　右邊：即時預覽 + 設定
import Cocoa
import SwiftUI
import AVFoundation
import WebKit
import UniformTypeIdentifiers
import ImageIO

// MARK: ───────────────────────── 壁紙項目

final class WallpaperItem: Identifiable, ObservableObject {
    /// 卡片上顯示的名字：檔名清乾淨（去掉 (1)、底線、副檔名）
    var displayTitle: String {
        var t = title
        if let dot = t.lastIndex(of: "."), t.distance(from: t.startIndex, to: dot) > 3,
           ["mp4", "mov", "m4v", "png", "jpg", "jpeg", "heic", "gif", "html"].contains(t.suffix(4).lowercased())
            || ["mp4", "mov", "m4v", "png", "jpg", "jpeg", "heic", "gif", "html"].contains(t.suffix(5).lowercased()) {
            t = String(t[..<dot])
        }
        t = t.replacingOccurrences(of: "_", with: " ")
        for _ in 0..<3 {
            t = t.replacingOccurrences(of: #"\s*\(\d+\)$"#, with: "", options: .regularExpression)
        }
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespaces)
        if t.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil {
            switch kind {
            case "video": return "影片 \(t)"
            case "image": return "圖片 \(t)"
            default: return t
            }
        }
        return t
    }
    let id: String
    let kind: String            // builtin | video | image | web
    let ref: String
    let title: String
    let canDelete: Bool
    @Published var subtitle: String
    @Published var thumb: NSImage?
    @Published var badge: String?

    init(id: String, kind: String, ref: String, title: String, subtitle: String, canDelete: Bool) {
        self.id = id
        self.kind = kind
        self.ref = ref
        self.title = title
        self.subtitle = subtitle
        self.canDelete = canDelete
    }
}

let LIBRARY_DIR = SUPPORT_DIR.appendingPathComponent("library", isDirectory: true)

let VIDEO_EXTS: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]
let IMAGE_EXTS: Set<String> = ["gif", "png", "jpg", "jpeg", "heic", "webp", "bmp", "tiff", "avif"]

// MARK: ───────────────────────── 掃描壁紙庫

let STATIC_THEME_NAMES: [String: String] = [
    "nebula": "星雲", "earth": "地球", "aurora": "極光", "galaxy": "星系",
    "moon": "月球", "mars": "火星", "ocean": "海洋", "city": "城市夜景",
    "himalaya": "喜馬拉雅", "jupiter": "木星",
]

/// App 內附的精選靜態壁紙（NASA 公有領域，見 Resources/wallpapers/static/CREDITS.md）
func builtinStaticFiles() -> [URL] {
    guard let dir = Bundle.main.url(forResource: "static", withExtension: nil, subdirectory: "wallpapers") else { return [] }
    let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    return files.filter { $0.pathExtension.lowercased() == "jpg" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

func scanLibrary() -> [WallpaperItem] {
    var out: [WallpaperItem] = []
    for id in builtinIDs() {
        out.append(WallpaperItem(id: "builtin:\(id)", kind: "builtin", ref: id,
                                 title: BUILTIN_TITLES[id] ?? id,
                                 subtitle: "內建動態壁紙", canDelete: false))
    }
    for u in builtinStaticFiles() {
        let slug = u.deletingPathExtension().lastPathComponent
        let theme = slug.split(separator: "-").first.map(String.init) ?? slug
        let name = STATIC_THEME_NAMES[theme] ?? slug
        let rel = "@bundle:wallpapers/static/\(u.lastPathComponent)"
        out.append(WallpaperItem(id: "image:\(rel)", kind: "image", ref: rel,
                                 title: "NASA・\(name)", subtitle: "精選靜態・公有領域", canDelete: false))
    }
    try? fm.createDirectory(at: LIBRARY_DIR, withIntermediateDirectories: true)
    if let items = try? fm.contentsOfDirectory(at: LIBRARY_DIR, includingPropertiesForKeys: nil) {
        for u in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if u.lastPathComponent.hasPrefix(".") { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: u.path, isDirectory: &isDir) else { continue }
            let name = u.deletingPathExtension().lastPathComponent
            if isDir.boolValue {
                let idx = u.appendingPathComponent("index.html")
                if fm.fileExists(atPath: idx.path) {
                    out.append(WallpaperItem(id: "web:\(idx.path)", kind: "web", ref: idx.path,
                                             title: name, subtitle: "HTML 動畫", canDelete: true))
                }
            } else {
                let ext = u.pathExtension.lowercased()
                if VIDEO_EXTS.contains(ext) {
                    let mb = (try? fm.attributesOfItem(atPath: u.path)[.size] as? Int).flatMap { $0 }.map { Double($0) / 1_048_576 } ?? 0
                    out.append(WallpaperItem(id: "video:\(u.path)", kind: "video", ref: u.path,
                                             title: name, subtitle: String(format: "影片・%.0f MB", mb), canDelete: true))
                } else if IMAGE_EXTS.contains(ext) {
                    out.append(WallpaperItem(id: "image:\(u.path)", kind: "image", ref: u.path,
                                             title: name, subtitle: "圖片・\(ext.uppercased())", canDelete: true))
                }
            }
        }
    }
    for e in customEntries() where !out.contains(where: { $0.ref == e.path }) {
        out.append(WallpaperItem(id: "web:\(e.path)", kind: "web", ref: e.path,
                                 title: e.title, subtitle: "我的 HTML", canDelete: false))
    }
    return out
}

// MARK: ───────────────────────── 縮圖產生

final class Thumbnailer {
    static let shared = Thumbnailer()
    private var jobs: [SnapshotJob] = []
    private var busyWeb: Set<String> = []
    private let queue = DispatchQueue(label: "thumb", qos: .utility)

    func cacheURL(_ key: String) -> URL {
        let dir = CACHE_DIR.appendingPathComponent("thumbs", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var h: UInt64 = 1469598103934665603
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return dir.appendingPathComponent(String(h, radix: 16) + ".jpg")
    }

    func thumb(for item: WallpaperItem, size: CGSize = CGSize(width: 640, height: 400),
               done: @escaping (NSImage?, String?) -> Void) {
        switch item.kind {
        case "builtin":
            if let u = Bundle.main.url(forResource: item.ref, withExtension: "jpg", subdirectory: "thumbs"),
               let img = NSImage(contentsOf: u) {
                done(img, nil); return
            }
            if let u = builtinURL(item.ref) { webSnapshot(u, size: size, done: done); return }
            done(nil, nil)
        case "video":
            videoThumb(URL(fileURLWithPath: item.ref), size: size, done: done)
        case "image":
            let path = resolveRef(item.ref)
            if let img = NSImage(contentsOfFile: path) {
                done(img, imageInfo(URL(fileURLWithPath: path)))
            } else { done(nil, nil) }
        default:
            webSnapshot(URL(fileURLWithPath: item.ref), size: size, done: done)
        }
    }

    private func imageInfo(_ u: URL) -> String {
        guard let rep = NSImageRep(contentsOf: u) else { return "圖片" }
        return "圖片・\(rep.pixelsWide)×\(rep.pixelsHigh)"
    }

    private func videoThumb(_ url: URL, size: CGSize, done: @escaping (NSImage?, String?) -> Void) {
        let cache = cacheURL(url.path + "|video")
        if let img = NSImage(contentsOf: cache) {
            queue.async { done(img, self.videoInfo(url)) }
            return
        }
        queue.async {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = size
            gen.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
            gen.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
            let info = self.videoInfo(url)
            let sem = DispatchSemaphore(value: 0)
            Task {
                let img: NSImage?
                if let cg = try? await gen.image(at: CMTime(seconds: 2, preferredTimescale: 600)).image {
                    img = NSImage(cgImage: cg, size: .zero)
                    if let i = img, let tiff = i.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                        try? data.write(to: cache)
                    }
                } else { img = nil }
                sem.signal()
                DispatchQueue.main.async { done(img, info) }
            }
            sem.wait()
        }
    }

    private func videoInfo(_ url: URL) -> String {
        let asset = AVURLAsset(url: url)
        var dur = 0.0
        var res = ""
        let sem = DispatchSemaphore(value: 0)
        Task {
            dur = (try? await asset.load(.duration)).map { CMTimeGetSeconds($0) } ?? 0
            if let t = try? await asset.loadTracks(withMediaType: .video).first {
                let s = (try? await t.load(.naturalSize)) ?? .zero
                let tf = (try? await t.load(.preferredTransform)) ?? .identity
                let shown = s.applying(tf)
                let fps = (try? await t.load(.nominalFrameRate)) ?? 0
                res = "\(Int(abs(shown.width)))×\(Int(abs(shown.height)))・\(Int(fps))fps"
            }
            sem.signal()
        }
        sem.wait()
        return "影片・\(Int(dur)) 秒・\(res)"
    }

    private func webSnapshot(_ url: URL, size: CGSize, done: @escaping (NSImage?, String?) -> Void) {
        let cache = cacheURL(url.path + "|web")
        if let img = NSImage(contentsOf: cache) { done(img, nil); return }
        if busyWeb.contains(url.path) { done(nil, nil); return }
        busyWeb.insert(url.path)
        let job = SnapshotJob(url: url, size: size, cache: cache) { [weak self] finishedJob, img in
            guard let self = self else { return }
            self.busyWeb.remove(finishedJob.key)
            self.jobs.removeAll { $0 === finishedJob }
            done(img, nil)
        }
        jobs.append(job)
    }
}

final class SnapshotJob: NSObject, WKNavigationDelegate {
    let key: String
    private let webView: WKWebView
    private let holder: NSWindow
    private let cache: URL
    private let size: CGSize
    private let completion: (SnapshotJob, NSImage?) -> Void
    private var finished = false
    private var timeout: DispatchWorkItem?

    init(url: URL, size: CGSize, cache: URL, completion: @escaping (SnapshotJob, NSImage?) -> Void) {
        self.key = url.path
        self.size = size
        self.cache = cache
        self.completion = completion
        let conf = WKWebViewConfiguration()
        // 離螢幕的 WebView 會被 WebKit 節流，導致截圖很慢 → 關掉這個行為
        _ = DynSetPreferenceSafe(conf.preferences, "pageVisibilityBasedProcessSuppressionEnabled", NSNumber(value: false))
        webView = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: conf)
        holder = NSWindow(contentRect: CGRect(x: -20000, y: -20000, width: size.width, height: size.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        holder.contentView = webView
        holder.orderBack(nil)
        webView.navigationDelegate = self
        let wi = DispatchWorkItem { [weak self] in self?.finish() }
        timeout = wi
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0, execute: wi)
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in self?.finish() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish() }

    private func finish() {
        guard !finished else { return }
        finished = true
        timeout?.cancel()
        let sc = WKSnapshotConfiguration()
        sc.rect = CGRect(origin: .zero, size: size)
        webView.takeSnapshot(with: sc) { [weak self] img, _ in
            guard let self = self else { return }
            if let img = img, let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                try? data.write(to: self.cache)
            }
            self.holder.orderOut(nil)
            self.completion(self, img)
        }
    }
}

// MARK: ───────────────────────── 與壁紙引擎的橋樑

final class Engine: ObservableObject {
    static let shared = Engine()
    weak var app: AppDelegate?
    var config: Config { app?.cfg ?? Config() }
    func apply(kind: String, ref: String) { app?.guiApply(kind: kind, ref: ref) }
    func setRate(_ v: Double) { app?.guiSetRate(v) }
    func setGravity(_ v: String) { app?.guiSetGravity(v) }
    func setDim(_ v: Double) { app?.guiSetDim(v) }
    func setMute(_ v: Bool) { app?.guiSetMute(v) }
    func setInteractive(_ v: Bool) { app?.guiSetInteractive(v) }
    func setPaused(_ v: Bool) { app?.guiSetPaused(v) }
    func setAutoStart(_ v: Bool) { app?.guiSetAutoStart(v) }
    func setPoster(_ v: Bool) { app?.guiSetPoster(v) }
    func setParallax(_ on: Bool, _ amount: Double) { app?.guiSetParallax(on, amount) }
    func setRotation(_ on: Bool, _ minutes: Double) { app?.guiSetRotation(on, minutes) }
    func setPauseOnFullscreen(_ on: Bool) { app?.guiSetPauseOnFullscreen(on) }
    func setLockPoster(_ on: Bool) { app?.guiSetLockPoster(on) }
    func setLockVideo(_ on: Bool) { app?.guiSetLockVideo(on) }
    var lockVideoProgress: String { app?.lockVideoProgress ?? "" }
}

// MARK: ───────────────────────── 資料模型

final class LibraryModel: ObservableObject {
    @Published var items: [WallpaperItem] = []
    @Published var filter = "全部"
    @Published var search = ""
    @Published var sort = "名稱"
    @Published var selectedID: String?

    let sorts = ["名稱", "類型", "最近加入"]
    @Published var cfg = Config()
    @Published var message = ""
    @Published var importing = false

    // 探索頁：分頁 / 分類 / 最愛
    enum Page: String, CaseIterable, Identifiable {
        case home = "首頁", still = "靜態", motion = "動態", mine = "我的"
        var id: String { rawValue }
    }
    @Published var page: Page = .home
    @Published var category: String = "全部"
    @Published var favorites: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "favIDs") ?? [])

    /// 分類晶片：名稱 / SF Symbol / 顏色
    let categories: [(String, String, Color)] = [
        ("全部", "sparkles", Color(red: 0.36, green: 0.52, blue: 1.0)),
        ("動態", "play.rectangle.fill", Color(red: 0.62, green: 0.42, blue: 1.0)),
        ("靜態", "photo.fill", Color(red: 0.20, green: 0.72, blue: 0.72)),
        ("NASA", "globe.americas.fill", Color(red: 0.95, green: 0.55, blue: 0.25)),
        ("HTML", "chevron.left.forwardslash.chevron.right", Color(red: 0.35, green: 0.75, blue: 0.45)),
        ("最愛", "heart.fill", Color(red: 0.95, green: 0.35, blue: 0.55)),
    ]

    let hotWords = ["星雲", "極光", "太空", "雨", "賽博", "城市", "山", "月"]

    func toggleFav(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        UserDefaults.standard.set(Array(favorites), forKey: "favIDs")
    }

    func isFav(_ id: String) -> Bool { favorites.contains(id) }

    /// 目前分頁 + 分類 + 搜尋後的清單
    var pageItems: [WallpaperItem] {
        var list = filtered
        switch page {
        case .still:  list = list.filter { $0.kind == "image" }
        case .motion: list = list.filter { $0.kind != "image" }
        case .mine:   list = list.filter { favorites.contains($0.id) }
        case .home:   break
        }
        switch category {
        case "動態": list = list.filter { $0.kind != "image" }
        case "靜態": list = list.filter { $0.kind == "image" }
        case "NASA": list = list.filter { $0.title.hasPrefix("NASA") }
        case "HTML": list = list.filter { $0.kind == "web" }
        case "最愛": list = list.filter { favorites.contains($0.id) }
        default: break
        }
        return list
    }

    let filters = ["全部", "內建", "影片", "圖片", "我的 HTML"]

    var filtered: [WallpaperItem] {
        let list = items.filter { it in
            let okFilter: Bool
            switch filter {
            case "內建": okFilter = it.kind == "builtin"
            case "影片": okFilter = it.kind == "video"
            case "圖片": okFilter = it.kind == "image"
            case "我的 HTML": okFilter = it.kind == "web"
            default: okFilter = true
            }
            let okSearch = search.isEmpty || it.title.localizedCaseInsensitiveContains(search)
            return okFilter && okSearch
        }
        switch sort {
        case "類型":
            return list.sorted { a, b in
                a.kind == b.kind ? a.title.localizedStandardCompare(b.title) == .orderedAscending : a.kind < b.kind
            }
        case "最近加入":
            return list.sorted { fileDate($0) > fileDate($1) }
        default:
            return list.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    private func fileDate(_ it: WallpaperItem) -> Date {
        if it.kind == "builtin" { return .distantPast }
        let u = URL(fileURLWithPath: it.ref)
        return (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    func reveal(_ it: WallpaperItem) {
        if it.kind == "builtin" {
            let dir = Bundle.main.resourceURL?.appendingPathComponent("wallpapers/\(it.ref)") ?? LIBRARY_DIR
            NSWorkspace.shared.activateFileViewerSelecting([dir])
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: it.ref)])
    }

    func editHTML(_ it: WallpaperItem) {
        let u = URL(fileURLWithPath: it.ref)
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        if fm.fileExists(atPath: textEdit.path) {
            NSWorkspace.shared.open([u], withApplicationAt: textEdit,
                                    configuration: NSWorkspace.OpenConfiguration())
            message = "用文字編輯器打開 index.html，存檔就會即時更新"
        } else {
            NSWorkspace.shared.open(u)
        }
    }

    /// 鍵盤上下移動選取
    func step(_ delta: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        let idx = list.firstIndex { $0.id == selectedID } ?? 0
        selectedID = list[min(max(0, idx + delta), list.count - 1)].id
    }

    func applySelected() { if let s = selected { apply(s) } }

    var selected: WallpaperItem? { items.first { $0.id == selectedID } }

    func refresh() {
        try? fm.createDirectory(at: LIBRARY_DIR, withIntermediateDirectories: true)
        items = scanLibrary()
        cfg = Engine.shared.config
        if selectedID == nil { selectedID = items.first?.id }
        loadThumbs()
    }

    func loadThumbs() {
        for it in items where it.thumb == nil {
            Thumbnailer.shared.thumb(for: it) { img, info in
                DispatchQueue.main.async {
                    it.thumb = img
                    if let info = info, !info.isEmpty { it.subtitle = info }
                }
            }
        }
    }

    func isCurrent(_ it: WallpaperItem) -> Bool {
        let c = Engine.shared.config
        return c.kind == it.kind && resolveRef(c.ref) == resolveRef(it.ref)
    }

    func apply(_ it: WallpaperItem) {
        Engine.shared.apply(kind: it.kind, ref: it.ref)
        cfg = Engine.shared.config
        message = "已套用「\(it.title)」到桌面"
    }

    func delete(_ it: WallpaperItem) {
        guard it.canDelete else { return }
        var target = URL(fileURLWithPath: it.ref)
        if it.kind == "web" { target = target.deletingLastPathComponent() }
        try? fm.trashItem(at: target, resultingItemURL: nil)
        message = "已把「\(it.title)」移到垃圾桶"
        if selectedID == it.id { selectedID = nil }
        refresh()
    }

    func addFiles(_ urls: [URL]) {
        var added = 0
        for u in urls {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: u.path, isDirectory: &isDir) else { continue }
            let dest = LIBRARY_DIR.appendingPathComponent(u.lastPathComponent)
            try? fm.removeItem(at: dest)
            if (try? fm.copyItem(at: u, to: dest)) != nil { added += 1 }
        }
        message = added > 0 ? "已加入 \(added) 個項目" : "沒有加入任何檔案"
        refresh()
    }

    func pickFiles() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = true
        p.canChooseDirectories = true
        p.message = "選擇影片 / 圖片 / GIF / HTML 資料夾（會複製到壁紙庫，原檔不會被動到）"
        if p.runModal() == .OK { addFiles(p.urls) }
    }

    func importBuiltinsAsTemplates() -> Int {
        guard let app = Engine.shared.app else { return 0 }
        let n = app.doCopyTemplates().count
        refresh()
        message = "已複製 \(n) 個可編輯範本"
        return n
    }

    func openLibraryFolder() {
        try? fm.createDirectory(at: LIBRARY_DIR, withIntermediateDirectories: true)
        NSWorkspace.shared.open(LIBRARY_DIR)
    }
}

// MARK: ───────────────────────── 即時預覽

final class PreviewBox: NSView {
    private var shownID = ""
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    func show(_ item: WallpaperItem?) {
        guard let item = item else {
            subviews.forEach { $0.removeFromSuperview() }
            player = nil; looper = nil
            shownID = ""
            return
        }
        let key = item.id + resolveRef(item.ref)
        guard key != shownID else { return }
        shownID = key
        subviews.forEach { $0.removeFromSuperview() }
        player = nil; looper = nil
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        switch item.kind {
        case "video":
            let p = AVQueuePlayer()
            looper = AVPlayerLooper(player: p, templateItem: AVPlayerItem(url: URL(fileURLWithPath: resolveRef(item.ref))))
            p.isMuted = true
            p.preventsDisplaySleepDuringVideoPlayback = false
            let l = AVPlayerLayer(player: p)
            l.videoGravity = .resizeAspectFill
            l.frame = bounds
            l.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer?.addSublayer(l)
            player = p
            p.play()
            say("PREVIEW video start=\(URL(fileURLWithPath: resolveRef(item.ref)).lastPathComponent)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak p] in
                let t = p?.currentTime().seconds ?? 0
                say("PREVIEW video t=\(String(format: "%.2f", t)) rate=\(p?.rate ?? 0)")
            }
        case "image":
            let path = resolveRef(item.ref)
            if path.lowercased().hasSuffix(".gif") {
                // GIF 用 WebView 才會真的動（NSImageView 不會播動畫）
                let wv = WKWebView(frame: bounds, configuration: WKWebViewConfiguration())
                wv.autoresizingMask = [.width, .height]
                let html = """
                <html><body style="margin:0;background:#000;overflow:hidden">
                <img src="\(URL(fileURLWithPath: path).lastPathComponent)" style="width:100%;height:100%;object-fit:cover;display:block">
                </body></html>
                """
                let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
                wv.loadHTMLString(html, baseURL: dir)
                addSubview(wv)
            } else {
                let iv = NSImageView(frame: bounds)
                iv.imageScaling = .scaleAxesIndependently
                iv.image = NSImage(contentsOfFile: path)
                iv.autoresizingMask = [.width, .height]
                addSubview(iv)
            }
        default:
            let url = item.kind == "builtin" ? builtinURL(item.ref) : URL(fileURLWithPath: resolveRef(item.ref))
            guard let url = url else { return }
            let conf = WKWebViewConfiguration()
            let wv = WKWebView(frame: bounds, configuration: conf)
            wv.autoresizingMask = [.width, .height]
            if #available(macOS 12.0, *) { wv.underPageBackgroundColor = .black }
            addSubview(wv)
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            say("PREVIEW web load=\(url.lastPathComponent)")
        }
    }

    override func layout() {
        super.layout()
        if let l = layer?.sublayers?.first as? AVPlayerLayer { l.frame = bounds }
        subviews.forEach { $0.frame = bounds }
    }
}

struct LivePreview: NSViewRepresentable {
    let item: WallpaperItem?
    func makeNSView(context: Context) -> PreviewBox { PreviewBox() }
    func updateNSView(_ nsView: PreviewBox, context: Context) { nsView.show(item) }
}

// MARK: ───────────────────────── 卡片

struct ItemCard: View {
    @ObservedObject var item: WallpaperItem
    let current: Bool
    let selected: Bool
    let onTap: () -> Void
    let onApply: () -> Void
    let onReveal: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    @State private var hover = false

    private var kindBadge: String? {
        switch item.kind {
        case "video": return "影片"
        case "image": return item.ref.lowercased().hasSuffix(".gif") ? "GIF" : "圖片"
        case "web": return "HTML"
        case "builtin": return "內建"
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let t = item.thumb {
                    Image(nsImage: t).resizable().aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(colors: [Color.black.opacity(0.75), Color.black.opacity(0.45)],
                                   startPoint: .top, endPoint: .bottom)
                    ProgressView().controlSize(.small)
                }
            }
            .frame(height: 118)
            .clipped()
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(current ? Color.accentColor : (selected ? Color.secondary : Color.clear), lineWidth: current ? 3 : 1.5))
            .overlay(alignment: .topLeading) {
                if let b = kindBadge {
                    Text(b)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.black.opacity(0.55))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if current {
                    Text("使用中")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                        .padding(6)
                }
            }
            .overlay(alignment: .bottom) {
                if hover && !current {
                    Text("設為桌布")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .padding(.bottom, 6)
                        .transition(.opacity)
                }
            }
            Text(item.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            Text(item.subtitle).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.12), lineWidth: 1))
        )
        .cornerRadius(14)
        .shadow(color: .black.opacity(hover ? 0.35 : 0.18), radius: hover ? 14 : 6, y: hover ? 6 : 3)
        .scaleEffect(hover ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: hover)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(count: 2) { onApply() }
        .onTapGesture(count: 1) { onTap() }
        .contextMenu {
            Button("套用到桌面") { onApply() }
                .disabled(current)
            Button("在 Finder 顯示") { onReveal() }
            if let onEdit = onEdit {
                Button("編輯 HTML…") { onEdit() }
            }
            if let onDelete = onDelete {
                Divider()
                Button("刪除（移到垃圾桶）", role: .destructive) { onDelete() }
            }
        }
    }
}

// MARK: ───────────────────────── 主介面：大圖 hero + 橫向卡片列

struct RowCard: View {
    @ObservedObject var item: WallpaperItem
    let current: Bool
    let onTap: () -> Void
    let onApply: () -> Void
    let onReveal: () -> Void
    @State private var hover = false

    private var badge: String {
        switch item.kind {
        case "video": return "動態"
        case "image": return item.ref.lowercased().hasSuffix(".gif") ? "GIF" : "靜態"
        case "web": return "HTML"
        default: return "內建"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let t = item.thumb {
                    Image(nsImage: t).resizable().aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.45)],
                                   startPoint: .top, endPoint: .bottom)
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 320, height: 180)
            .clipped()

            LinearGradient(colors: [.black.opacity(0.85), .clear], startPoint: .bottom, endPoint: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white).lineLimit(1)
                Text(item.subtitle).font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7)).lineLimit(1)
            }
            .padding(10)

            VStack {
                HStack {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.black.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    if current {
                        Text("使用中")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(8)
                Spacer()
                if hover && !current {
                    HStack {
                        Spacer()
                        Button(action: onApply) {
                            Label("設為桌布", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 320, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(hover ? 0.45 : 0.12), lineWidth: 1))
        .shadow(color: .black.opacity(hover ? 0.4 : 0.2), radius: hover ? 16 : 8, y: hover ? 8 : 4)
        .scaleEffect(hover ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: hover)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { onTap() }
        .contextMenu {
            Button("套用到桌面") { onApply() }.disabled(current)
            Button("在 Finder 顯示") { onReveal() }
        }
    }
}

struct LibraryView: View {
    @ObservedObject var model: LibraryModel
    @ObservedObject var tour = TourState.shared
    @State private var heroIndex = 0
    @State private var heroPaused = false

    private let heroTimer = Timer.publish(every: 6.0, on: .main, in: .common).autoconnect()
    private let gridColumns = [GridItem(.adaptive(minimum: 215), spacing: 14)]

    // MARK: 資料

    private var featured: [WallpaperItem] { model.items }

    private var heroItem: WallpaperItem? {
        guard !featured.isEmpty else { return nil }
        return featured[min(heroIndex, featured.count - 1)]
    }

    private var latest: [WallpaperItem] {
        model.filtered.sorted { a, b in
            (try? URL(fileURLWithPath: a.ref).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast >
            (try? URL(fileURLWithPath: b.ref).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
    }
    private var builtins: [WallpaperItem] { model.filtered.filter { $0.kind == "builtin" } }
    private var mine: [WallpaperItem] { model.filtered.filter { $0.kind != "builtin" } }
    private var isFiltering: Bool { !model.search.isEmpty || model.filter != "全部" }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "早安"
        case 12..<18: return "午安"
        default: return "晚安"
        }
    }

    private var pageTitle: String {
        switch model.page {
        case .home: return "探索壁紙庫"
        case .still: return "靜態壁紙"
        case .motion: return "動態壁紙"
        case .mine: return "我的最愛"
        }
    }

    // MARK: 主體

    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                ScrollView {
                    if model.page == .home {
                        homeContent
                    } else {
                        exploreContent
                    }
                }
            }

            if tour.active { TourOverlay(tour: tour) }
        }
        .coordinateSpace(name: "dynwall-window")
        .onPreferenceChange(TourAnchorKey.self) { r in
            DispatchQueue.main.async { tour.rects = r }
        }
        .onAppear {
            model.refresh()
            if model.selectedID == nil { model.selectedID = model.items.first?.id }
            tour.startIfNeeded()
        }
        .onReceive(heroTimer) { _ in
            guard !heroPaused, featured.count > 1, !tour.active else { return }
            withAnimation(.easeInOut(duration: 0.55)) { heroIndex = (heroIndex + 1) % featured.count }
        }
    }

    // MARK: 上方導覽（分頁置中、右邊工具）

    private var navBar: some View {
        ZStack {
            HStack(spacing: 2) {
                ForEach(LibraryModel.Page.allCases) { p in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            model.page = p
                            if model.page == .home { model.category = "全部" }
                        }
                        dbg("UI page=\(p.rawValue) items=\(model.pageItems.count)")
                    } label: {
                        Text(p.rawValue)
                            .font(.system(size: 12.5, weight: model.page == p ? .semibold : .regular))
                            .foregroundColor(model.page == p ? .primary : .secondary)
                            .padding(.horizontal, 18).padding(.vertical, 7)
                            .background(Capsule().fill(model.page == p ? Color.primary.opacity(0.13) : Color.clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(Color.white.opacity(0.10)))

            HStack(spacing: 8) {
                Menu {
                    Button("加入檔案…（影片 / 圖片 / GIF / HTML）") { model.pickFiles() }
                    Button("匯入 Wallpaper Engine 網頁壁紙…") {
                        NSApp.sendAction(#selector(AppDelegate.importWEAction), to: nil, from: nil)
                    }
                    Divider()
                    Button("開啟壁紙庫資料夾") { model.openLibraryFolder() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 34, height: 34)
                .help("加入壁紙")
                .tourAnchor("add")

                Spacer()

                Button { surprise() } label: {
                    Label("猜你喜歡", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
                .help("隨機挑一張套用")

                roundIcon("questionmark") { tour.replay() }.help("使用導覽")
                roundIcon("gearshape") {
                    NSApp.sendAction(#selector(AppDelegate.showSettingsWindow), to: nil, from: nil)
                }.help("設定（⌘,）")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .bottom)
    }

    private func roundIcon(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
    }

    private func surprise() {
        let pool = model.pageItems.isEmpty ? model.items : model.pageItems
        guard let pick = pool.randomElement() else { return }
        model.apply(pick)
        if model.page == .home, let i = featured.firstIndex(where: { $0.id == pick.id }) { heroIndex = i }
        dbg("UI surprise=\(pick.title)")
    }

    // MARK: 首頁（大圖 + 橫向卡片列）

    private var homeContent: some View {
        VStack(spacing: 0) {
            hero.frame(height: 400)
            shelves
        }
    }

    private var hero: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [Color(red: 0.07, green: 0.09, blue: 0.18),
                                        Color(red: 0.28, green: 0.12, blue: 0.36)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                LivePreview(item: heroItem)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .allowsHitTesting(false)

                LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0.35), .clear],
                               startPoint: .bottomLeading, endPoint: .center)

                VStack(alignment: .leading, spacing: 10) {
                    Text("精選").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.65))
                    Text(heroItem?.title ?? "還沒有壁紙")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundColor(.white).lineLimit(1)
                    Text(metaLine).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 10) {
                        Button {
                            if let h = heroItem { model.apply(h) }
                        } label: {
                            Label(model.selected.map { model.isCurrent($0) } == true ? "使用中" : "套用到桌面",
                                  systemImage: "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(heroItem == nil || (heroItem.map { model.isCurrent($0) } ?? true))
                        .tourAnchor("apply")

                        Button {
                            if let h = heroItem { model.reveal(h) }
                        } label: {
                            Label("在 Finder 顯示", systemImage: "folder").font(.system(size: 12))
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                    }
                    .padding(.top, 6)
                }
                .padding(.leading, 44)
                .padding(.bottom, 54)

                HStack {
                    arrow("chevron.left") { step(-1) }
                    Spacer()
                    arrow("chevron.right") { step(1) }
                }
                .padding(.horizontal, 26)

                VStack {
                    Spacer()
                    dots.padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .tourAnchor("inspector")
        }
        .frame(height: 400)
        .onHover { heroPaused = $0 }
    }

    private var metaLine: String {
        guard let h = heroItem else { return "" }
        var bits: [String] = []
        switch h.kind {
        case "video": bits.append("動態影片")
        case "image": bits.append(h.ref.lowercased().hasSuffix(".gif") ? "GIF 動圖" : "靜態圖片")
        case "web": bits.append("HTML 動態")
        default: bits.append("內建動態")
        }
        let sub = h.subtitle.trimmingCharacters(in: .whitespaces)
        if !sub.isEmpty && !sub.hasPrefix(bits[0]) && !bits[0].hasPrefix(sub) { bits.append(sub) }
        return bits.joined(separator: " ‧ ")
    }

    private func arrow(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(.black.opacity(0.35)))
                .overlay(Circle().stroke(Color.white.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<min(featured.count, 12), id: \.self) { i in
                Circle()
                    .fill(i == heroIndex ? Color.white : Color.white.opacity(0.35))
                    .frame(width: i == heroIndex ? 7 : 5, height: i == heroIndex ? 7 : 5)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.3)) { heroIndex = i } }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Capsule().fill(.black.opacity(0.25)))
    }

    private func step(_ d: Int) {
        guard featured.count > 1 else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            heroIndex = (heroIndex + d + featured.count) % featured.count
        }
    }

    // MARK: 下面的橫向卡片列

    private var shelves: some View {
        VStack(alignment: .leading, spacing: 26) {
            if isFiltering {
                if featured.isEmpty {
                    emptyState
                } else {
                    shelf("篩選結果", model.filtered)
                }
            } else {
                shelf("最新壁紙", latest)
                if !builtins.isEmpty { shelf("精選動態壁紙", builtins) }
                if !mine.isEmpty { shelf("我的壁紙", mine) }
            }
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tourAnchor("grid")
        .onChange(of: model.filter) { _, _ in heroIndex = 0
            dbg("UI filter=\(model.filter) search=\(model.search) shown=\(model.filtered.count)") }
        .onChange(of: model.search) { _, _ in heroIndex = 0
            dbg("UI filter=\(model.filter) search=\(model.search) shown=\(model.filtered.count)") }
    }

    private var emptyState: some View {
        let isFavEmpty = model.page == .mine && model.favorites.isEmpty
        return VStack(spacing: 8) {
            Image(systemName: isFavEmpty ? "heart" : "sparkle.magnifyingglass")
                .font(.system(size: 26)).foregroundColor(.secondary)
            Text(isFavEmpty ? "還沒有最愛" : "找不到符合的壁紙")
                .font(.system(size: 15, weight: .semibold))
            Text(isFavEmpty ? "在卡片右下角按一下 ♡，就會收集到這裡" : "換個關鍵字，或把分類切回「全部」")
                .font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func shelf(_ title: String, _ items: [WallpaperItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 17, weight: .bold))
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 13)).foregroundColor(.secondary)
                Spacer()
                Text("\(items.count) 張").font(.system(size: 10)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 28)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { it in
                        RowCard(item: it,
                                current: model.isCurrent(it),
                                onTap: {
                                    model.selectedID = it.id
                                    if let idx = featured.firstIndex(where: { $0.id == it.id }) {
                                        withAnimation(.easeInOut(duration: 0.35)) { heroIndex = idx }
                                    }
                                },
                                onApply: { model.apply(it) },
                                onReveal: { model.reveal(it) })
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: 探索頁（標題 / 搜尋 / 熱門 / 分類 / 格狀）

    private var exploreContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 問候 + 來源
            HStack(spacing: 10) {
                Text(greeting).font(.system(size: 17, weight: .semibold)).foregroundColor(.secondary)
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 9, weight: .bold))
                    Text("DynWall").font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
                }
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.12)))
                .foregroundColor(.secondary)
                Spacer()
            }

            Text(pageTitle).font(.system(size: 34, weight: .bold)).padding(.top, -4)

            // 搜尋列
            HStack(spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                    TextField("搜尋…", text: $model.search)
                        .textFieldStyle(.plain).font(.system(size: 13))
                    if !model.search.isEmpty {
                        Button { model.search = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .overlay(Capsule().stroke(Color.white.opacity(0.09)))

                roundIcon("link") { model.openLibraryFolder() }.help("開啟壁紙庫資料夾")
                roundIcon("sparkles") { surprise() }.help("隨機挑一張")
                roundIcon("arrow.clockwise") { model.refresh() }.help("重新掃描")
            }

            // 熱門
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("熱門:").font(.system(size: 11)).foregroundColor(.secondary)
                    ForEach(model.hotWords, id: \.self) { w in
                        Button { model.search = w } label: {
                            Text(w).font(.system(size: 11))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 分類
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.categories, id: \.0) { c in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { model.category = c.0 }
                            dbg("UI category=\(c.0) items=\(model.pageItems.count)")
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: c.1)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(c.2)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(c.2.opacity(0.18)))
                                Text(c.0).font(.system(size: 12))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(model.category == c.0 ? Color.white.opacity(0.13) : Color.white.opacity(0.04)))
                            .overlay(Capsule().stroke(model.category == c.0 ? c.2.opacity(0.55) : Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .tourAnchor("filters")

            Text("\(model.pageItems.count) 段媒體・已載入 \(model.pageItems.count)")
                .font(.system(size: 11)).foregroundColor(.secondary)

            if model.pageItems.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 14) {
                    ForEach(model.pageItems) { it in
                        GridCard(item: it,
                                 current: model.isCurrent(it),
                                 fav: model.isFav(it.id),
                                 onTap: { model.apply(it) },
                                 onFav: { model.toggleFav(it.id) },
                                 onReveal: { model.reveal(it) })
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 34)
        .tourAnchor("grid")
    }
}

// MARK: 探索頁的卡片（解析度徽章 / 標題 / 愛心）

struct GridCard: View {
    @ObservedObject var item: WallpaperItem
    let current: Bool
    let fav: Bool
    let onTap: () -> Void
    let onFav: () -> Void
    let onReveal: () -> Void
    @State private var hover = false
    @State private var res = ""

    var body: some View {
        Button(action: onTap) {
            // 用「透明 Rectangle + overlay」當底：圖片不會把卡片撐寬（不然最右邊那欄會被視窗切掉）
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .overlay {
                    if let t = item.thumb {
                        Image(nsImage: t).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.8)],
                                        startPoint: .center, endPoint: .bottom))
                .overlay(alignment: .topTrailing) {
                    Text(res.isEmpty ? kindLabel : res)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.5)))
                        .padding(8)
                }
                .overlay(alignment: .topLeading) {
                    if current {
                        Text("使用中")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottom) {
                    HStack(spacing: 8) {
                        Text(item.displayTitle)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: fav ? "heart.fill" : "heart")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(fav ? Color(red: 1, green: 0.35, blue: 0.5) : .white.opacity(0.75))
                            .contentShape(Rectangle())
                            .onTapGesture { onFav() }
                            .help(fav ? "取消最愛" : "加入最愛")
                    }
                    .padding(.horizontal, 10).padding(.bottom, 9)
                }
                .overlay(alignment: .center) {
                    if hover && !current {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                }
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(current ? Color.accentColor : Color.white.opacity(0.08),
                                lineWidth: current ? 2 : 1)
                }
                .scaleEffect(hover ? 1.015 : 1)
                .animation(.easeOut(duration: 0.14), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .contextMenu {
            Button("在 Finder 顯示") { onReveal() }
            Button(fav ? "取消最愛" : "加入最愛") { onFav() }
        }
        .task(id: item.id) { res = await Resolution.label(item) }
    }

    private var kindLabel: String {
        switch item.kind {
        case "video": return "動態"
        case "image": return item.ref.lowercased().hasSuffix(".gif") ? "GIF" : "靜態"
        case "web": return "HTML"
        default: return "內建"
        }
    }
}

// MARK: 解析度（給卡片右上角的徽章）

enum Resolution {
    static func label(_ item: WallpaperItem) async -> String {
        switch item.kind {
        case "image":
            let u = URL(fileURLWithPath: resolveRef(item.ref))
            if let src = CGImageSourceCreateWithURL(u as CFURL, nil),
               let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
               let w = p[kCGImagePropertyPixelWidth] as? Int,
               let h = p[kCGImagePropertyPixelHeight] as? Int {
                return "\(w)x\(h)"
            }
            return "圖片"
        case "video":
            let a = AVURLAsset(url: URL(fileURLWithPath: resolveRef(item.ref)))
            if let t = a.tracks(withMediaType: .video).first {
                let s = t.naturalSize.applying(t.preferredTransform)
                return "\(Int(abs(s.width).rounded()))x\(Int(abs(s.height).rounded()))"
            }
            return "影片"
        case "web":
            return "HTML"
        default:
            return "內建"
        }
    }
}
