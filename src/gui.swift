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

// MARK: ───────────────────────── 壁紙項目

final class WallpaperItem: Identifiable, ObservableObject {
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

func scanLibrary() -> [WallpaperItem] {
    var out: [WallpaperItem] = []
    for id in builtinIDs() {
        out.append(WallpaperItem(id: "builtin:\(id)", kind: "builtin", ref: id,
                                 title: BUILTIN_TITLES[id] ?? id,
                                 subtitle: "內建動態壁紙", canDelete: false))
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
            if let img = NSImage(contentsOfFile: item.ref) {
                done(img, imageInfo(URL(fileURLWithPath: item.ref)))
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

final class Engine {
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
            l.videoGravity = .resizeAspect
            l.frame = bounds
            l.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer?.addSublayer(l)
            player = p
            p.play()
        case "image":
            let iv = NSImageView(frame: bounds)
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.image = NSImage(contentsOfFile: resolveRef(item.ref))
            iv.autoresizingMask = [.width, .height]
            addSubview(iv)
        default:
            let url = item.kind == "builtin" ? builtinURL(item.ref) : URL(fileURLWithPath: resolveRef(item.ref))
            guard let url = url else { return }
            let conf = WKWebViewConfiguration()
            let wv = WKWebView(frame: bounds, configuration: conf)
            wv.autoresizingMask = [.width, .height]
            if #available(macOS 12.0, *) { wv.underPageBackgroundColor = .black }
            addSubview(wv)
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
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
            .frame(height: 108)
            .clipped()
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8)
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
                    Text("雙擊套用")
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
        .padding(6)
        .background(selected ? Color.primary.opacity(0.08) : (hover ? Color.primary.opacity(0.04) : Color.clear))
        .cornerRadius(10)
        .scaleEffect(hover ? 1.02 : 1.0)
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

// MARK: ───────────────────────── 主介面

struct LibraryView: View {
    @ObservedObject var model: LibraryModel
    @ObservedObject var tour = TourState.shared

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                libraryPane
                Divider()
                inspector.frame(width: 320)
            }
            .frame(minWidth: 1000, minHeight: 640)

            if tour.active {
                TourOverlay(tour: tour)
            }
        }
        .coordinateSpace(name: "dynwall-window")
        .onPreferenceChange(TourAnchorKey.self) { r in
            // 版面量測是在更新中進行的，推到下一個 runloop 再改狀態，避免 "Modifying state during view update"
            DispatchQueue.main.async { tour.rects = r }
        }
        .onAppear {
            model.refresh()
            if model.selectedID == nil { model.selectedID = model.filtered.first?.id }
            tour.startIfNeeded()
        }
    }

    private var libraryPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // 第一列：類型切換（讓它用自然寬度，不要硬塞固定寬度被裁掉）
                HStack(spacing: 10) {
                    Picker("", selection: $model.filter) {
                        ForEach(model.filters, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .tourAnchor("filters")

                    Spacer()

                    Text("顯示 \(model.filtered.count) / 共 \(model.items.count) 張")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }

                // 第二列：搜尋、排序、動作
                HStack(spacing: 10) {
                    TextField("搜尋…", text: $model.search)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 120, maxWidth: 200)

                    Picker("", selection: $model.sort) {
                        ForEach(model.sorts, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()

                    Spacer()

                    Button {
                        model.pickFiles()
                    } label: { Label("加入壁紙", systemImage: "plus") }
                    .labelStyle(.titleAndIcon)
                    .fixedSize()
                    .tourAnchor("add")

                    Button {
                        model.refresh()
                    } label: { Image(systemName: "arrow.clockwise") }
                    .help("重新整理")

                    Button {
                        tour.replay()
                    } label: { Image(systemName: "questionmark.circle") }
                    .help("再看一次使用導覽")

                    Button {
                        NSApp.sendAction(#selector(AppDelegate.showSettingsWindow), to: nil, from: nil)
                    } label: { Image(systemName: "gearshape") }
                    .help("設定（⌘,）")
                }
            }
            .padding(12)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
                    ForEach(model.filtered) { it in
                        ItemCard(item: it,
                                 current: model.isCurrent(it),
                                 selected: model.selectedID == it.id,
                                 onTap: { model.selectedID = it.id },
                                 onApply: { model.apply(it) },
                                 onReveal: { model.reveal(it) },
                                 onEdit: it.kind == "web" ? { model.editHTML(it) } : nil,
                                 onDelete: it.canDelete ? { model.delete(it) } : nil)
                    }
                }
                .padding(14)
            }
            .tourAnchor("grid")

            Divider()
            HStack(spacing: 8) {
                Text(model.message.isEmpty
                     ? "點縮圖看預覽，雙擊直接套用；右鍵有更多選項（Finder、編輯 HTML、刪除）"
                     : model.message)
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 6)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            var urls: [URL] = []
            let group = DispatchGroup()
            for p in providers {
                group.enter()
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let u = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(u)
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) { model.addFiles(urls) }
            return true
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("預覽").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                LivePreview(item: model.selected)
                    .frame(height: 180)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15)))

                if let s = model.selected {
                    Text(s.title).font(.system(size: 16, weight: .bold))
                    Text(s.subtitle).font(.system(size: 11)).foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Button {
                            model.apply(s)
                        } label: {
                            Label(model.isCurrent(s) ? "使用中" : "套用到桌面", systemImage: "checkmark.circle")
                        }
                        .disabled(model.isCurrent(s))
                        .tourAnchor("apply")

                        if s.canDelete {
                            Button(role: .destructive) {
                                model.delete(s)
                            } label: { Image(systemName: "trash") }
                        }
                    }
                } else {
                    Text("從左邊挑一個壁紙").font(.system(size: 12)).foregroundColor(.secondary)
                }

                Divider()
                Text("選項").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)

                Toggle("播放中（取消＝暫停）", isOn: Binding(
                    get: { !model.cfg.paused },
                    set: { Engine.shared.setPaused(!$0); model.cfg = Engine.shared.config }))

                Toggle("靜音", isOn: Binding(
                    get: { model.cfg.mute },
                    set: { Engine.shared.setMute($0); model.cfg = Engine.shared.config }))

                Toggle("允許滑鼠互動（自訂網頁壁紙）", isOn: Binding(
                    get: { model.cfg.interactive },
                    set: { Engine.shared.setInteractive($0); model.cfg = Engine.shared.config }))

                Toggle("開機自動啟動", isOn: Binding(
                    get: { model.cfg.autoStart },
                    set: { Engine.shared.setAutoStart($0); model.cfg = Engine.shared.config }))

                Toggle("關掉 App 後桌面保留同一張（靜態）", isOn: Binding(
                    get: { model.cfg.poster },
                    set: { Engine.shared.setPoster($0); model.cfg = Engine.shared.config }))

                VStack(alignment: .leading, spacing: 4) {
                    Text("播放速度：\(String(format: "%.1fx", model.cfg.rate))")
                        .font(.system(size: 11))
                    Slider(value: Binding(
                        get: { model.cfg.rate },
                        set: { model.cfg.rate = $0 }),
                           in: 0.25...2.0, step: 0.25) { _ in
                        Engine.shared.setRate(model.cfg.rate)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("暗化：\(Int(model.cfg.dim * 100))%（讓桌面圖示更清楚）").font(.system(size: 11))
                    Slider(value: Binding(
                        get: { model.cfg.dim },
                        set: { model.cfg.dim = $0 }),
                           in: 0...0.7, step: 0.1) { _ in
                        Engine.shared.setDim(model.cfg.dim)
                    }
                }

                Picker("畫面縮放", selection: Binding(
                    get: { model.cfg.gravity },
                    set: { Engine.shared.setGravity($0); model.cfg = Engine.shared.config })) {
                    Text("填滿畫面（裁切）").tag("fill")
                    Text("完整顯示（黑邊）").tag("fit")
                    Text("延展變形").tag("stretch")
                }
                .pickerStyle(.menu)

                Divider()
                Text("壁紙庫").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                Button {
                    _ = model.importBuiltinsAsTemplates()
                } label: { Label("把內建壁紙複製成可編輯範本", systemImage: "doc.on.doc") }
                Button {
                    model.openLibraryFolder()
                } label: { Label("開啟壁紙資料夾", systemImage: "folder") }

                Text("把影片 / 圖片拖進這個視窗也可以加入")
                    .font(.system(size: 10)).foregroundColor(.secondary)

                Text("共 \(model.items.count) 個壁紙")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
            .padding(16)
        }
        .tourAnchor("inspector")
        .background(Color.primary.opacity(0.03))
    }
}
