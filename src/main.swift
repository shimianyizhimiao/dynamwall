// Required Notice: Copyright (c) 2026 shimianyizhimiao — 動態壁紙 / DynWall
// 授權：PolyForm Noncommercial 1.0.0 + Share-Alike 附加條款（見 LICENSE）
// 禁止商業使用；修改後散布必須以相同條款公開原始碼。

//  動態壁紙 DynWall
//  macOS 桌面動態壁紙：影片 / HTML(CSS+JS) / 圖片 GIF
//  視窗放在「桌面圖示之下、桌面圖片之上」，所以桌面上按右鍵、點圖示都正常。
import Cocoa
import ImageIO
import AVFoundation
import WebKit
import UniformTypeIdentifiers
import CoreServices
import SwiftUI

// MARK: ───────────────────────── 路徑 / 常數

let fm = FileManager.default
let HOME = fm.homeDirectoryForCurrentUser
let BUNDLE_ID = Bundle.main.bundleIdentifier ?? "com.dynwall.app"
/// 主程式用「動態壁紙」；把影片包成的獨立 App（例如 com.dynwall.19juan）用自己的資料夾，兩者互不干擾
let DIR_SUFFIX = (BUNDLE_ID == "com.dynwall.app") ? "" : "-" + (BUNDLE_ID.split(separator: ".").last.map(String.init) ?? "app")
let SUPPORT_DIR = HOME.appendingPathComponent("Library/Application Support/動態壁紙\(DIR_SUFFIX)", isDirectory: true)
let CUSTOM_DIR = SUPPORT_DIR.appendingPathComponent("wallpapers", isDirectory: true)
let CACHE_DIR = HOME.appendingPathComponent("Library/Caches/動態壁紙\(DIR_SUFFIX)", isDirectory: true)
let CONFIG_URL = SUPPORT_DIR.appendingPathComponent("config.json")
let AGENT_LABEL = BUNDLE_ID
let AGENT_URL = HOME.appendingPathComponent("Library/LaunchAgents/\(AGENT_LABEL).plist")
let DEBUG = ProcessInfo.processInfo.environment["DYN_DEBUG"] == "1"
let TAKEOVER = "com.dynwall.takeover"
let logClock: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()
/// 上次「寫系統桌布圖」的時間：寫完系統會發螢幕參數變更，不能因此重建壁紙內容（會造成頻閃）
var lastDesktopWriteAt = Date.distantPast
let LOG_DIR = HOME.appendingPathComponent("Library/Logs", isDirectory: true)
let LOG_PATH = ProcessInfo.processInfo.environment["DYN_LOG"] ?? LOG_DIR.appendingPathComponent("動態壁紙\(DIR_SUFFIX).log").path
let LEVEL_OFFSET = Int(ProcessInfo.processInfo.environment["DYN_LEVEL_OFFSET"] ?? "") ?? -1

let BUILTIN_ORDER = ["aurora", "starfield", "cybergrid", "matrix", "template"]
let BUILTIN_TITLES: [String: String] = [
    "aurora": "極光",
    "starfield": "星海",
    "cybergrid": "賽博格柵",
    "matrix": "數位雨",
    "template": "自訂範本"
]

func say(_ s: String) {
    let line = "[\(logClock.string(from: Date()))] " + s
    print(line); fflush(stdout)
    guard let d = (line + "\n").data(using: .utf8) else { return }
    let path = LOG_PATH
    try? fm.createDirectory(at: LOG_DIR, withIntermediateDirectories: true)
    // 太肥就砍掉重來（保留最近的紀錄，不讓日誌無限長大）
    if let size = (try? fm.attributesOfItem(atPath: path))?[.size] as? Int, size > 512_000 {
        try? fm.removeItem(atPath: path)
    }
    if let h = FileHandle(forWritingAtPath: path) {
        h.seekToEndOfFile()
        h.write(d)
        try? h.close()
    } else {
        try? d.write(to: URL(fileURLWithPath: path))
    }
}
func dbg(_ s: String) { if DEBUG { print("DBG \(s)"); fflush(stdout) } }

// MARK: ───────────────────────── 設定檔

struct Config: Codable {
    var kind = "builtin"      // builtin | web | video | image
    var ref = "aurora"        // builtin id 或檔案路徑
    var mute = true
    var rate = 1.0
    var gravity = "fill"      // fill | fit | stretch
    var dim = 0.0
    var interactive = false
    var paused = false
    var autoStart = false
    var poster = true         // 套用壁紙時，同步把「靜態海報圖」設成系統桌布（關掉 App 後桌面仍是同一張）
    var parallaxOn = false    // 視差：預設關閉（想要景深感的使用者自己在設定裡開）
    var parallax = 10.0       // 位移幅度（像素）；壁紙會先放大一點避免露邊
    var rotationOn = false    // 定時換壁紙（輪換整個壁紙庫）
    var rotationMinutes = 30.0
    var pauseOnFullscreen = true   // 有 App 全螢幕時暫停壁紙，省電
    var lockPoster = true          // 鎖定／登入畫面要看到當下這一格（系統桌布一定得是靜態圖）
    var lockVideoOn = false        // 鎖定畫面跟著桌面一起播同一支影片（自動同步）

    init() {}

    enum CodingKeys: String, CodingKey {
        case kind, ref, mute, rate, gravity, dim, interactive, paused, autoStart, poster, parallaxOn, parallax, rotationOn, rotationMinutes, pauseOnFullscreen, lockPoster, lockVideoOn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "builtin"
        ref = (try? c.decode(String.self, forKey: .ref)) ?? "aurora"
        mute = (try? c.decode(Bool.self, forKey: .mute)) ?? true
        rate = (try? c.decode(Double.self, forKey: .rate)) ?? 1.0
        gravity = (try? c.decode(String.self, forKey: .gravity)) ?? "fill"
        dim = (try? c.decode(Double.self, forKey: .dim)) ?? 0.0
        interactive = (try? c.decode(Bool.self, forKey: .interactive)) ?? false
        paused = (try? c.decode(Bool.self, forKey: .paused)) ?? false
        autoStart = (try? c.decode(Bool.self, forKey: .autoStart)) ?? false
        poster = (try? c.decode(Bool.self, forKey: .poster)) ?? true
        parallaxOn = (try? c.decode(Bool.self, forKey: .parallaxOn)) ?? false
        parallax = (try? c.decode(Double.self, forKey: .parallax)) ?? 10.0
        rotationOn = (try? c.decode(Bool.self, forKey: .rotationOn)) ?? false
        rotationMinutes = (try? c.decode(Double.self, forKey: .rotationMinutes)) ?? 30.0
        pauseOnFullscreen = (try? c.decode(Bool.self, forKey: .pauseOnFullscreen)) ?? true
        lockPoster = (try? c.decode(Bool.self, forKey: .lockPoster)) ?? true
        lockVideoOn = (try? c.decode(Bool.self, forKey: .lockVideoOn)) ?? false
    }
}

func ensureDirs() {
    for d in [SUPPORT_DIR, CUSTOM_DIR, CACHE_DIR] {
        try? fm.createDirectory(at: d, withIntermediateDirectories: true)
    }
}

func loadConfig() -> Config {
    guard let data = try? Data(contentsOf: CONFIG_URL) else { return Config() }
    return (try? JSONDecoder().decode(Config.self, from: data)) ?? Config()
}

func saveConfig(_ c: Config) {
    ensureDirs()
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let d = try? enc.encode(c) { try? d.write(to: CONFIG_URL) }
}

// MARK: ───────────────────────── 內建 / 自訂壁紙掃描

func builtinResourceDir() -> URL? { Bundle.main.resourceURL?.appendingPathComponent("wallpapers", isDirectory: true) }

func builtinURL(_ id: String) -> URL? {
    guard let dir = builtinResourceDir() else { return nil }
    let u = dir.appendingPathComponent(id).appendingPathComponent("index.html")
    return fm.fileExists(atPath: u.path) ? u : nil
}

func builtinIDs() -> [String] {
    guard let dir = builtinResourceDir(),
          let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
    let found = names.filter {
        !$0.hasPrefix(".") && fm.fileExists(atPath: dir.appendingPathComponent($0).appendingPathComponent("index.html").path)
    }
    var ordered = BUILTIN_ORDER.filter { found.contains($0) }
    ordered += found.filter { !ordered.contains($0) }.sorted()
    return ordered
}

struct CustomEntry {
    let title: String
    let path: String
}

func customEntries() -> [CustomEntry] {
    guard let items = try? fm.contentsOfDirectory(at: CUSTOM_DIR, includingPropertiesForKeys: nil) else { return [] }
    var out: [CustomEntry] = []
    for u in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: u.path, isDirectory: &isDir) else { continue }
        if isDir.boolValue {
            let idx = u.appendingPathComponent("index.html")
            if fm.fileExists(atPath: idx.path) { out.append(CustomEntry(title: u.lastPathComponent, path: idx.path)) }
        } else if u.pathExtension.lowercased() == "html" {
            out.append(CustomEntry(title: u.deletingPathExtension().lastPathComponent, path: u.path))
        }
    }
    return out
}

func gravityValue(_ g: String) -> AVLayerVideoGravity {
    switch g {
    case "fit": return .resizeAspect
    case "stretch": return .resize
    default: return .resizeAspectFill
    }
}

/// 支援 `@bundle:media/xxx.mp4` 這種寫法：指向 App 自己內部的檔案，
/// 這樣把 App 搬到哪裡都能用，而且不需要「桌面／文件」資料夾權限。
func resolveRef(_ ref: String) -> String {
    guard ref.hasPrefix("@bundle:") else { return ref }
    let rel = String(ref.dropFirst("@bundle:".count))
    if let dir = Bundle.main.resourceURL {
        let u = dir.appendingPathComponent(rel)
        if fm.fileExists(atPath: u.path) { return u.path }
    }
    return ref
}

// MARK: ───────────────────────── 視圖 / 視窗

final class LayoutView: NSView {
    var onLayout: (() -> Void)?
    override func layout() {
        super.layout()
        onLayout?()
    }
}

/// 暗化遮罩：只負責變黑，不吃滑鼠事件
final class DimView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }
}

/// 用 FSEvents 監看整個資料夾（含子檔案「就地修改」，文字編輯器 / VS Code 都涵蓋）
final class DirMonitor {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init?(path: String, onChange: @escaping () -> Void) {
        self.onChange = onChange
        var ctx = FSEventStreamContext()
        ctx.info = Unmanaged.passUnretained(self).toOpaque()
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            Unmanaged<DirMonitor>.fromOpaque(info).takeUnretainedValue().onChange()
        }
        let paths = [path] as CFArray
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents
                                            | kFSEventStreamCreateFlagNoDefer
                                            | kFSEventStreamCreateFlagWatchRoot)
        guard let s = FSEventStreamCreate(kCFAllocatorDefault, callback, &ctx, paths,
                                          FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                          0.25, flags) else { return nil }
        stream = s
        FSEventStreamSetDispatchQueue(s, DispatchQueue.main)
        if !FSEventStreamStart(s) {
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
            stream = nil
            return nil
        }
    }

    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    deinit { stop() }
}

/// 放在桌面圖示下方的視窗，不能成為 key/main window
final class WallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
}

// MARK: ───────────────────────── 靜態海報（關掉 App 後桌面上留的那張圖）

/// 短雜湊（給快取檔名用）
func shortHash(_ s: String) -> String {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100_0000_01b3 }
    return String(h, radix: 16)
}

/// 把 CGImage 存成 PNG
@discardableResult
func writePNGFile(_ cg: CGImage, to url: URL) -> Bool {
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    return (try? data.write(to: url)) != nil
}

/// 把圖裁成「螢幕比例」（置中裁切）。系統桌布是等比縮放放進螢幕，
/// 圖片比例跟螢幕不同就會上下或左右留黑邊 —— 先裁掉就不會有黑邊。
func croppedToScreenAspect(_ cg: CGImage, screen: NSScreen) -> CGImage {
    let target = screen.frame.width / max(screen.frame.height, 1)
    let w = CGFloat(cg.width), h = CGFloat(cg.height)
    let imgAspect = w / max(h, 1)
    var rect = CGRect(x: 0, y: 0, width: w, height: h)
    if imgAspect > target {
        // 圖太寬 → 裁左右
        let newW = (h * target).rounded()
        rect = CGRect(x: ((w - newW) / 2).rounded(), y: 0, width: max(newW, 1), height: h)
    } else if imgAspect < target {
        // 圖太高 → 裁上下
        let newH = (w / target).rounded()
        rect = CGRect(x: 0, y: ((h - newH) / 2).rounded(), width: w, height: max(newH, 1))
    }
    return cg.cropping(to: rect) ?? cg
}

/// 簡單的整數盒子（給「等待 N 個非同步工作完成」用）
final class IntBox {
    var value: Int
    init(_ v: Int) { value = v }
}

/// 這張圖片的描述（給日誌／介面用）
func posterLabel(_ c: Config) -> String {
    switch c.kind {
    case "video": return "影片定格"
    case "image": return "圖片"
    case "web": return "網頁截圖"
    default: return "內建壁紙截圖"
    }
}

/// 內建壁紙打包好的高解析海報圖
func posterResourceURL(_ id: String) -> URL? {
    if let u = Bundle.main.url(forResource: id, withExtension: "jpg", subdirectory: "posters") { return u }
    return Bundle.main.url(forResource: id, withExtension: "jpg")
}

/// 找 Chrome（產生自訂 HTML 的靜態海報用）
func chromeBinary() -> String? {
    let p = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if fm.isExecutableFile(atPath: p) { return p }
    if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
        let exec = u.appendingPathComponent("Contents/MacOS/Google Chrome").path
        if fm.isExecutableFile(atPath: exec) { return exec }
    }
    return nil
}

/// 判斷截圖是不是「幾乎全黑／單色」的空白畫面（避免把桌面設成黑畫面）
func isLikelyBlank(_ img: NSImage) -> Bool {
    let side = 16
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let data = rep.bitmapData else { return false }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()
    var lo = 765, hi = 0
    for y in 0..<side {
        for x in 0..<side {
            let o = y * rep.bytesPerRow + x * 4
            let v = Int(data[o]) + Int(data[o + 1]) + Int(data[o + 2])
            lo = min(lo, v); hi = max(hi, v)
        }
    }
    return (hi - lo) < 12
}

// MARK: ───────────────────────── 每個螢幕一個壁紙

final class ScreenWallpaper {
    let displayID: CGDirectDisplayID
    let screen: NSScreen
    let window: WallpaperWindow
    let root = LayoutView()
    var player: AVQueuePlayer?
    var looper: AVPlayerLooper?
    var lastReorderAt = Date.distantPast
    var idleTicks = 0
    var lastPosterURL: URL?
    var playerLayer: AVPlayerLayer?
    var webView: WKWebView?
    var dimView: DimView?
    var monitor: DirMonitor?
    var reloadWork: DispatchWorkItem?
    var currentHTML: URL?
    var lastFrameSample: (Int, Date)?
    var lastVideoTime: Double = -1
    var frozenTicks = 0
    var lastNudgeAt = Date.distantPast
    var currentVideoURL: URL?
    var cfg = Config()
    var posterWork: DispatchWorkItem?
    var posterJob: SnapshotJob?

    init?(screen: NSScreen) {
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        displayID = num.uint32Value
        self.screen = screen

        let base = Int(CGWindowLevelForKey(.desktopIconWindow))
        let level = NSWindow.Level(rawValue: base + LEVEL_OFFSET)
        let w = WallpaperWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        w.isReleasedWhenClosed = false
        w.level = level
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        w.backgroundColor = .black
        w.isOpaque = true
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.isMovable = false
        w.isMovableByWindowBackground = false
        w.animationBehavior = .none
        w.hidesOnDeactivate = false
        w.canHide = false
        w.isExcludedFromWindowsMenu = true
        window = w

        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.black.cgColor
        root.onLayout = { [weak self] in self?.relayout() }
        w.contentView = root
        resizeToScreen()
        w.orderFrontRegardless()
    }

    func resizeToScreen() {
        window.setFrame(screen.frame, display: true)
        relayout()
    }

    func relayout() {
        let b = root.bounds
        playerLayer?.frame = b
        dimView?.frame = b
        webView?.frame = b
    }

    func destroy() {
        teardownContent()
        window.orderOut(nil)
        window.close()
    }

    // MARK: 內容

    func apply(_ c: Config) {
        cfg = c
        let tail = String(c.ref.suffix(48))
        say("APPLY screen=\(displayID) kind=\(c.kind) ref=…\(tail)")
        teardownContent()
        switch c.kind {
        case "video":
            if !setupVideo(URL(fileURLWithPath: resolveRef(c.ref))) { setupBuiltin("aurora") }
        case "web":
            let u = URL(fileURLWithPath: resolveRef(c.ref))
            if fm.fileExists(atPath: u.path) { setupWeb(u, watch: true) } else { setupBuiltin("aurora") }
        case "image":
            if let u = makeImageWrapper(URL(fileURLWithPath: resolveRef(c.ref))) { setupWeb(u, watch: false) } else { setupBuiltin("aurora") }
        default:
            setupBuiltin(c.ref)
        }
        updateDim(c.dim)
        let allowMouse = c.interactive && (c.kind == "web" || c.kind == "builtin" || c.kind == "image")
        window.ignoresMouseEvents = !allowMouse
        if c.paused { pauseContent() }
        schedulePosterRefresh()
    }

    func teardownContent() {
        posterWork?.cancel(); posterWork = nil
        reloadWork?.cancel(); reloadWork = nil
        monitor?.stop(); monitor = nil
        player?.pause()
        player = nil
        looper = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        if let wv = webView {
            wv.stopLoading()
            wv.navigationDelegate = nil
            wv.removeFromSuperview()
        }
        webView = nil
        dimView?.removeFromSuperview()
        dimView = nil
        currentHTML = nil
        lastFrameSample = nil
    }

    // MARK: 靜態海報

    /// 套用壁紙後排程產生海報（等動畫／影片跑起來再抓，畫面才漂亮）
    func schedulePosterRefresh() {
        posterWork?.cancel()
        guard cfg.poster || cfg.lockPoster else { return }
        let w = DispatchWorkItem { [weak self] in self?.writeDesktopPoster() }
        posterWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: w)
    }

    /// 視差：滑鼠離開中心多少，整張壁紙就往同方向位移幾像素。
    /// 內容會先放大一點（比螢幕大 2 倍幅度），所以位移時不會露邊。
    func applyParallax(_ mouse: NSPoint?) {
        guard let layer = root.layer else { return }
        let amount = CGFloat(max(0, min(cfg.parallax, 40)))
        guard cfg.parallaxOn, amount > 0.5, let m = mouse else {
            if !CATransform3DIsIdentity(layer.transform) { layer.transform = CATransform3DIdentity }
            return
        }
        let f = screen.frame
        let nx = max(-1, min(1, (m.x - f.midX) / (f.width / 2)))
        let ny = max(-1, min(1, (m.y - f.midY) / (f.height / 2)))
        let pad = amount * 2 + 4
        let scale = 1 + (pad * 2) / min(f.width, f.height)
        var t = CATransform3DMakeScale(scale, scale, 1)
        t = CATransform3DTranslate(t, nx * amount / scale, ny * amount / scale, 0)
        layer.transform = t
    }

    /// 把某張圖設成這台螢幕的系統桌布
    func applyDesktopPicture(_ url: URL) {
        let opts: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        do {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: opts)
            lastDesktopWriteAt = Date()
            say("POSTER screen=\(displayID) \(posterLabel(cfg)) file=\(url.lastPathComponent)")
        } catch {
            dbg("設定系統桌布失敗：\(error)")
        }
    }

    /// 結束 App 時用：立刻沿用最近一張海報（同步、瞬間完成），
    /// 不再等非同步抽格 —— 以前等 6 秒還會來不及（POSTER-ON-QUIT left=1）。
    @discardableResult
    func posterOnQuit() -> Bool {
        guard cfg.poster else { return true }
        if let u = lastPosterURL, fm.fileExists(atPath: u.path) {
            applyDesktopPicture(u)
            say("POSTER-ON-QUIT reuse screen=\(displayID) file=\(u.lastPathComponent)")
            return true
        }
        // 退而求其次：桌面上已經是同一張（我們產生的海報，或圖片壁紙原檔）→ 不用重做，直接結束
        if let cur = NSWorkspace.shared.desktopImageURL(for: screen), fm.fileExists(atPath: cur.path) {
            let isOurs = cur.lastPathComponent.hasPrefix("poster-")
                || cfg.kind == "image" && cur.path == URL(fileURLWithPath: resolveRef(cfg.ref)).path
            if isOurs {
                say("POSTER-ON-QUIT reuse-current screen=\(displayID) file=\(cur.lastPathComponent)")
                lastPosterURL = cur
                return true
            }
        }
        // 還沒有任何海報（例如剛套用就馬上結束）→ 退回非同步產生
        writeDesktopPoster()
        say("POSTER-ON-QUIT generate screen=\(displayID)")
        return false
    }

    /// 產生這台螢幕的靜態海報，並設成系統桌布
    func writeDesktopPoster(_ done: (() -> Void)? = nil, force: Bool = false) {
        // 桌面上已經是這張壁紙的海報（比例也對）→ 連產生都不用，直接跳過
        // 每次啟動都重畫一張 2.6MB 的 PNG 很浪費，也容易讓桌布閃一下
        let preHash = shortHash(cfg.kind + "|" + cfg.ref)
        if !force, let cur = NSWorkspace.shared.desktopImageURL(for: screen), fm.fileExists(atPath: cur.path),
           cur.lastPathComponent.hasPrefix("poster-\(preHash)-"),
           let img = NSImage(contentsOf: cur), let rep = img.representations.first, rep.pixelsHigh > 0,
           abs(Double(rep.pixelsWide) / Double(rep.pixelsHigh) - Double(screen.frame.width / max(screen.frame.height, 1))) < 0.01 {
            lastPosterURL = cur
            say("POSTER-SKIP screen=\(displayID) 已是同一張（不重新產生）")
            prunePosters(keep: cur)
            done?()
            return
        }
        let finish: (URL?) -> Void = { [weak self] url in
            guard let self = self else { done?(); return }
            if let url = url {
                // 桌布已經是同一張就不要重設：重設會讓系統桌布重畫一次，很容易被看成「閃一下」
                // 但「同一來源、比例卻不對」（舊版海報沒裁切）時仍要重設，否則黑邊會留著
                let h = shortHash(self.cfg.kind + "|" + self.cfg.ref)
                if !force, let curURL = NSWorkspace.shared.desktopImageURL(for: self.screen) {
                    let cur = curURL.lastPathComponent
                    if cur == url.lastPathComponent || cur.hasPrefix("poster-\(h)-") {
                        let screenAspect = Double(self.screen.frame.width / max(self.screen.frame.height, 1))
                        var aspectOK = fm.fileExists(atPath: curURL.path)   // 檔案被清掉就一定要重做
                        if aspectOK, let img = NSImage(contentsOf: curURL), let rep = img.representations.first, rep.pixelsHigh > 0 {
                            aspectOK = abs(Double(rep.pixelsWide) / Double(rep.pixelsHigh) - screenAspect) < 0.01
                        }
                        if aspectOK {
                            say("POSTER-SKIP screen=\(self.displayID) 已是同一張")
                            self.lastPosterURL = curURL
                            self.prunePosters(keep: curURL)   // 跳過也要清，不然快取會一直長大
                            done?(); return
                        }
                        say("POSTER-REDO screen=\(self.displayID) 比例不符（舊海報未裁切）")
                    }
                }
                self.applyDesktopPicture(url)
                self.lastPosterURL = url
                self.prunePosters(keep: url)
            } else {
                dbg("海報產生失敗 kind=\(self.cfg.kind) ref=\(self.cfg.ref)")
            }
            done?()
        }

        // 1) 內建壁紙：用打包好的高解析海報圖（不用截圖，一定正確）
        if cfg.kind == "builtin", let u = posterResourceURL(cfg.ref) {
            finish(u); return
        }

        // 2) 圖片：裁成螢幕比例再設（避免黑邊）；GIF 直接用原檔（保留動畫）
        if cfg.kind == "image" {
            let src = URL(fileURLWithPath: resolveRef(cfg.ref))
            if fm.fileExists(atPath: src.path) {
                if src.pathExtension.lowercased() == "gif" { finish(src); return }
                if let cgSrc = CGImageSourceCreateWithURL(src as CFURL, nil),
                   let cg = CGImageSourceCreateImageAtIndex(cgSrc, 0, nil),
                   let dst = newPosterURL("png") {
                    let cut = croppedToScreenAspect(cg, screen: screen)
                    finish(writePNGFile(cut, to: dst) ? dst : src)
                    return
                }
                finish(src)
                return
            }
        }

        // 3) 影片：抽「現在這一格」，關掉 App 時桌面就停在這裡
        if cfg.kind == "video" {
            let url = URL(fileURLWithPath: resolveRef(cfg.ref))
            if fm.fileExists(atPath: url.path), let dst = newPosterURL("png") {
                let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                gen.appliesPreferredTrackTransform = true
                gen.maximumSize = CGSize(width: 2560, height: 2560)
                gen.requestedTimeToleranceBefore = .zero
                gen.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
                let t = player?.currentTime() ?? CMTime(seconds: 2.5, preferredTimescale: 600)
                gen.generateCGImagesAsynchronously(forTimes: [NSValue(time: t)]) { _, cg, _, _, err in
                    var out: URL?
                    if let cg = cg {
                        let cut = croppedToScreenAspect(cg, screen: self.screen)   // 裁成螢幕比例，桌布才不會有黑邊
                        out = writePNGFile(cut, to: dst) ? dst : nil
                    }
                    if let err = err { dbg("抽影片格失敗：\(err.localizedDescription)") }
                    DispatchQueue.main.async { finish(out) }
                }
                return
            }
        }

        // 4) 自訂 HTML：用 Chrome 無頭渲染（WebKit 離屏視窗會停掉 requestAnimationFrame，截出來是空白）
        if let html = htmlPosterURL() {
            say("POSTER-WEB render \(html.lastPathComponent)")
            chromePoster(html) { url in finish(url) }
            return
        }

        finish(nil)
    }

    /// 自訂 HTML 壁紙對應的 html 檔
    func htmlPosterURL() -> URL? {
        if cfg.kind == "web" {
            let u = URL(fileURLWithPath: resolveRef(cfg.ref))
            return fm.fileExists(atPath: u.path) ? u : nil
        }
        if cfg.kind == "builtin" { return builtinURL(cfg.ref) }
        return nil
    }

    /// 用 Chrome 無頭渲染一張靜態圖（可自訂 HTML 用）
    func chromePoster(_ html: URL, _ done: @escaping (URL?) -> Void) {
        guard let chrome = chromeBinary(), let dst = newPosterURL("jpg") else {
            say("POSTER-WEB 找不到 Chrome，這次不動系統桌布")
            done(nil); return
        }
        let dir = CACHE_DIR.appendingPathComponent("posters", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // Chrome 對「中文／空白」的輸出路徑不可靠 → 一律先寫到 ASCII 的系統暫存目錄，再搬進快取
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let stamp = "\(Int(Date().timeIntervalSince1970))-\(UInt32.random(in: 0...99999))"
        let tmp = tmpDir.appendingPathComponent("dynwall-poster-\(stamp).png")
        let profile = tmpDir.appendingPathComponent("dynwall-chrome-\(stamp)", isDirectory: true)
        try? fm.createDirectory(at: profile, withIntermediateDirectories: true)
        let px = posterPixelSize()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: chrome)
        // URL 一定要用 absoluteString（會做百分比編碼）：手動組 "file://<path>" 遇到中文／空白／括號會讓 Chrome 卡死
        // --user-data-dir 用獨立 profile：否則已經開著的 Chrome 會把工作交給既有實例然後卡住
        p.arguments = ["--headless=new", "--disable-gpu", "--hide-scrollbars",
                       "--allow-file-access-from-files", "--no-first-run", "--no-default-browser-check",
                       "--user-data-dir=\(profile.path)", "--force-device-scale-factor=2",
                       "--window-size=\(Int(px.width)),\(Int(px.height))",
                       "--virtual-time-budget=4500",
                       "--screenshot=\(tmp.path)", html.absoluteString]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice

        // 有些會持續動畫的頁面，Chrome 截完圖也不會自己結束 → 以「輸出檔出現」為準，不看它有沒有退出
        let flag = IntBox(0)
        let deadline = Date().addingTimeInterval(25)
        func pollForFile() {
            if flag.value != 0 { return }
            let size = ((try? fm.attributesOfItem(atPath: tmp.path))?[.size] as? Int) ?? 0
            if size > 4096 {
                flag.value = 1
                var out: URL?
                if let img = NSImage(contentsOf: tmp), let tiff = img.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) {
                    try? data.write(to: dst)
                    out = dst
                    say("POSTER-WEB ok \(Int(img.size.width))x\(Int(img.size.height)) -> \(dst.lastPathComponent)")
                }
                if p.isRunning { p.terminate() }
                try? fm.removeItem(at: tmp)
                try? fm.removeItem(at: profile)
                DispatchQueue.main.async { done(out) }
                return
            }
            if Date() > deadline {
                flag.value = 1
                if p.isRunning { p.terminate() }
                try? fm.removeItem(at: profile)
                say("POSTER-WEB 超時（沒有輸出檔）")
                DispatchQueue.main.async { done(nil) }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pollForFile() }
        }
        p.terminationHandler = { _ in pollForFile() }
        do { try p.run() } catch {
            flag.value = 1
            say("POSTER-WEB Chrome 啟動失敗 \(error)")
            done(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { pollForFile() }
    }

    /// 海報要多大：用螢幕「點數」尺寸（離屏視窗在 Retina 上會自動輸出 2 倍解析度）。
    /// 不能用像素尺寸：HTML 的畫布會依 CSS 尺寸配置，尺寸開太大畫布會爆掉變全黑。
    func posterPixelSize() -> CGSize {
        CGSize(width: max(320, screen.frame.width), height: max(200, screen.frame.height))
    }

    func newPosterURL(_ ext: String) -> URL? {
        let dir = CACHE_DIR.appendingPathComponent("posters", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // 檔名帶時間戳：內容更新時 macOS 一定會重新載入（同檔名同 URL 會被快取）
        let name = "poster-\(shortHash(cfg.kind + "|" + cfg.ref))-\(Int(Date().timeIntervalSince1970)).\(ext)"
        return dir.appendingPathComponent(name)
    }

    /// 只留最近幾張，避免快取一直長大
    func prunePosters(keep: URL) {
        let dir = CACHE_DIR.appendingPathComponent("posters", isDirectory: true)
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        // 正在當桌布的那張絕對不能刪，否則系統桌布會指向一個不存在的檔案
        var protected = Set<String>([keep.lastPathComponent])
        if let cur = NSWorkspace.shared.desktopImageURL(for: screen) { protected.insert(cur.lastPathComponent) }
        if let lp = lastPosterURL { protected.insert(lp.lastPathComponent) }
        let others = files.filter { !protected.contains($0.lastPathComponent) }.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        for f in others.dropFirst(3) { try? fm.removeItem(at: f) }
    }

    @discardableResult
    func setupVideo(_ url: URL) -> Bool {
        guard fm.fileExists(atPath: url.path) else { dbg("找不到影片：\(url.path)"); return false }
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 1.0
        let p = AVQueuePlayer()
        p.actionAtItemEnd = .advance
        looper = AVPlayerLooper(player: p, templateItem: item)
        p.isMuted = cfg.mute
        p.volume = cfg.mute ? 0 : 1
        p.preventsDisplaySleepDuringVideoPlayback = false
        let layer = AVPlayerLayer(player: p)
        layer.videoGravity = gravityValue(cfg.gravity)
        layer.frame = root.bounds
        root.layer?.insertSublayer(layer, at: 0)
        player = p
        playerLayer = layer
        p.play()
        if cfg.rate != 1.0 { p.rate = Float(cfg.rate) }
        addDimIfNeeded()
        return true
    }

    func setupBuiltin(_ id: String) {
        if let u = builtinURL(id) {
            setupWeb(u, watch: false)
        } else if let u = builtinURL("aurora") {
            setupWeb(u, watch: false)
        } else {
            dbg("找不到內建壁紙資源")
        }
    }

    /// Wallpaper Engine 的網頁壁紙會呼叫這些 API；沒有就先補一個空的，避免整片黑
    static let weShimJS = """
    (function(){
      if (!window.wallpaperPropertyListener) {
        window.wallpaperPropertyListener = {
          applyUserProperties: function(){}, applyGeneralProperties: function(){},
          setPaused: function(){}, userDirectory: ""
        };
      }
      if (!window.wallpaperRegisterAudioListener) { window.wallpaperRegisterAudioListener = function(){}; }
      if (!window.wallpaperRegisterMediaStatusListener) { window.wallpaperRegisterMediaStatusListener = function(){}; }
    })();
    """

    func setupWeb(_ url: URL, watch: Bool) {
        let conf = WKWebViewConfiguration()
        conf.mediaTypesRequiringUserActionForPlayback = []
        conf.suppressesIncrementalRendering = false
        conf.userContentController.addUserScript(WKUserScript(source: Self.frameCounterJS,
                                                             injectionTime: .atDocumentEnd,
                                                             forMainFrameOnly: false))
        conf.userContentController.addUserScript(WKUserScript(source: Self.weShimJS,
                                                             injectionTime: .atDocumentStart,
                                                             forMainFrameOnly: false))
        // 關閉「視窗被遮住就停止渲染」的節流（私有偏好；失敗不影響運作）
        let ok = DynSetPreferenceSafe(conf.preferences, "pageVisibilityBasedProcessSuppressionEnabled", NSNumber(value: false))
        dbg("suppressionDisabled=\(ok)")

        let wv = WKWebView(frame: root.bounds, configuration: conf)
        wv.autoresizingMask = [.width, .height]
        wv.allowsBackForwardNavigationGestures = false
        wv.allowsMagnification = false
        if #available(macOS 12.0, *) { wv.underPageBackgroundColor = .black }
        if #available(macOS 13.3, *) { wv.isInspectable = true }
        root.addSubview(wv)
        webView = wv
        addDimIfNeeded()
        wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        currentHTML = url
        dbg("載入 \(url.path)")
        if watch { startWatching(url.deletingLastPathComponent()) }
    }

    func startWatching(_ dir: URL) {
        monitor?.stop()
        monitor = DirMonitor(path: dir.path) { [weak self] in self?.reloadWebSoon() }
        dbg(monitor == nil ? "無法監看 \(dir.path)" : "開始監看（FSEvents）\(dir.path)")
    }

    func reloadWebSoon() {
        reloadWork?.cancel()
        let wi = DispatchWorkItem { [weak self] in self?.reloadWeb() }
        reloadWork = wi
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: wi)
    }

    func reloadWeb() {
        guard let wv = webView, let u = currentHTML else { return }
        say("RELOAD 熱重載 \(u.lastPathComponent)")
        wv.loadFileURL(u, allowingReadAccessTo: u.deletingLastPathComponent())
    }

    func makeImageWrapper(_ src: URL) -> URL? {
        guard fm.fileExists(atPath: src.path) else { dbg("找不到圖片：\(src.path)"); return nil }
        let dir = CACHE_DIR.appendingPathComponent("imagewrapper", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = src.pathExtension.isEmpty ? "img" : src.pathExtension.lowercased()
        let copy = dir.appendingPathComponent("wallpaper-image.\(ext)")
        try? fm.removeItem(at: copy)
        do { try fm.copyItem(at: src, to: copy) } catch { dbg("複製圖片失敗 \(error)"); return nil }
        let size: String
        switch cfg.gravity {
        case "fit": size = "contain"
        case "stretch": size = "100% 100%"
        default: size = "cover"
        }
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><style>
        html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden;}
        body{background-image:url('wallpaper-image.\(ext)');
             background-size:\(size);background-position:center center;background-repeat:no-repeat;}
        </style></head><body></body></html>
        """
        let dest = dir.appendingPathComponent("index.html")
        do { try html.write(to: dest, atomically: true, encoding: .utf8) } catch { return nil }
        return dest
    }

    // MARK: 暗化 / 暫停

    func addDimIfNeeded() {
        guard cfg.dim > 0.001, dimView == nil else { return }
        let v = DimView(frame: root.bounds)
        v.autoresizingMask = [.width, .height]
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.black.withAlphaComponent(CGFloat(cfg.dim)).cgColor
        root.addSubview(v)
        dimView = v
    }

    func updateDim(_ alpha: Double) {
        if alpha <= 0.001 {
            dimView?.removeFromSuperview()
            dimView = nil
        } else if let v = dimView {
            v.layer?.backgroundColor = NSColor.black.withAlphaComponent(CGFloat(alpha)).cgColor
        } else {
            addDimIfNeeded()
        }
    }

    /// 影片「看起來在播但畫面定格」的救援：先 seek 一下，沒用就重掛 item
    func unfreezeVideo() {
        guard let p = player else { return }
        frozenTicks += 1
        if frozenTicks == 1, let t = p.currentItem?.currentTime() {
            say("UNFREEZE seek screen=\(displayID)")
            p.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { _ in p.play() }
            return
        }
        if let url = currentVideoURL {
            say("UNFREEZE rebuild screen=\(displayID) url=\(url.lastPathComponent)")
            let item = AVPlayerItem(url: url)
            p.replaceCurrentItem(with: item)
            p.play()
        }
        frozenTicks = 0
    }

    /// 被別的視窗蓋住再露出來時，替這個螢幕補一格
    func watchOcclusion() {
        NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                               object: nil, queue: .main) { [weak self] note in
            guard let self, (note.object as? NSWindow) === self.window else { return }
            if self.window.occlusionState.contains(.visible) { self.nudgeFrame() }
        }
    }

    /// 強制重畫一格：被全螢幕或別的程式蓋住再回來時，AVPlayerLayer 不會自己更新
    func nudgeFrame() {
        guard let p = player, !cfg.paused else { return }
        guard Date().timeIntervalSince(lastNudgeAt) > 0.5 else { return }
        lastNudgeAt = Date()
        let t = p.currentTime()
        p.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            if !self.cfg.paused { p.play() }
        }
    }

    func pauseContent() {
        player?.pause()
        webView?.evaluateJavaScript(Self.jsPause, completionHandler: nil)
    }

    func resumeContent() {
        if let p = player {
            p.play()
            if cfg.rate != 1.0 { p.rate = Float(cfg.rate) }
        }
        if webView != nil { webView?.evaluateJavaScript(Self.jsResume, completionHandler: nil) }
    }

    // MARK: 診斷

    func probeInfo() -> String {
        var s = "screen=\(displayID) kind=\(cfg.kind) ref=\(cfg.ref) level=\(window.level.rawValue) "
        s += "frame=\(Int(window.frame.width))x\(Int(window.frame.height)) "
        s += "occlVisible=\(window.occlusionState.contains(.visible)) "
        s += "visible=\(window.isVisible) alpha=\(window.alphaValue) "
        s += "mouseIgnored=\(window.ignoresMouseEvents)"
        if let p = player {
            s += " video_t=\(String(format: "%.2f", p.currentTime().seconds)) rate=\(p.rate) "
            s += "status=\(p.timeControlStatus.rawValue) items=\(p.items().count) itemStatus=\(p.currentItem?.status.rawValue ?? -1)"
        }
        if let wv = webView { s += " webURL=\(wv.url?.lastPathComponent ?? "-")" }
        return s
    }

    func probeJS(_ done: @escaping (String) -> Void) {
        guard let wv = webView else { done(""); return }
        wv.evaluateJavaScript("window.__dynFrames") { result, _ in
            var extra = ""
            if let n = result as? Int {
                let now = Date()
                if let (pn, pt) = self.lastFrameSample {
                    let dt = now.timeIntervalSince(pt)
                    if dt > 0.5 { extra += " fps=\(String(format: "%.1f", Double(n - pn) / dt))" }
                }
                self.lastFrameSample = (n, now)
                extra += " frames=\(n)"
            } else {
                extra += " frames=nil"
            }
            wv.evaluateJavaScript("document.hidden + '/' + document.visibilityState") { h, _ in
                done(extra + " hidden=\(h ?? "?")")
            }
        }
    }

    static let frameCounterJS = """
    window.__dynFrames = 0;
    window.__dynPaused = false;
    window.__dynSavedRAF = null;
    (function dynTick(){ window.__dynFrames++; window.requestAnimationFrame(dynTick); })();
    """

    static let jsPause = """
    if (!window.__dynPaused) {
      window.__dynPaused = true;
      window.__dynSavedRAF = window.requestAnimationFrame;
      window.requestAnimationFrame = function(){ return 0; };
    }
    """

    static let jsResume = """
    try { location.reload(); } catch (e) {}
    """
}

// MARK: ───────────────────────── App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    var cfg = Config()
    var screens: [ScreenWallpaper] = []
    var statusItem: NSStatusItem!
    var parallaxTimer: Timer?
    var rotationTimer: Timer?
    var pausedByFullscreen = false
    var headless = false   // 測試模式：不要彈 NSAlert 卡住主執行緒
    var lockVideoWaiting = false
    var lockVideoInteractive = false
    var activity: NSObjectProtocol?
    var lockSyncWork: DispatchWorkItem?
    var lockVideoProgress = ""
    /// 啟動前每台螢幕原本的桌布，供「關掉 App 後保留桌面」關閉時還原
    var originalDesktop: [CGDirectDisplayID: URL] = [:]
    var lastParallaxLog = Date.distantPast
    var pausedBySystem = false
    var systemHidden = false
    var healthTimer: Timer?
    var screenSyncWork: DispatchWorkItem?
    var lastPosterRefreshAt = Date.distantPast
    var libraryWindow: NSWindow?
    var settingsWindow: NSWindow?
    let libraryModel = LibraryModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 先記下使用者原本的桌布：若「關掉 App 後桌面保留同一張」是關的，結束時要還原
        for sc in NSScreen.screens {
            if let id = (sc.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
               let u = NSWorkspace.shared.desktopImageURL(for: sc) {
                originalDesktop[id] = u
            }
        }
        say("ORIGINAL-DESKTOP \(originalDesktop.mapValues { $0.lastPathComponent })")
        // 壁紙是長時間播放的影片，被系統 App Nap 壓下去會「看起來在播但畫面不動」
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            for sw in self.screens { sw.nudgeFrame() }
            say("NUDGE app-activate")
        }
        nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            for sw in self.screens { sw.nudgeFrame() }
            say("NUDGE space-change")
        }
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical],
                                                         reason: "播放動態壁紙")
        say("APP-NAP disabled")
        NSApp.setActivationPolicy(.accessory)
        Engine.shared.app = self
        ensureDirs()
        // 獨立打包的 App：第一次啟動時把自己內建的預設壁紙寫進設定（@bundle: 指向 App 內部檔案）
        if let preset = Bundle.main.url(forResource: "preset", withExtension: "json"),
           !fm.fileExists(atPath: CONFIG_URL.path),
           let data = try? Data(contentsOf: preset),
           (try? JSONDecoder().decode(Config.self, from: data)) != nil {
            try? data.write(to: CONFIG_URL)
            say("SEED-PRESET \(preset.lastPathComponent)")
        }
        cfg = loadConfig()
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .suddenTerminationDisabled],
                                                        reason: "動態壁紙持續播放")
        buildStatusItem()
        if CommandLine.arguments.contains("--copy-templates") {
            let copied = doCopyTemplates()
            say("CLI-COPY-TEMPLATES count=\(copied.count) dir=\(CUSTOM_DIR.path) custom=\(customEntries().count)")
        }
        // 壁紙庫這支 App 就是使用者的壁紙引擎：開啟就套用上次選的壁紙（同時顯示壁紙庫介面）
        syncScreens()
        let guiOnly = false
        if CommandLine.arguments.contains("--set") { announceTakeover() }   // CLI 換壁紙也算接手
        say("MODE guiOnly=\(guiOnly)")
        registerObservers()
        startHealthWatch()
        if let a = cliAutoStart { _ = setAutoStart(a == "on" || a == "true" || a == "1") }
        if cfg.autoStart { _ = writeLaunchAgent() }
        if DEBUG {
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in self?.probe() }
        }
        if CommandLine.arguments.contains("--dump-menu") {
            let m = statusItem.menu ?? NSMenu()
            menuNeedsUpdate(m)
            dumpMenu(m, indent: 0)
            exit(0)
        }
        if let i = args.firstIndex(of: "--cycle-test"), i + 1 < args.count, let period = Double(args[i + 1]) {
            startCycleTest(period: period)
        }
        if CommandLine.arguments.contains("--gui-test") {
            runGUITest()
        }
        if let i = CommandLine.arguments.firstIndex(of: "--import-we"), i + 1 < CommandLine.arguments.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let p = CommandLine.arguments[i + 1]
                let ok = self.importWEProject(at: URL(fileURLWithPath: p))
                say("WE-IMPORT result=\(ok)")
                self.libraryModel.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { NSApp.terminate(nil) }
            }
        }
        if CommandLine.arguments.contains("--lock-apply") || CommandLine.arguments.contains("--lock-restore") {
            headless = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if CommandLine.arguments.contains("--lock-restore") {
                    self.restoreAerial()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { NSApp.terminate(nil) }
                } else {
                    self.applyLockVideo()
                    // 轉檔是非同步的，最多等 5 分鐘才自己結束
                    DispatchQueue.main.asyncAfter(deadline: .now() + 300) { NSApp.terminate(nil) }
                }
            }
        }
        if CommandLine.arguments.contains("--quit-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { NSApp.terminate(nil) }
        }
        if CommandLine.arguments.contains("--ui-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.showLibraryWindow()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    let m = self.libraryModel
                    say("UITEST items=\(m.items.count) filtered_all=\(m.filtered.count)")
                    m.filter = "影片"; say("UITEST filter=影片 → \(m.filtered.count)")
                    m.filter = "內建"; say("UITEST filter=內建 → \(m.filtered.count)")
                    m.filter = "我的 HTML"; say("UITEST filter=我的 HTML → \(m.filtered.count)")
                    m.filter = "全部"; m.search = "NASA"; say("UITEST search=NASA → \(m.filtered.count)")
                    m.search = "zzzz"; say("UITEST search=zzzz → \(m.filtered.count)")
                    m.search = ""
                    // 最愛：加一張 → 我的頁應該只剩那張 → 取消
                    if let first = m.items.first {
                        let before = m.isFav(first.id)
                        m.toggleFav(first.id)
                        let favCount = m.favorites.count
                        let oldPage = m.page; m.page = .mine
                        say("UITEST fav id=\(first.id) count=\(favCount) minePage=\(m.pageItems.count)")
                        m.page = oldPage
                        if m.isFav(first.id) != before { m.toggleFav(first.id) }
                    }
                    // 存快照：全部 → 搜尋 NASA → 搜尋無結果
                    func snap(_ name: String) {
                        guard let w = self.libraryWindow, let v = w.contentView,
                              let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
                        v.cacheDisplay(in: v.bounds, to: rep)
                        if let data = rep.representation(using: .png, properties: [:]) {
                            try? data.write(to: URL(fileURLWithPath: "/tmp/ui-\(name).png"))
                            say("UITEST snap=\(name) bytes=\(data.count)")
                        }
                    }
                    snap("all")
                    m.search = "NASA"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        snap("nasa")
                        m.search = "zzzz"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            snap("empty")
                            m.search = ""
                            say("UITEST done")
                        }
                    }
                }
            }
        }
        if CommandLine.arguments.contains("--list-library") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let items = scanLibrary()
                say("LIST count=\(items.count)")
                for it in items { say("LIST \(it.kind) | \(it.title) | \(it.ref)") }
                let ids = items.map { $0.id }
                let dup = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }
                say("LIST duplicates=\(dup.count)")
            }
        }
        if CommandLine.arguments.contains("--tour-test") {
            runTourTest()
        }
        if CommandLine.arguments.contains("--snap-test") {
            if let i = CommandLine.arguments.firstIndex(of: "--page"), i + 1 < CommandLine.arguments.count {
                let name = CommandLine.arguments[i + 1]
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    let pages: [String: LibraryModel.Page] = ["首頁": .home, "靜態": .still, "動態": .motion, "我的": .mine]
                    self.libraryModel.page = pages[name] ?? .home
                    self.libraryModel.category = name == "靜態" ? "全部" : "全部"
                    say("SNAPTEST page=\(name) items=\(self.libraryModel.pageItems.count)")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                guard let w = self.libraryWindow, let v = w.contentView,
                      let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
                v.cacheDisplay(in: v.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    let pg = self.libraryModel.page.rawValue
try? data.write(to: URL(fileURLWithPath: "/tmp/library-snap-\(pg).png"))
try? data.write(to: URL(fileURLWithPath: "/tmp/library-snap.png"))
                    say("SNAPTEST bytes=\(data.count) px=\(rep.pixelsWide)x\(rep.pixelsHigh)")
                }
            }
        }
        if CommandLine.arguments.contains("--settings-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.showSettingsWindow()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    let order = NSApp.windows.filter { $0.isVisible }.map { "\($0.title)@\(Int($0.frame.minX)),\(Int($0.frame.minY))" }.joined(separator: " | ")
                    say("SETTINGSTEST appActive=\(NSApp.isActive) key=\(NSApp.keyWindow?.title ?? "-") order=[\(order)]")
                    if let w = self.settingsWindow {
                        say("SETTINGSTEST frame=\(Int(w.frame.width))x\(Int(w.frame.height)) visible=\(w.isVisible) onActiveSpace=\(w.isOnActiveSpace) level=\(w.level.rawValue) sheet=\(w.sheetParent != nil) title=\(w.title)")
                        // 把視窗內容自己畫成點陣圖，證明「有畫出來」（不依賴螢幕錄影權限）
                        if let v = w.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                            v.cacheDisplay(in: v.bounds, to: rep)
                            if let data = rep.representation(using: .png, properties: [:]) {
                                try? data.write(to: URL(fileURLWithPath: "/tmp/settings-snap.png"))
                                say("SETTINGSTEST snapshot bytes=\(data.count) px=\(rep.pixelsWide)x\(rep.pixelsHigh)")
                            }
                        }
                    } else {
                        say("SETTINGSTEST nil")
                    }
                }
            }
        }
        if !UserDefaults.standard.bool(forKey: "welcomed") { UserDefaults.standard.set(true, forKey: "welcomed") }
        // 圖形化介面：一般開啟就直接顯示壁紙庫；登入時自動啟動（--login）只在背景跑壁紙
        if !CommandLine.arguments.contains("--login") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.showLibraryWindow() }
        }
        say("READY screens=\(screens.count) kind=\(cfg.kind) ref=\(cfg.ref) level=\(screens.first?.window.level.rawValue ?? 0)")
        startParallax()
        startRotation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 關掉 App 前，先把「現在這一格」變成系統桌布 —— 否則桌面會變回原本的壁紙
        if !cfg.poster {
            restoreOriginalDesktop()
        }
        if cfg.poster && !screens.isEmpty {
            // 有現成海報就同步沿用（瞬間完成）；沒有才退回非同步產生，最多等 2 秒
            var needWait = false
            for s in screens where !s.posterOnQuit() { needWait = true }
            if needWait {
                let deadline = Date().addingTimeInterval(2.0)
                while Date() < deadline {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                }
            }
            say("POSTER-ON-QUIT screens=\(screens.count) waited=\(needWait)")
        }
        parallaxTimer?.invalidate()
        parallaxTimer = nil
        rotationTimer?.invalidate()
        rotationTimer = nil
        for s in screens { s.teardownContent() }
        if let a = activity { ProcessInfo.processInfo.endActivity(a) }
    }

    // MARK: 螢幕管理

    func syncScreens(reapply: Bool = false) {
        var ids = Set<CGDirectDisplayID>()
        for s in NSScreen.screens {
            if let n = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber { ids.insert(n.uint32Value) }
        }
        for sw in screens where !ids.contains(sw.displayID) { sw.destroy() }
        screens = screens.filter { ids.contains($0.displayID) }
        let existing = Set(screens.map { $0.displayID })
        var fresh = Set<CGDirectDisplayID>()
        for s in NSScreen.screens {
            guard let n = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            if !existing.contains(n.uint32Value), let sw = ScreenWallpaper(screen: s) {
                screens.append(sw)
                sw.watchOcclusion()
                fresh.insert(n.uint32Value)
                say("SCREEN-ADD id=\(n.uint32Value)")
            }
        }
        for sw in screens {
            sw.resizeToScreen()
            // 只有新螢幕或明確要求時才重建內容 —— 重建＝整組拆掉再裝，會閃一下
            if reapply || fresh.contains(sw.displayID) { sw.apply(cfg) }
        }
    }

    /// 螢幕參數變更用「去抖」處理，並在剛寫過桌布圖時忽略（否則會自我觸發成頻閃迴圈）
    func scheduleScreenSync() {
        screenSyncWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if Date().timeIntervalSince(lastDesktopWriteAt) < 2.0 {
                say("SCREEN-SYNC skip（剛寫過桌布圖）")
                return
            }
            self.syncScreens()
        }
        screenSyncWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: w)
    }

    func registerObservers() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.scheduleScreenSync() }
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.systemPause(true) }
        // 別的 DynWall App 說「我接手壁紙」→ 先留一張桌布，再讓位結束
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name(TAKEOVER), object: nil, queue: .main) { [weak self] n in
            guard let self, let from = n.userInfo?["from"] as? String, from != BUNDLE_ID else { return }
            say("TAKEOVER received from=\(from) → 讓位並結束")
            self.cfg.poster = true
            NSApp.terminate(nil)
        }
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.systemPause(false)
            self?.hideWallpaper(false)
        }
        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.systemPause(true) }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.systemPause(false)
            self?.hideWallpaper(false)
        }
        // 官方 API：登出／鎖定螢幕、切換使用者時暫停播放（省電）
        ws.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.systemPause(true) }
        ws.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.systemPause(false) }
        // 舊式分散式通知（部分系統版本靠這個）
        let dnc = DistributedNotificationCenter.default()
        // 第二次開啟 App 時（Finder 雙擊 / Dock）→ 把已執行中的視窗叫出來
        dnc.addObserver(forName: Notification.Name(BUNDLE_ID + ".showLibrary"), object: nil, queue: .main) { [weak self] _ in
            self?.showLibraryWindow()
        }
        dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in self?.systemPause(true) }
        dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.systemPause(false) }
    }

    func systemPause(_ pause: Bool) {
        pausedBySystem = pause
        for sw in screens {
            if pause { sw.pauseContent() }
            else if cfg.paused { sw.pauseContent() }
            else { sw.resumeContent() }
        }
        say("SYSTEM-PAUSE \(pause)")
        // 要進鎖定／睡眠前，先把「現在這一格」寫成桌布：登入畫面只認桌布圖，不會顯示我們的視窗
        if pause && (cfg.poster || cfg.lockPoster) {
            for sw in screens { sw.writeDesktopPoster(nil, force: true) }
            say("LOCK-POSTER refreshed screens=\(screens.count)")
        }
        // 醒來／解鎖後，系統有時會把桌布改回舊圖 → 重新套一次我們的定格圖（60 秒內不重複做，避免一直重畫）
        if !pause && (cfg.poster || cfg.lockPoster) && Date().timeIntervalSince(lastPosterRefreshAt) > 60 {
            lastPosterRefreshAt = Date()
            for sw in screens { sw.schedulePosterRefresh() }
        }
    }

    /// 把桌布還原成使用者啟動前的樣子（只有「關掉 App 後桌面保留同一張」關閉時才會做）
    func restoreOriginalDesktop() {
        for sc in NSScreen.screens {
            guard let id = (sc.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
                  let u = originalDesktop[id], fm.fileExists(atPath: u.path) else { continue }
            do {
                try NSWorkspace.shared.setDesktopImageURL(u, for: sc, options: [
                    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true,
                ])
                say("RESTORE-DESKTOP screen=\(id) file=\(u.lastPathComponent)")
            } catch {
                say("RESTORE-DESKTOP 失敗 screen=\(id) \(error)")
            }
        }
    }

    func hideWallpaper(_ hidden: Bool) {
        systemHidden = hidden
        for sw in screens {
            if hidden { sw.window.orderOut(nil) } else { sw.window.orderFrontRegardless() }
        }
    }

    // MARK: 健康檢查（不依賴通知：蓋上蓋子再打開時，系統不一定會發喚醒通知）

    func startHealthWatch() {
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.healthTick()
        }
    }

    func isScreenLocked() -> Bool {
        guard let d = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (d["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    var healthLogTick = 0

    func healthTick() {
        healthLogTick += 1
        if healthLogTick % 3 == 0 {
            for sw in screens {
                if let p = sw.player {
                    let st: String
                    switch p.timeControlStatus {
                    case .playing: st = "playing"
                    case .paused: st = "paused"
                    case .waitingToPlayAtSpecifiedRate: st = "waiting"
                    @unknown default: st = "?"
                    }
                    say(String(format: "HEALTH-PLAY d=%u t=%.2f %@ rate=%.1f vis=%d occl=%d pausedByFull=%@ sys=%@",
                               sw.displayID, p.currentTime().seconds, st, p.rate,
                               sw.window.isVisible ? 1 : 0,
                               sw.window.occlusionState.contains(.visible) ? 1 : 0,
                               pausedByFullscreen ? "1" : "0", pausedBySystem ? "1" : "0"))
                }
            }
        }
        let asleep = CGDisplayIsAsleep(CGMainDisplayID()) != 0
        let locked = isScreenLocked()
        let shouldPause = asleep || locked
        // 最重要的部分：狀態和實際情況不一致就矯正（通知漏接時靠這裡救回來）
        if shouldPause != pausedBySystem {
            say("HEALTH pause=\(shouldPause) asleep=\(asleep) locked=\(locked)")
            systemPause(shouldPause)
        }
        if shouldPause {
            return   // 只暫停播放，不把視窗收起來（收起來才會露出桌面定格圖）
        }
        if systemHidden { hideWallpaper(false) }       // 醒來就把視窗放回來（通知漏接也靠這裡）
        checkFullscreenPause()
        for sw in screens {
            // 不要在這裡盲目 orderFrontRegardless：全螢幕空間、螢幕剛醒時 isVisible 會是 false，
            // 每 3 秒重排一次視窗就會變成「規律頻閃」。真的不見了再處理，而且最多 30 秒一次。
            if !sw.window.isVisible {
                if Date().timeIntervalSince(sw.lastReorderAt) > 30 {
                    sw.window.orderFrontRegardless()
                    sw.lastReorderAt = Date()
                    say("HEALTH reorder screen=\(sw.displayID)")
                }
            }
            if let p = sw.player, !cfg.paused, !pausedByFullscreen, !pausedBySystem {
                let t = p.currentTime().seconds
                if abs(t - sw.lastVideoTime) < 0.03 {
                    sw.unfreezeVideo()
                } else {
                    sw.frozenTicks = 0
                }
                sw.lastVideoTime = t
            }
            if let p = sw.player, !cfg.paused, p.timeControlStatus == .paused {
                sw.idleTicks += 1
                if sw.idleTicks >= 2 {   // 連續兩次（6 秒）都沒在播才重播，避免打斷緩衝
                    p.play()
                    if cfg.rate != 1.0 { p.rate = Float(cfg.rate) }
                    sw.idleTicks = 0
                    say("HEALTH replay screen=\(sw.displayID)")
                }
            } else {
                sw.idleTicks = 0
            }
        }
    }

    // MARK: 選單列

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            if let img = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: "動態壁紙") {
                img.isTemplate = true
                b.image = img
            } else {
                b.title = "壁紙"
            }
            b.toolTip = "動態壁紙"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        let bw = statusItem.button?.window
        say("STATUSITEM hasImage=\(statusItem.button?.image != nil) title=\(statusItem.button?.title ?? "") "
            + "windowExists=\(bw != nil) frame=\(bw?.frame.debugDescription ?? "nil") "
            + "screenVisible=\(bw?.isVisible ?? false) length=\(statusItem.length)")
    }

    func info(_ t: String) -> NSMenuItem {
        let i = NSMenuItem(title: t, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    func action(_ t: String, _ sel: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: t, action: sel, keyEquivalent: "")
        i.target = self
        return i
    }

    func toggleItem(_ t: String, _ on: Bool, _ sel: Selector) -> NSMenuItem {
        let i = action(t, sel)
        i.state = on ? .on : .off
        return i
    }

    func currentLabel() -> String {
        switch cfg.kind {
        case "video": return "影片：" + (cfg.ref as NSString).lastPathComponent
        case "image": return "圖片：" + (cfg.ref as NSString).lastPathComponent
        case "web": return "自訂：" + (cfg.ref as NSString).lastPathComponent
        default: return "內建：" + (BUILTIN_TITLES[cfg.ref] ?? cfg.ref)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(info("動態壁紙 1.0"))
        let libItem = action("開啟壁紙庫…", #selector(showLibraryAction))
        libItem.keyEquivalent = "l"
        menu.addItem(libItem)
        let tourItem = action("顯示使用導覽…", #selector(showTourAction))
        menu.addItem(tourItem)
        let setItem = action("設定…", #selector(showSettingsAction))
        setItem.keyEquivalent = ","
        menu.addItem(setItem)
        menu.addItem(.separator())
        menu.addItem(info("目前：\(currentLabel())"))
        menu.addItem(info("螢幕：\(screens.count)　狀態：\(cfg.paused || pausedBySystem ? "暫停" : "播放中")"))
        menu.addItem(.separator())
        menu.addItem(toggleItem("暫停播放", cfg.paused, #selector(togglePause)))
        menu.addItem(.separator())

        menu.addItem(action("選擇影片檔…（mp4 / mov）", #selector(pickVideo)))
        menu.addItem(action("選擇 HTML 網頁檔…", #selector(pickHTML)))
        menu.addItem(action("選擇圖片 / GIF…", #selector(pickImage)))
        menu.addItem(action("匯入 Wallpaper Engine 網頁壁紙…", #selector(importWEAction)))
        menu.addItem(action("把目前影片套到鎖定畫面", #selector(applyLockVideo)))
        menu.addItem(action("還原鎖定畫面影片", #selector(restoreAerial)))

        let builtinItem = NSMenuItem(title: "內建動態壁紙", action: nil, keyEquivalent: "")
        let bm = NSMenu()
        for id in builtinIDs() {
            let it = action(BUILTIN_TITLES[id] ?? id, #selector(pickBuiltin))
            it.representedObject = id
            it.state = (cfg.kind == "builtin" && cfg.ref == id) ? .on : .off
            bm.addItem(it)
        }
        builtinItem.submenu = bm
        menu.addItem(builtinItem)

        let customItem = NSMenuItem(title: "我的自訂壁紙", action: nil, keyEquivalent: "")
        let cm = NSMenu()
        let entries = customEntries()
        if entries.isEmpty { cm.addItem(info("（還沒有，先按下面「複製內建範本」）")) }
        for e in entries {
            let it = action(e.title, #selector(pickCustom))
            it.representedObject = e.path
            it.state = (cfg.kind == "web" && cfg.ref == e.path) ? .on : .off
            cm.addItem(it)
        }
        cm.addItem(.separator())
        cm.addItem(action("複製內建壁紙成可編輯範本", #selector(copyTemplates)))
        cm.addItem(action("開啟自訂壁紙資料夾", #selector(openCustomFolder)))
        cm.addItem(action("重新掃描資料夾", #selector(rescan)))
        customItem.submenu = cm
        menu.addItem(customItem)

        menu.addItem(action("用瀏覽器開啟目前壁紙（預覽）", #selector(editCurrent)))
        menu.addItem(.separator())

        let optItem = NSMenuItem(title: "選項", action: nil, keyEquivalent: "")
        let om = NSMenu()
        om.addItem(toggleItem("靜音", cfg.mute, #selector(toggleMute)))

        let speedItem = NSMenuItem(title: "播放速度", action: nil, keyEquivalent: "")
        let sm = NSMenu()
        for r in [0.5, 1.0, 1.5, 2.0] {
            let it = action("\(r)x", #selector(pickRate))
            it.representedObject = r
            it.state = abs(cfg.rate - r) < 0.01 ? .on : .off
            sm.addItem(it)
        }
        speedItem.submenu = sm
        om.addItem(speedItem)

        let scaleItem = NSMenuItem(title: "畫面縮放", action: nil, keyEquivalent: "")
        let scm = NSMenu()
        for (k, t) in [("fill", "填滿畫面（裁切）"), ("fit", "完整顯示（留黑邊）"), ("stretch", "延展變形")] {
            let it = action(t, #selector(pickGravity))
            it.representedObject = k
            it.state = cfg.gravity == k ? .on : .off
            scm.addItem(it)
        }
        scaleItem.submenu = scm
        om.addItem(scaleItem)

        let dimItem = NSMenuItem(title: "暗化（讓桌面圖示更清楚）", action: nil, keyEquivalent: "")
        let dm = NSMenu()
        for d in [0.0, 0.2, 0.4, 0.6] {
            let it = action("\(Int(d * 100))%", #selector(pickDim))
            it.representedObject = d
            it.state = abs(cfg.dim - d) < 0.01 ? .on : .off
            dm.addItem(it)
        }
        dimItem.submenu = dm
        om.addItem(dimItem)

        om.addItem(toggleItem("允許滑鼠互動（自訂網頁用）", cfg.interactive, #selector(toggleInteractive)))
        om.addItem(.separator())
        om.addItem(toggleItem("開機自動啟動", cfg.autoStart, #selector(toggleAutoStart)))
        om.addItem(toggleItem("關掉 App 後桌面保留同一張（靜態）", cfg.poster, #selector(togglePoster)))
        optItem.submenu = om
        menu.addItem(optItem)

        menu.addItem(.separator())
        menu.addItem(action("重新載入壁紙", #selector(reloadWallpaper)))
        menu.addItem(action("回復成內建・極光", #selector(resetDefault)))
        menu.addItem(action("開啟設定檔（config.json）", #selector(openConfig)))
        menu.addItem(.separator())
        menu.addItem(action("關於動態壁紙…", #selector(showAbout)))
        menu.addItem(action("結束動態壁紙", #selector(quitApp)))
    }

    /// 關於：帶著作者與授權資訊（授權要求保留署名，散布時不得移除）
    @objc func showAbout() {
        let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let alert = NSAlert()
        alert.messageText = "動態壁紙 DynWall \(v)"
        alert.informativeText = """
        作者：shimianyizhimiao
        授權：PolyForm Noncommercial 1.0.0 + Share-Alike 附加條款
        　　　（禁止商業使用；修改後散布必須以相同條款開源，不得閉源）

        原始碼：https://github.com/shimianyizhimiao/dynwall

        本程式為個人自製專案，免費提供。若你是從付費管道拿到這支程式，
        那不是作者發布的版本。
        """
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: 選單動作

    func setSource(kind: String, ref: String, interactive: Bool) {
        cfg.kind = kind
        cfg.ref = ref
        cfg.interactive = interactive
        cfg.paused = false
        saveConfig(cfg)
        for sw in screens { sw.apply(cfg) }
        say("SOURCE kind=\(kind) ref=\(ref)")
    }

    @objc func pickVideo() {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.canChooseDirectories = false
        p.allowsMultipleSelection = false
        p.message = "選擇要當作動態壁紙的影片"
        p.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        if p.runModal() == .OK, let u = p.url { setSource(kind: "video", ref: u.path, interactive: false) }
    }

    @objc func pickHTML() {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.canChooseDirectories = false
        p.allowsMultipleSelection = false
        p.message = "選擇 HTML 網頁檔（CSS / JS 動畫都可以）"
        p.allowedContentTypes = [.html]
        if p.runModal() == .OK, let u = p.url { setSource(kind: "web", ref: u.path, interactive: true) }
    }

    @objc func pickImage() {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.canChooseDirectories = false
        p.allowsMultipleSelection = false
        p.message = "選擇圖片（GIF 會動）"
        p.allowedContentTypes = [.gif, .image]
        if p.runModal() == .OK, let u = p.url { setSource(kind: "image", ref: u.path, interactive: false) }
    }

    @objc func pickBuiltin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        setSource(kind: "builtin", ref: id, interactive: false)
    }

    @objc func pickCustom(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        setSource(kind: "web", ref: path, interactive: true)
    }

    @objc func togglePause() {
        cfg.paused.toggle()
        saveConfig(cfg)
        for sw in screens { cfg.paused ? sw.pauseContent() : sw.resumeContent() }
        say("PAUSE \(cfg.paused)")
    }

    @objc func toggleMute() {
        cfg.mute.toggle()
        saveConfig(cfg)
        for sw in screens {
            sw.player?.isMuted = cfg.mute
            sw.player?.volume = cfg.mute ? 0 : 1
        }
    }

    @objc func pickRate(_ sender: NSMenuItem) {
        guard let r = sender.representedObject as? Double else { return }
        cfg.rate = r
        saveConfig(cfg)
        for sw in screens where sw.player != nil && !cfg.paused { sw.player?.rate = Float(r) }
    }

    @objc func pickGravity(_ sender: NSMenuItem) {
        guard let g = sender.representedObject as? String else { return }
        cfg.gravity = g
        saveConfig(cfg)
        for sw in screens {
            sw.playerLayer?.videoGravity = gravityValue(g)
            if cfg.kind == "image" { sw.apply(cfg) }
        }
    }

    @objc func pickDim(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? Double else { return }
        cfg.dim = d
        saveConfig(cfg)
        for sw in screens { sw.cfg.dim = d; sw.updateDim(d) }
    }

    @objc func toggleInteractive() {
        cfg.interactive.toggle()
        saveConfig(cfg)
        let allowMouse = cfg.interactive && (cfg.kind == "web" || cfg.kind == "builtin" || cfg.kind == "image")
        for sw in screens { sw.window.ignoresMouseEvents = !allowMouse }
    }

    @objc func copyTemplates() {
        let copied = doCopyTemplates()
        let a = NSAlert()
        a.messageText = "已複製 \(copied.count) 個可編輯範本"
        a.informativeText = "位置：\(CUSTOM_DIR.path)\n\n用任何文字編輯器打開裡面的 index.html，改最上面的 CONFIG 數字，存檔後桌面立刻更新（不用重開 App）。"
        a.addButton(withTitle: "開啟資料夾")
        a.addButton(withTitle: "好")
        if a.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(CUSTOM_DIR) }
    }

    /// 把內建壁紙複製到使用者的自訂資料夾（純檔案動作，不跳視窗）
    @discardableResult
    func doCopyTemplates() -> [String] {
        guard let src = builtinResourceDir() else { return [] }
        ensureDirs()
        var copied: [String] = []
        for id in builtinIDs() {
            let title = BUILTIN_TITLES[id] ?? id
            let dest = CUSTOM_DIR.appendingPathComponent("\(title)（可編輯）", isDirectory: true)
            try? fm.removeItem(at: dest)
            do {
                try fm.copyItem(at: src.appendingPathComponent(id), to: dest)
                copied.append(title)
            } catch { dbg("複製範本失敗 \(id): \(error)") }
        }
        say("COPY-TEMPLATES \(copied.joined(separator: ","))")
        return copied
    }

    @objc func openCustomFolder() {
        ensureDirs()
        NSWorkspace.shared.open(CUSTOM_DIR)
    }

    // MARK: Wallpaper Engine 網頁壁紙匯入

    @objc func importWEAction() {
        let panel = NSOpenPanel()
        panel.title = "選擇 Wallpaper Engine 專案（project.json 或整個資料夾）"
        panel.message = "會把整個專案複製進壁紙庫，之後不依賴原本的位置"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["json"]
        panel.begin { [weak self] resp in
            guard let self, resp == .OK else { return }
            var ok = 0
            for u in panel.urls where self.importWEProject(at: u) { ok += 1 }
            self.libraryModel.refresh()
            let a = NSAlert()
            a.messageText = ok > 0 ? "已匯入 \(ok) 個網頁壁紙" : "匯入失敗"
            a.informativeText = ok > 0
                ? "已放進壁紙庫，選一張按「套用到桌面」即可。\n註：Wallpaper Engine 的「屬性」面板與音訊視覺化不支援，會用預設值跑。"
                : "找不到 project.json，或複製時出錯。詳見 ~/Library/Logs/動態壁紙.log。"
            a.runModal()
        }
    }

    /// 把一個 Wallpaper Engine 專案（type=web）複製進壁紙庫
    @discardableResult
    func importWEProject(at url: URL) -> Bool {
        var dir = url
        var isDir: ObjCBool = false
        if !(fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue) {
            dir = url.deletingLastPathComponent()
        }
        let pj = dir.appendingPathComponent("project.json")
        guard let data = try? Data(contentsOf: pj),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            say("WE-IMPORT 失敗：\(dir.lastPathComponent) 沒有可讀的 project.json")
            return false
        }
        let type = (obj["type"] as? String) ?? "?"
        guard type == "web" else {
            say("WE-IMPORT 失敗：type=\(type)（只支援網頁型 web）")
            return false
        }
        let rawTitle = (obj["title"] as? String) ?? ""
        let title = rawTitle.isEmpty ? dir.lastPathComponent : rawTitle
        let entry = (obj["file"] as? String) ?? "index.html"
        let safe = title.replacingOccurrences(of: "/", with: "-")
                         .replacingOccurrences(of: ":", with: "-")
                         .trimmingCharacters(in: .whitespacesAndNewlines)
        let dest = LIBRARY_DIR.appendingPathComponent(safe)
        try? fm.removeItem(at: dest)
        do { try fm.copyItem(at: dir, to: dest) }
        catch { say("WE-IMPORT 複製失敗：\(error)"); return false }
        let idx = dest.appendingPathComponent("index.html")
        if entry != "index.html", !fm.fileExists(atPath: idx.path) {
            let html = """
            <!DOCTYPE html><meta charset="utf-8">
            <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}iframe{border:0;width:100%;height:100%}</style>
            <iframe src="\(entry)" allow="autoplay"></iframe>
            """
            try? html.write(to: idx, atomically: true, encoding: .utf8)
        }
        say("WE-IMPORT ok title=\(title) entry=\(entry) dir=\(dest.lastPathComponent)")
        return true
    }

    @objc func rescan() {
        say("RESCAN custom=\(customEntries().count) builtin=\(builtinIDs().count)")
    }

    @objc func editCurrent() {
        let p = resolveRef(cfg.ref)
        if (cfg.kind == "web" || cfg.kind == "video" || cfg.kind == "image"), fm.fileExists(atPath: p) {
            NSWorkspace.shared.open(URL(fileURLWithPath: p))
        } else if cfg.kind == "builtin", let u = builtinURL(cfg.ref) {
            NSWorkspace.shared.open(u)
        } else {
            rescan()
        }
    }

    @objc func openConfig() {
        ensureDirs()
        if !fm.fileExists(atPath: CONFIG_URL.path) { saveConfig(cfg) }
        NSWorkspace.shared.open(CONFIG_URL)
    }

    @objc func reloadWallpaper() {
        for sw in screens { sw.apply(cfg) }
    }

    @objc func resetDefault() {
        let auto = cfg.autoStart
        cfg = Config()
        cfg.autoStart = auto
        saveConfig(cfg)
        for sw in screens { sw.apply(cfg) }
        say("RESET default")
    }

    @objc func toggleAutoStart() {
        let target = !cfg.autoStart
        if target { _ = setAutoStart(true) } else { _ = setAutoStart(false) }
        saveConfig(cfg)
    }

    /// 開／關「關掉 App 後把目前畫面留在桌面上」
    @objc func togglePoster() {
        guiSetPoster(!cfg.poster)
    }

    @objc func quitApp() {
        saveConfig(cfg)
        NSApp.terminate(nil)
    }

    // MARK: 開機自動啟動

    func writeLaunchAgent() -> Bool {
        guard let bin = Bundle.main.executableURL?.path ?? CommandLine.arguments.first else { return false }
        ensureDirs()
        let plist: [String: Any] = [
            "Label": AGENT_LABEL,
            "ProgramArguments": [bin, "--login"],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return false }
        try? fm.createDirectory(at: AGENT_URL.deletingLastPathComponent(), withIntermediateDirectories: true)
        do { try data.write(to: AGENT_URL) } catch { dbg("寫入 LaunchAgent 失敗 \(error)"); return false }
        return true
    }

    @discardableResult
    func setAutoStart(_ on: Bool) -> Bool {
        if on {
            guard writeLaunchAgent() else { return false }
            _ = runTool("/bin/launchctl", ["bootout", "gui/\(getuid())/\(AGENT_LABEL)"])
            let (ok, out) = runTool("/bin/launchctl", ["bootstrap", "gui/\(getuid())", AGENT_URL.path])
            cfg.autoStart = true
            say("AUTOSTART on ok=\(ok) \(out.trimmingCharacters(in: .whitespacesAndNewlines))")
            return ok
        } else {
            _ = runTool("/bin/launchctl", ["bootout", "gui/\(getuid())/\(AGENT_LABEL)"])
            try? fm.removeItem(at: AGENT_URL)
            cfg.autoStart = false
            say("AUTOSTART off")
            return true
        }
    }

    func runTool(_ path: String, _ args: [String]) -> (Bool, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (false, "\(error)") }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (p.terminationStatus == 0, String(data: data, encoding: .utf8) ?? "")
    }

    // MARK: 首次啟動說明

    func welcome() {
        let a = NSAlert()
        a.messageText = "動態壁紙已經開始運作"
        a.informativeText = """
        壁紙畫在桌面圖示的下面、桌面圖片上面：桌面圖示、右鍵選單、Spotlight 都照常可用。

        控制的地方在「選單列的 🖼 圖示」——
        ⚠️ 你的選單列是設定成自動隱藏的，所以把滑鼠移到螢幕最上面，選單列出現後就會看到圖示。

        點它之後可以：
        • 選擇影片檔 → 任何 mp4 / mov 影片
        • 內建動態壁紙 → 極光、星海、賽博格柵、數位雨
        • 我的自訂壁紙 → 自己寫 HTML + CSS + JS 的動態壁紙（存檔即時更新）
        • 選項 → 靜音、播放速度、縮放、暗化、開機自動啟動

        想結束程式也在同一個選單裡。
        """
        a.addButton(withTitle: "知道了")
        a.addButton(withTitle: "開啟自訂壁紙資料夾")
        if a.runModal() == .alertSecondButtonReturn { openCustomFolder() }
    }

    // MARK: 診斷

    /// 印出整個選單結構（自我檢查用）
    func dumpMenu(_ menu: NSMenu, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        if indent == 0 { say("MENU 頂層項目：\(menu.numberOfItems)") }
        for i in 0..<menu.numberOfItems {
            let it = menu.item(at: i)!
            if it.isSeparatorItem {
                say("\(pad)──")
                continue
            }
            let state = it.state == .on ? "[✓]" : "[ ]"
            let enabled = it.isEnabled ? "" : "（不可點）"
            let sub = it.submenu == nil ? "" : " ▸ (\(it.submenu!.numberOfItems) 項)"
            say("\(pad)\(state) \(it.title)\(enabled)\(sub)")
            if let sm = it.submenu { dumpMenu(sm, indent: indent + 1) }
        }
    }

    /// 自我測試：每隔幾秒自動切換不同來源，驗證執行中切換（選單換壁紙）不會出問題
    func startCycleTest(period: Double) {
        var idx = 0
        let seq: [(String, String)] = [
            ("builtin", "aurora"),
            ("builtin", "starfield"),
            ("web", "\(CUSTOM_DIR.path)/極光（可編輯）/index.html"),
            ("builtin", "cybergrid"),
            ("builtin", "matrix")
        ]
        Timer.scheduledTimer(withTimeInterval: period, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let s = seq[idx % seq.count]
            idx += 1
            say("CYCLE \(idx) -> \(s.0) \(s.1)")
            self.setSource(kind: s.0, ref: s.1, interactive: s.0 == "web")
        }
    }

    func probe() {
        let bw = statusItem.button?.window
        say("STATUSMENUBAR frame=\(bw?.frame.debugDescription ?? "nil") visible=\(bw?.isVisible ?? false) screen=\(bw?.screen?.frame.debugDescription ?? "nil")")
        for sw in screens {
            say("STATUS \(sw.probeInfo())")
            sw.probeJS { s in
                if !s.isEmpty { say("STATUSJS screen=\(sw.displayID)\(s)") }
            }
        }
    }
}

// MARK: ───────────────────────── GUI 壁紙庫（被 gui.swift 的介面呼叫）

extension AppDelegate {
    func guiApply(kind: String, ref: String) {
        if screens.isEmpty { syncScreens() }   // 只開介面時，第一次按「套用」才真的建立壁紙視窗
        announceTakeover()                     // 讓其他壁紙 App 讓位，避免兩層壁紙疊在一起
        setSource(kind: kind, ref: ref, interactive: kind == "web")
    }

    /// 告訴其他 DynWall 系列 App「現在由我負責壁紙」
    func announceTakeover() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(TAKEOVER), object: nil,
            userInfo: ["from": BUNDLE_ID], deliverImmediately: true)
        say("TAKEOVER announce from=\(BUNDLE_ID)")
    }

    func guiSetRate(_ r: Double) {
        cfg.rate = r
        saveConfig(cfg)
        for sw in screens where sw.player != nil && !cfg.paused { sw.player?.rate = Float(r) }
    }

    func guiSetGravity(_ g: String) {
        cfg.gravity = g
        saveConfig(cfg)
        for sw in screens {
            sw.playerLayer?.videoGravity = gravityValue(g)
            if cfg.kind == "image" { sw.apply(cfg) }
        }
    }

    func guiSetDim(_ d: Double) {
        cfg.dim = d
        saveConfig(cfg)
        for sw in screens { sw.cfg.dim = d; sw.updateDim(d) }
    }

    func guiSetMute(_ m: Bool) {
        cfg.mute = m
        saveConfig(cfg)
        for sw in screens {
            sw.player?.isMuted = m
            sw.player?.volume = m ? 0 : 1
        }
    }

    func guiSetInteractive(_ on: Bool) {
        cfg.interactive = on
        saveConfig(cfg)
        let allowMouse = on && (cfg.kind == "web" || cfg.kind == "builtin" || cfg.kind == "image")
        for sw in screens { sw.window.ignoresMouseEvents = !allowMouse }
    }

    func guiSetPaused(_ paused: Bool) {
        cfg.paused = paused
        saveConfig(cfg)
        for sw in screens { paused ? sw.pauseContent() : sw.resumeContent() }
    }

    func guiSetAutoStart(_ on: Bool) {
        _ = setAutoStart(on)
        saveConfig(cfg)
    }

    /// 「關掉 App 後桌面保留同一張靜態圖」
    func guiSetPoster(_ on: Bool) {
        cfg.poster = on
        saveConfig(cfg)
        for sw in screens {
            sw.cfg.poster = on
            if on { sw.schedulePosterRefresh() }
        }
        say("SET-POSTER \(on)")
    }

    // 已經在執行時，使用者又雙擊 App／按 Dock 圖示 → 把壁紙庫視窗叫出來
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 設定窗開著時（例如在 Dock 點一下 App）不要把壁紙庫又叫到設定窗上面
        if let s = settingsWindow, s.isVisible {
            s.orderFrontRegardless()
            s.makeKey()
            return true
        }
        showLibraryWindow()
        return true
    }

    /// GUI 自測：把壁紙庫打開、列出項目、模擬點選套用與調整設定
    func runGUITest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [self] in
            showLibraryWindow()
            say("GUITEST items=\(libraryModel.items.count) filtered=\(libraryModel.filtered.count)")
            for (i, it) in libraryModel.items.enumerated() {
                say("GUITEST item[\(i)] kind=\(it.kind) title=\(it.title) sub=\(it.subtitle)")
            }
            var polls = 0
            func pollThumbs() {
                polls += 1
                let n = libraryModel.items.filter { $0.thumb != nil }.count
                say("GUITEST thumbs t=\(polls * 2)s → \(n)/\(libraryModel.items.count)")
                if polls < 14 && n < libraryModel.items.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { pollThumbs() }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { pollThumbs() }
            var delay = 9.0
            for k in ["video", "image", "builtin"] {
                if let it = libraryModel.items.first(where: { $0.kind == k }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                        say("GUITEST apply \(k) → \(it.title)")
                        libraryModel.apply(it)
                        say("GUITEST applied current=\(libraryModel.isCurrent(it))")
                    }
                    delay += 4
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 記住使用者原本的設定，測完要還原（不然會被留在暗化 0.3／速度 1.5／留黑邊）
                let oldDim = self.cfg.dim, oldRate = self.cfg.rate, oldGravity = self.cfg.gravity
                Engine.shared.setDim(0.3)
                Engine.shared.setRate(1.5)
                Engine.shared.setGravity("fit")
                say("GUITEST settings dim=0.3 rate=1.5 gravity=fit")
                let thumbs = (try? fm.contentsOfDirectory(atPath: CACHE_DIR.appendingPathComponent("thumbs").path)) ?? []
                say("GUITEST thumb-cache=\(thumbs.count)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    Engine.shared.setDim(oldDim)
                    Engine.shared.setRate(oldRate)
                    Engine.shared.setGravity(oldGravity)
                    say("GUITEST restored dim=\(oldDim) rate=\(oldRate) gravity=\(oldGravity)")
                }
            }
        }
    }

    // MARK: 壁紙庫視窗

    func showLibraryWindow() {
        if libraryWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 700),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = "動態壁紙庫"
            w.isReleasedWhenClosed = false
            w.isOpaque = false                     // 玻璃質感：讓背景用材質透出桌面
            w.backgroundColor = .clear
            w.delegate = self
            w.contentView = NSHostingView(rootView: LibraryView(model: libraryModel))
            w.center()
            libraryWindow = w
            libraryModel.refresh()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        libraryWindow?.makeKeyAndOrderFront(nil)
        libraryModel.refresh()
        say("LIBRARY-OPEN items=\(libraryModel.items.count)")
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === libraryWindow {
            NSApp.setActivationPolicy(.accessory)
            say("LIBRARY-CLOSE")
        }
    }

    // MARK: 鎖定畫面動態（macOS 26 的 aerial 影片槽）

    /// macOS 26 把「鎖定畫面播放的影片」放在這裡；換掉裡面的 .mov，鎖定畫面就會播我們的影片
    func aerialDir() -> URL {
        fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/videos", isDirectory: true)
    }

    func aerialSlots() -> [URL] {
        let files = (try? fm.contentsOfDirectory(at: aerialDir(), includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.filter { $0.pathExtension.lowercased() == "mov" }
    }

    func aerialBackupDir() -> URL {
        let d = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/動態壁紙/aerial-backup", isDirectory: true)
        try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// 把目前壁紙的影片轉成 HEVC .mov，換進 aerial 槽；原檔會先備份
    /// HEVC 轉檔（鎖定畫面只吃 HEVC 的 .mov；AVAssetExportSession 在 4K60 會偷偷輸出 H.264）
    func transcodeToHEVC(_ src: URL, _ dst: URL, done: @escaping (Bool, String?) -> Void) {
        let asset = AVURLAsset(url: src)
        guard let track = asset.tracks(withMediaType: .video).first else { done(false, "沒有影像軌"); return }
        let t = track.preferredTransform
        let sz = track.naturalSize.applying(t)
        let w = Int(abs(sz.width).rounded()), h = Int(abs(sz.height).rounded())
        guard let reader = try? AVAssetReader(asset: asset) else { done(false, "開不了影片"); return }
        let pix: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: pix)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        try? fm.removeItem(at: dst)
        guard let writer = try? AVAssetWriter(outputURL: dst, fileType: .mov) else { done(false, "建不了輸出檔"); return }
        let bitrate = max(16_000_000, w * h * 20 / 100)   // 4K 約 16–20 Mbps，鎖定畫面看起來才不會糊
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoAllowFrameReorderingKey: true,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        input.transform = t
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pix)
        guard writer.canAdd(input) else { done(false, "writer 不收這個設定"); return }
        writer.add(input)
        guard writer.startWriting(), reader.startReading() else { done(false, "啟動失敗"); return }
        writer.startSession(atSourceTime: .zero)
        let q = DispatchQueue(label: "dynwall.hevc")
        var finished = false
        input.requestMediaDataWhenReady(on: q) {
            while input.isReadyForMoreMediaData {
                guard !finished else { return }
                if let sb = output.copyNextSampleBuffer() {
                    if let pb = CMSampleBufferGetImageBuffer(sb) {
                        adaptor.append(pb, withPresentationTime: CMSampleBufferGetPresentationTimeStamp(sb))
                    }
                } else {
                    finished = true
                    input.markAsFinished()
                    reader.cancelReading()
                    writer.finishWriting {
                        let ok = writer.status == .completed
                        done(ok, ok ? nil : writer.error?.localizedDescription)
                    }
                    return
                }
            }
        }
    }

    // MARK: 鎖定畫面的圖示設定（macOS 把「鎖定畫面／螢幕保護」存在 Idle，跟桌布分開）

    func wallpaperStoreURL() -> URL {
        fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    }

    /// 讀出整份桌布設定（失敗回 nil）
    func readWallpaperStore() -> [String: Any]? {
        guard let data = try? Data(contentsOf: wallpaperStoreURL()),
              let obj = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        return obj
    }

    func backupWallpaperStore() {
        let bak = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/動態壁紙/Index.plist.bak")
        guard !fm.fileExists(atPath: bak.path) else { return }
        try? fm.copyItem(at: wallpaperStoreURL(), to: bak)
        say("STORE backup=\(bak.lastPathComponent)")
    }

    func writeWallpaperStore(_ obj: [String: Any]) -> Bool {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: obj, format: .binary, options: 0) else { return false }
        do { try data.write(to: wallpaperStoreURL()); return true } catch { say("STORE write failed \(error)"); return false }
    }

    func scheduleLockSync() {
        lockSyncWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self, !self.cfg.lockVideoOn else { return }
            self.syncLockToDesktop()
        }
        lockSyncWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: w)
    }

    /// 把每個螢幕「鎖定畫面（Idle）」設成跟桌面同一張 —— 打密碼時就不會再看到舊圖
    @discardableResult
    func syncLockToDesktop() -> Bool {
        guard var obj = readWallpaperStore() else { say("STORE read failed"); return false }
        guard var displays = obj["Displays"] as? [String: Any] else { return false }
        var changed = 0
        for (id, value) in displays {
            guard var v = value as? [String: Any],
                  var desk = v["Desktop"] as? [String: Any],
                  var idle = v["Idle"] as? [String: Any] else { continue }
            guard var deskContent = desk["Content"] as? [String: Any],
                  var idleContent = idle["Content"] as? [String: Any] else { continue }
            idleContent["Choices"] = deskContent["Choices"]
            if let opt = deskContent["EncodedOptionValues"] { idleContent["EncodedOptionValues"] = opt }
            idle["Content"] = idleContent
            v["Idle"] = idle
            displays[id] = v
            changed += 1
        }
        guard changed > 0 else { say("STORE 沒有可同步的螢幕"); return false }
        obj["Displays"] = displays
        backupWallpaperStore()
        let ok = writeWallpaperStore(obj)
        say("STORE idle←desktop screens=\(changed) ok=\(ok)")
        return ok
    }

    /// 把系統桌布設定還原成 App 第一次改之前的樣子
    @objc func restoreWallpaperStore() {
        let bak = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/動態壁紙/Index.plist.bak")
        guard fm.fileExists(atPath: bak.path) else { alert("沒有備份", "這個 App 還沒改過系統桌布設定。"); return }
        do {
            try? fm.removeItem(at: wallpaperStoreURL())
            try fm.copyItem(at: bak, to: wallpaperStoreURL())
            restartWallpaperAgent()
            say("STORE restored from backup")
            alert("已還原", "系統桌布設定已還原成 App 改動前的樣子，並重啟 WallpaperAgent。")
        } catch {
            alert("還原失敗", "\(error)")
        }
    }

    /// 找出系統裡現成的「動態桌布」選項，回傳它的 assetID（給鎖定畫面用）
    func aerialChoice() -> (choice: [String: Any], assetID: String)? {
        guard let obj = readWallpaperStore(), let displays = obj["Displays"] as? [String: Any] else { return nil }
        for (_, value) in displays {
            guard let v = value as? [String: Any] else { continue }
            for kind in ["Idle", "Desktop"] {
                guard let k = v[kind] as? [String: Any],
                      let content = k["Content"] as? [String: Any],
                      let choices = content["Choices"] as? [[String: Any]] else { continue }
                for c in choices {
                    guard let provider = c["Provider"] as? String, provider.contains("aerial"),
                          let conf = c["Configuration"] as? Data,
                          let inner = try? PropertyListSerialization.propertyList(from: conf, format: nil) as? [String: Any],
                          let asset = inner["assetID"] as? String else { continue }
                    return (c, asset)
                }
            }
        }
        return nil
    }

    /// 把鎖定畫面設成那張動態桌布（影片檔由我們寫進去）
    @discardableResult
    func useAerialForLock() -> String? {
        guard let (choice, asset) = aerialChoice() else { say("STORE 沒有 aerial 選項"); return nil }
        guard var obj = readWallpaperStore(), var displays = obj["Displays"] as? [String: Any] else { return nil }
        for (id, value) in displays {
            guard var v = value as? [String: Any], var idle = v["Idle"] as? [String: Any],
                  var content = idle["Content"] as? [String: Any] else { continue }
            content["Choices"] = [choice]
            idle["Content"] = content
            v["Idle"] = idle
            displays[id] = v
        }
        obj["Displays"] = displays
        backupWallpaperStore()
        let ok = writeWallpaperStore(obj)
        say("STORE idle←aerial asset=\(asset) ok=\(ok)")
        return ok ? asset : nil
    }

    // MARK: 鎖定影片：自動同步（勾一次就好）

    func lockVideoCacheDir() -> URL {
        let d = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/動態壁紙/lockvideo", isDirectory: true)
        try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func lockVideoCacheURL() -> URL {
        let h = shortHash(cfg.kind + "|" + cfg.ref + "|" + String(describing: (try? fm.attributesOfItem(atPath: resolveRef(cfg.ref))[.size]) ?? ""))
        return lockVideoCacheDir().appendingPathComponent("lock-\(h).mov")
    }

    /// 挑一個系統 aerial 資產（優先用正在用的，否則用目錄裡的 Tahoe Day）
    func pickAerialAsset() -> String {
        if let a = aerialChoice()?.assetID { return a }
        let manifest = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json")
        if let data = try? Data(contentsOf: manifest),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let assets = obj["assets"] as? [[String: Any]] {
            if let tahoe = assets.first(where: { ($0["accessibilityLabel"] as? String) == "Tahoe Day" }),
               let id = tahoe["id"] as? String { return id }
            if let id = assets.first?["id"] as? String { return id }
        }
        return "4C108785-A7BA-422E-9C79-B0129F1D5550"   // Tahoe Day 的固定 id（macOS 26）
    }

    /// 把桌面（和鎖定畫面）都設成同一個 aerial 資產
    @discardableResult
    func setWallpaperToAerial(_ asset: String) -> Bool {
        guard var obj = readWallpaperStore(), var displays = obj["Displays"] as? [String: Any] else {
            say("STORE 讀不到"); return false
        }
        guard let conf = try? PropertyListSerialization.data(fromPropertyList: ["assetID": asset],
                                                             format: .binary, options: 0) else { return false }
        let choice: [String: Any] = [
            "Provider": "com.apple.wallpaper.choice.aerials",
            "Configuration": conf,
            "Files": [Any](),
        ]
        var n = 0
        for (id, v) in displays {
            guard var vv = v as? [String: Any] else { continue }
            for kind in ["Desktop", "Idle"] {
                guard var k = vv[kind] as? [String: Any],
                      var content = k["Content"] as? [String: Any] else { continue }
                content["Choices"] = [choice]
                k["Content"] = content
                vv[kind] = k
            }
            displays[id] = vv
            n += 1
        }
        obj["Displays"] = displays
        backupWallpaperStore()
        let ok = writeWallpaperStore(obj)
        say("STORE wallpaper←aerial asset=\(asset) screens=\(n) ok=\(ok)")
        return ok
    }

    /// 一鍵：轉檔 → 寫進 aerial 槽 → 把桌面與鎖定畫面都指到它（完全不使用者去系統設定）
    func syncLockVideo() {
        guard cfg.lockVideoOn else { say("LOCKVIDEO off"); return }
        guard cfg.kind == "video" else {
            say("LOCKVIDEO skip kind=\(cfg.kind)")
            lockVideoProgress = "只支援影片壁紙"
            return
        }
        let asset = pickAerialAsset()
        let target = aerialDir().appendingPathComponent("\(asset).mov")
        try? fm.createDirectory(at: aerialDir(), withIntermediateDirectories: true)
        let cached = lockVideoCacheURL()

        let finishInstall: (URL) -> Void = { src in
            do {
                try? fm.removeItem(at: target)
                try fm.copyItem(at: src, to: target)
            } catch {
                say("LOCKVIDEO 寫入失敗 \(error)")
                self.lockVideoProgress = "寫入失敗"
                return
            }
            let ok = self.setWallpaperToAerial(asset)
            self.lockVideoProgress = ok ? "已同步（按 Ctrl+Cmd+Q 看看）" : "系統設定寫入失敗"
            say("LOCKVIDEO installed asset=\(asset) store=\(ok) size=\(((try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) / 1_048_576)MB")
            if ok && self.lockVideoInteractive {
                self.lockVideoInteractive = false
                self.alert("鎖定畫面已經換成你的影片",
                               "系統的桌布與鎖定畫面都指到同一個動態桌布，影片是剛剛轉好的那一支。\n\n按 Ctrl+Cmd+Q 鎖定看看。")
            }
        }

        if fm.fileExists(atPath: cached.path) {
            lockVideoProgress = "套用中…"
            finishInstall(cached)
            return
        }
        let src = URL(fileURLWithPath: resolveRef(cfg.ref))
        say("LOCKVIDEO converting src=\(src.lastPathComponent) asset=\(asset)")
        lockVideoProgress = "第一次轉檔…約 20 秒"
        let tmp = fm.temporaryDirectory.appendingPathComponent("lock-\(UUID().uuidString).mov")
        transcodeToHEVC(src, tmp) { ok, err in
            guard ok else {
                say("LOCKVIDEO convert failed \(err ?? "")")
                self.lockVideoProgress = "轉檔失敗"
                return
            }
            try? fm.removeItem(at: cached)
            try? fm.copyItem(at: tmp, to: cached)
            finishInstall(cached)
        }
    }

    /// 等使用者去系統設定下載動態桌布：每 4 秒看一次，最多 3 分鐘
    func pollAerialSlots(_ left: Int = 45) {
        guard cfg.lockVideoOn, left > 0 else { lockVideoWaiting = false; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if self.aerialChoice() != nil {
                self.lockVideoWaiting = false
                say("LOCKVIDEO 槽出現了，自動開始同步")
                self.syncLockVideo()
            } else {
                self.pollAerialSlots(left - 1)
            }
        }
    }

    @objc func openWallpaperSettings() {
        let urls = ["x-apple.systempreferences:com.apple.Wallpaper-Settings.extension",
                    "x-apple.systempreferences:com.apple.Desktop-Settings.extension"]
        for u in urls {
            if let url = URL(string: u), NSWorkspace.shared.open(url) { say("LOCKVIDEO open wallpaper pane"); return }
        }
    }

    func guiSetLockVideo(_ on: Bool) {
        if on { lockVideoInteractive = true }
        cfg.lockVideoOn = on
        saveConfig(cfg)
        lockVideoProgress = on ? "準備中…" : ""
        if on { syncLockVideo() }
    }

    @objc func applyLockVideo() {
        guard cfg.kind == "video" else {
            alert("只有「影片」壁紙能放到鎖定畫面",
                  "macOS 的鎖定畫面只能播影片。先把壁紙換成一支影片再試。")
            return
        }
        let slots = aerialSlots()
        guard !slots.isEmpty else {
            alert("還不能設定：系統裡還沒有任何動態桌布",
                  "鎖定畫面的影片是「取代 Apple 已經下載好的那支」。\n\n請先去 系統設定 → 桌布 → 選一個「動態」桌布（有在動的那種），等它下載完，再回來按一次。\n\n下載位置：~/Library/Application Support/com.apple.wallpaper/aerials/videos/")
            return
        }
        let src = URL(fileURLWithPath: resolveRef(cfg.ref))
        guard fm.fileExists(atPath: src.path) else { alert("找不到目前的影片檔", src.path); return }
        // 大檔優先：使用者選的那支動態桌布通常就是最大的槽
        let target = slots.max { a, b in
            ((try? a.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) <
            ((try? b.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        } ?? slots[0]
        let bak = aerialBackupDir().appendingPathComponent(target.lastPathComponent)
        if !fm.fileExists(atPath: bak.path) {
            do { try fm.copyItem(at: target, to: bak); say("AERIAL backup=\(bak.lastPathComponent)") }
            catch { alert("備份原本的鎖定影片失敗", "\(error)"); return }
        }
        say("AERIAL convert src=\(src.lastPathComponent) → slot=\(target.lastPathComponent)")
        let tmp = fm.temporaryDirectory.appendingPathComponent("lock-\(UUID().uuidString).mov")
        transcodeToHEVC(src, tmp) { ok, err in
            guard ok else {
                say("AERIAL export failed \(err ?? "")")
                self.alert("轉檔失敗", "無法把這支影片轉成 HEVC：\(err ?? "未知錯誤")")
                return
            }
            do {
                _ = try fm.replaceItemAt(target, withItemAt: tmp)
                self.restartWallpaperAgent()
                let mb = ((try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) / 1_048_576
                say("AERIAL applied slot=\(target.lastPathComponent) size=\(mb)MB")
                self.alert("鎖定畫面換好了",
                           "按 Ctrl+Cmd+Q 鎖定看看。\n\n注意：系統設定裡的桌布要保持是「動態（aerial）」，鎖定畫面才會播這支影片。\n想還原：設定 → 播放 → 還原鎖定畫面影片。")
            } catch {
                self.alert("寫入鎖定影片失敗", "\(error)")
            }
        }
    }

    /// 還原 Apple 原本的鎖定畫面影片
    @objc func restoreAerial() {
        let slots = aerialSlots()
        let backups = (try? fm.contentsOfDirectory(at: aerialBackupDir(), includingPropertiesForKeys: nil)) ?? []
        guard !backups.isEmpty else { alert("沒有備份", "這個 App 沒有換過鎖定畫面影片。"); return }
        var n = 0
        for b in backups {
            let dst = aerialDir().appendingPathComponent(b.lastPathComponent)
            do {
                if fm.fileExists(atPath: dst.path) { _ = try fm.replaceItemAt(dst, withItemAt: b) }
                else { try fm.copyItem(at: b, to: dst) }
                n += 1
            } catch { say("AERIAL restore failed \(b.lastPathComponent): \(error)") }
        }
        restartWallpaperAgent()
        say("AERIAL restored n=\(n) slots=\(slots.count)")
        alert("已還原", "已把 \(n) 支 Apple 原始影片放回去。")
    }

    func restartWallpaperAgent() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["WallpaperAgent"]
        try? p.run()
        say("AERIAL wallpaperAgent restarted")
    }

    func alert(_ title: String, _ body: String) {
        if headless { say("ALERT \(title) | \(body.replacingOccurrences(of: "\n", with: " "))"); return }
        let a = NSAlert()
        a.messageText = title
        a.informativeText = body
        a.runModal()
    }

    // MARK: 定時輪換

    func startRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        guard cfg.rotationOn, cfg.rotationMinutes >= 0.02 else { say("ROTATION off"); return }
        let t = Timer(timeInterval: cfg.rotationMinutes * 60, repeats: true) { [weak self] _ in
            self?.rotateNext()
        }
        RunLoop.main.add(t, forMode: .common)
        rotationTimer = t
        say("ROTATION on every=\(cfg.rotationMinutes)min items=\(scanLibrary().count)")
    }

    func rotateNext() {
        let items = scanLibrary()
        guard !items.isEmpty else { return }
        let cur = items.firstIndex { $0.kind == cfg.kind && resolveRef($0.ref) == resolveRef(cfg.ref) } ?? -1
        let next = items[(cur + 1) % items.count]
        say("ROTATION next=\(next.title) kind=\(next.kind)")
        guiApply(kind: next.kind, ref: next.ref)
    }

    func guiSetRotation(_ on: Bool, _ minutes: Double) {
        cfg.rotationOn = on
        cfg.rotationMinutes = minutes
        saveConfig(cfg)
        startRotation()
    }

    // MARK: 全螢幕偵測（有 App 全螢幕就暫停壁紙）

    func isFullscreenAppActive() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != Bundle.main.bundleIdentifier,
              front.bundleIdentifier != "com.apple.finder",
              front.bundleIdentifier != "com.apple.dock" else { return false }
        let pid = front.processIdentifier
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else { return false }
        let target = NSScreen.main?.frame ?? .zero
        for w in list {
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let r = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
            // 真正全螢幕：左上角貼齊 (0,0) 而且整個螢幕都蓋住（含選單列）
            if r.origin.x < 2 && r.origin.y < 2 && abs(r.width - target.width) < 4 && abs(r.height - target.height) < 4 { return true }
        }
        return false
    }

    func checkFullscreenPause() {
        guard cfg.pauseOnFullscreen else {
            if pausedByFullscreen {
                pausedByFullscreen = false
                resumeAllScreens()
            }
            return
        }
        let full = isFullscreenAppActive()
        if full != pausedByFullscreen {
            pausedByFullscreen = full
            say("FULLSCREEN pause=\(full)")
            if full {
                for sw in screens { sw.pauseContent() }
            } else {
                resumeAllScreens()
            }
        }
    }

    /// 恢復播放（但使用者自己按暫停、或系統睡眠中就不要硬開）
    func resumeAllScreens() {
        guard !cfg.paused, !pausedBySystem else { return }
        for sw in screens { sw.resumeContent() }
    }

    func guiSetLockPoster(_ on: Bool) {
        cfg.lockPoster = on
        saveConfig(cfg)
        if on { for sw in screens { sw.schedulePosterRefresh() } }
    }

    func guiSetPauseOnFullscreen(_ on: Bool) {
        cfg.pauseOnFullscreen = on
        saveConfig(cfg)
        if !on { pausedByFullscreen = false; resumeAllScreens() } else { checkFullscreenPause() }
    }

    // MARK: 視差

    func startParallax() {
        parallaxTimer?.invalidate()
        parallaxTimer = nil
        guard cfg.parallaxOn, cfg.parallax > 0.5 else {
            for sw in screens { sw.applyParallax(nil) }
            say("PARALLAX off")
            return
        }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let m = NSEvent.mouseLocation
            for sw in self.screens { sw.applyParallax(m) }
            if Date().timeIntervalSince(self.lastParallaxLog) > 3 {
                self.lastParallaxLog = Date()
                let f = self.screens.first?.screen.frame ?? .zero
                let nx = f.width > 0 ? (m.x - f.midX) / (f.width / 2) : 0
                let ny = f.height > 0 ? (m.y - f.midY) / (f.height / 2) : 0
                let tr = self.screens.first?.root.layer?.transform ?? CATransform3DIdentity
                say(String(format: "PARALLAX dx=%.1f dy=%.1f layer scale=%.3f tx=%.1f ty=%.1f",
                           nx * self.cfg.parallax, ny * self.cfg.parallax, tr.m11, tr.m41, tr.m42))
            }
        }
        RunLoop.main.add(t, forMode: .common)
        parallaxTimer = t
        say("PARALLAX on amount=\(cfg.parallax)")
    }

    func guiSetParallax(_ on: Bool, _ amount: Double) {
        cfg.parallaxOn = on
        cfg.parallax = amount
        saveConfig(cfg)
        for sw in screens { sw.cfg.parallaxOn = on; sw.cfg.parallax = amount }
        startParallax()
    }

    // MARK: 設定視窗

    @objc func showSettingsWindow() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
                             styleMask: [.titled, .closable],
                             backing: .buffered, defer: false)
            w.title = "動態壁紙 設定"
            w.isReleasedWhenClosed = false
            // 一定要能跟著使用者跑到目前這個 Space，不然會「看起來沒開」
            w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            w.level = .floating   // 測試：浮動層級能不能壓過壁紙庫
            w.hidesOnDeactivate = false
            w.isMovableByWindowBackground = false
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            settingsWindow = w
            say("SETTINGS-OPEN")
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // 壁紙庫開著就用 sheet 貼在它上面：sheet 一定跟著壁紙庫出現在同一個 Space，
        // 不會像獨立視窗那樣被壓在後面（使用者會覺得「按了沒反應」）
        if let lib = libraryWindow, lib.isVisible, let w = settingsWindow, w.sheetParent == nil {
            lib.beginSheet(w)
            say("SETTINGS-SHEET")
            return
        }
        settingsWindow?.orderFrontRegardless()
        settingsWindow?.makeKey()
        if let w = settingsWindow {
            say("SETTINGS-FRONT visible=\(w.isVisible) key=\(w.isKeyWindow) occl=\(w.occlusionState.contains(.visible))")
        }
        // 再補一次：啟動 App／Dock 點擊可能觸發 reopen，把壁紙庫又抬上來
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let w = self?.settingsWindow else { return }
            w.orderFrontRegardless()
            w.makeKey()
            say("SETTINGS-FRONT2 occl=\(w.occlusionState.contains(.visible))")
        }
    }

    @objc func showSettingsAction() { showSettingsWindow() }

    @objc func showLibraryAction() { showLibraryWindow() }

    /// 選單列「顯示使用導覽…」：開壁紙庫並重播導覽
    @objc func showTourAction() {
        showLibraryWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { TourState.shared.replay() }
    }

    /// 自動測試：逐步走完導覽，並回報每個錨點有沒有抓到、在不在視窗內
    func runTourTest() {
        let t = TourState.shared
        var i = 0
        func size() -> CGSize { libraryWindow?.contentView?.bounds.size ?? .zero }
        func tick() {
            guard i < t.steps.count else {
                let s = size()
                let all = t.rects.map { "\($0.key)=\(Int($0.value.minX)),\(Int($0.value.minY)),\(Int($0.value.width))x\(Int($0.value.height))" }.sorted().joined(separator: " ")
                say("TOURTEST done steps=\(t.steps.count) active=\(t.active) window=\(Int(s.width))x\(Int(s.height)) rects=[\(all)]")
                return
            }
            say("TOURTEST step=\(i + 1) \(t.anchorReport(size())) active=\(t.active)")
            t.next()
            i += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { tick() }
        }
        say("TOURTEST start")
        showLibraryWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            t.replay()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { tick() }
        }
    }
}

// MARK: ───────────────────────── 壁紙項目 / 掃描 / 縮圖 / 引擎橋樑（實作在 gui.swift）

// MARK: ───────────────────────── 進入點

if let bid = Bundle.main.bundleIdentifier {
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
        .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if !others.isEmpty {
        say("ALREADY-RUNNING pid=\(others[0].processIdentifier)")
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name((Bundle.main.bundleIdentifier ?? "com.dynwall.app") + ".showLibrary"),
            object: nil, userInfo: nil, deliverImmediately: true)
        Thread.sleep(forTimeInterval: 0.4)
        exit(0)
    }
}

ensureDirs()

// 命令列支援：DynWall --set builtin starfield / --autostart on|off
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--set"), i + 2 < args.count {
    var c = loadConfig()
    c.kind = args[i + 1]
    c.ref = args[i + 2]
    c.paused = false
    saveConfig(c)
    say("CLI-SET \(c.kind) \(c.ref)")
}
let cliAutoStart = args.firstIndex(of: "--autostart").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
