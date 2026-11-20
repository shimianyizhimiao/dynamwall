import SwiftUI
import AppKit

/// 自己畫的開關：系統的 NSSwitch 在這個視窗偶爾會把白色圓點畫丟，改用純 SwiftUI 繪製
struct PillSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 12) {
            configuration.label
            Spacer(minLength: 8)
            Capsule()
                .fill(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.22))
                .frame(width: 42, height: 24)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .padding(2)
                        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                }
                .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
                .contentShape(Capsule())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.14)) { configuration.isOn.toggle() }
                }
        }
    }
}

// MARK: ───────────────────────── 設定視窗（分頁）
//
// 照 WaifuX 的做法：設定不要塞在側邊面板，開一個獨立視窗、分成幾頁。
// 側邊面板只留「這張壁紙」的即時調整，這裡放全域的。

struct SettingsView: View {
    @State private var cfg = Engine.shared.config
    @State private var cacheMB: Double = 0
    @State private var copied = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        TabView {
            general.tabItem { Label(T("一般"), systemImage: "gearshape") }
            playback.tabItem { Label(T("播放"), systemImage: "play.rectangle") }
            advanced.tabItem { Label(T("進階"), systemImage: "wrench.and.screwdriver") }
            about.tabItem { Label(T("關於"), systemImage: "info.circle") }
        }
        .frame(width: 620, height: 470)
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button(T("完成")) { closeSelf() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .onAppear { reload(); cacheMB = Self.cacheSizeMB() }
    }

    /// 每個開關都給標題＋一行說明，避免只看到兩顆「不知道是什麼」的膠囊
    private func toggleRow(_ title: String, _ desc: String, _ isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(PillSwitchStyle())
                .fixedSize()
        }
    }

    private func reload() { cfg = Engine.shared.config }

    /// sheet 或獨立視窗都能關：有 sheet 父視窗就 endSheet，否則直接關
    private func closeSelf() {
        guard let w = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.title.contains("設定") }) else { return }
        if let parent = w.sheetParent {
            parent.endSheet(w)
        } else {
            w.close()
        }
    }

    // MARK: 一般

    private var general: some View {
        Form {
            Section {
                Picker(T("語言"), selection: Binding(
                    get: { cfg.lang },
                    set: { v in
                        var c = Engine.shared.config
                        c.lang = v
                        c.langChosen = true
                        saveConfig(c)
                        L10n.current = AppLang(rawValue: v) ?? .zhHant
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { relaunch() }
                    }
                )) {
                    ForEach(AppLang.allCases) { l in
                        Text(l.label).tag(l.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text(T("換語言後會自動重開 App（壁紙會繼續播放）。"))
                    .font(.system(size: 10.5)).foregroundColor(.secondary)
            } header: { Text(T("語言 Language")) }

            Section {
                toggleRow(T("登入時自動啟動"), T("開機後在背景直接開始播壁紙，不開視窗。"),
                          bind(\.autoStart, { Engine.shared.setAutoStart($0) }))
                toggleRow(T("關掉 App 後保留桌面"), T("結束 App 時把當下畫面留在桌面。關掉的話，結束時會還原你原本的桌布。"),
                          bind(\.poster, { Engine.shared.setPoster($0) }))
                toggleRow(T("鎖定畫面顯示當下畫面"), T("打密碼那個畫面系統只認「桌布圖」，所以一定要有一張靜態圖；關掉就會看到你原本的桌布。"),
                          bind(\.lockPoster, { Engine.shared.setLockPoster($0) }))
            } header: { Text(T("啟動")) }

            Section {
                Picker(T("預設畫面縮放"), selection: bindString(\.gravity, { Engine.shared.setGravity($0) })) {
                    Text(T("填滿畫面（裁切邊緣）")).tag("fill")
                    Text(T("完整顯示（可能留黑邊）")).tag("fit")
                    Text(T("延展變形")).tag("stretch")
                }
                Text(T("「填滿」適合影片與照片；「完整顯示」適合有文字或介面的自訂 HTML。"))
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text(T("畫面")) }

            Section {
                Button(T("重播使用導覽")) { TourState.shared.replay() }
                Text(T("導覽只會自動出現一次；之後想看就從這裡重播。"))
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text(T("導覽")) }
        }
        .formStyle(.grouped)
    }

    // MARK: 播放

    private var playback: some View {
        Form {
            Section {
                toggleRow(T("播放中"), T("關掉就暫停壁紙（影片停在當下這一格）。"),
                          Binding(get: { !cfg.paused }, set: { Engine.shared.setPaused(!$0); reload() }))
                toggleRow(T("靜音"), T("影片壁紙的聲音；預設靜音。"),
                          bind(\.mute, { Engine.shared.setMute($0) }))
                toggleRow(T("允許滑鼠互動"), T("只有自訂 HTML 壁紙有作用：滑鼠點擊、滾動會傳給網頁。"),
                          bind(\.interactive, { Engine.shared.setInteractive($0) }))
            } header: { Text(T("播放")) }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(T("播放速度"))：\(String(format: "%.2fx", cfg.rate))")
                        .font(.system(size: 12))
                    Slider(value: Binding(get: { cfg.rate }, set: { cfg.rate = $0; Engine.shared.setRate($0); reload() }),
                           in: 0.25...2.0, step: 0.25)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(T("暗化"))：\(Int(cfg.dim * 100))%")
                        .font(.system(size: 12))
                    Slider(value: Binding(get: { cfg.dim }, set: { cfg.dim = $0; Engine.shared.setDim($0); reload() }),
                           in: 0...0.7, step: 0.1)
                }
            } header: { Text(T("調整")) }

            Section {
                toggleRow(T("視差（景深）"), T("滑鼠移動時，壁紙往同方向微微位移，看起來有前後層次。預設關閉。"),
                          Binding(get: { cfg.parallaxOn },
                                  set: { cfg.parallaxOn = $0; Engine.shared.setParallax($0, cfg.parallax); reload() }))
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(T("位移幅度"))：\(Int(cfg.parallax)) px")
                        .font(.system(size: 12))
                    Slider(value: Binding(
                        get: { cfg.parallax },
                        set: { cfg.parallax = $0; Engine.shared.setParallax(cfg.parallaxOn, $0); reload() }),
                           in: 0...30, step: 1)
                }
                .disabled(!cfg.parallaxOn)
                Text(T("壁紙會先放大一點，所以位移時不會露出黑邊；影片、圖片、HTML 都適用。"))
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text(T("視差（景深）")) }

            Section {
                toggleRow(T("定時自動換壁紙"), T("時間到就換成壁紙庫裡的下一張，一直循環。"),
                          Binding(get: { cfg.rotationOn },
                                  set: { cfg.rotationOn = $0; Engine.shared.setRotation($0, cfg.rotationMinutes); reload() }))
                Picker(T("間隔"), selection: Binding(
                    get: { Int(cfg.rotationMinutes) },
                    set: { cfg.rotationMinutes = Double($0); Engine.shared.setRotation(cfg.rotationOn, cfg.rotationMinutes); reload() })) {
                    Text(T("5 分鐘")).tag(5)
                    Text(T("15 分鐘")).tag(15)
                    Text(T("30 分鐘")).tag(30)
                    Text(T("1 小時")).tag(60)
                    Text(T("3 小時")).tag(180)
                }
                .disabled(!cfg.rotationOn)
                toggleRow(T("全螢幕時暫停"), T("看影片、玩遊戲開全螢幕時把壁紙停住，省電也省顯卡。"),
                          Binding(get: { cfg.pauseOnFullscreen },
                                  set: { cfg.pauseOnFullscreen = $0; Engine.shared.setPauseOnFullscreen($0); reload() }))
            } header: { Text(T("自動化（省電）")) }

            Section {
                Text(T("macOS 的鎖定畫面由系統進程繪製，第三方 App 改不到 —— 我們試過直接寫系統桌布資料庫（Index.plist）與冒充 Apple 的動態桌布，系統會在幾秒內改回它記憶體裡的設定，所以這個功能拿掉了，不再留半套。"))
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(T("要讓鎖定畫面跟桌面一樣，只能在「系統設定 → 桌布」那裡設定（可選同一張給桌面與鎖定畫面）。下方的桌布海報功能仍然有效：桌面上會是壁紙的當下畫面。"))
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button(T("打開桌布設定")) {
                        NSApp.sendAction(#selector(AppDelegate.openWallpaperSettings), to: nil, from: nil)
                    }
                    Button(T("還原系統桌布設定")) {
                        NSApp.sendAction(#selector(AppDelegate.restoreWallpaperStore), to: nil, from: nil)
                    }
                }
                .font(.system(size: 11))
            } header: { Text(T("鎖定畫面（系統限制）")) }
        }
        .formStyle(.grouped)
    }

    // MARK: 進階

    private var advanced: some View {
        Form {
            Section {
                HStack {
                    Button(T("開啟壁紙資料夾")) {
                        try? fm.createDirectory(at: LIBRARY_DIR, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(LIBRARY_DIR)
                    }
                    Spacer()
                    Text("\(LIBRARY_DIR.path)")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.head)
                }
            } header: { Text(T("壁紙庫")) }

            Section {
                HStack {
                    Text("\(T("縮圖與海報快取"))：\(String(format: "%.0f MB", cacheMB))")
                    Spacer()
                    Button(T("清除快取")) {
                        clearCache()
                        cacheMB = Self.cacheSizeMB()
                    }
                }
                Text(T("清掉不會影響壁紙本身，下次開啟會重新產生縮圖。"))
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text(T("快取")) }

            Section {
                HStack {
                    Button(copied ? "已複製 ✓" : "複製診斷資訊") { copyDiagnostics() }
                    Button(T("開啟日誌資料夾")) {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: LOG_PATH)])
                    }
                }
                Text(T("回報問題時把診斷資訊貼給我，比猜快很多。"))
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text(T("診斷")) }
        }
        .formStyle(.grouped)
    }

    // MARK: 關於

    private var about: some View {
        VStack(spacing: 10) {
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon).resizable().frame(width: 84, height: 84)
            }
            Text(T("動態壁紙 DynWall")).font(.system(size: 18, weight: .bold))
            Text("\(T("版本")) \(version) · \(T("影片／圖片／GIF／自訂 HTML"))")
                .font(.system(size: 11)).foregroundColor(.secondary)

            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                row("作者", "shimianyizhimiao")
                row("授權", "PolyForm Noncommercial 1.0.0 + Share-Alike")
                row("原始碼", "github.com/shimianyizhimiao/dynwall")
                row("系統需求", "macOS 13 以上・Apple Silicon 與 Intel")
            }
            .frame(width: 460, alignment: .leading)

            Text(T("個人專案，可能還有一些 BUG；若你是從付費管道拿到，那不是作者發布的版本。"))
                .font(.system(size: 10)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 460)
                .padding(.top, 4)

            Spacer()
        }
        .padding(22)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(.system(size: 11, weight: .semibold)).frame(width: 60, alignment: .leading)
            Text(v).font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: 小工具

    private func bind(_ key: WritableKeyPath<Config, Bool>, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { cfg[keyPath: key] }, set: { cfg[keyPath: key] = $0; set($0); reload() })
    }

    private func bindString(_ key: WritableKeyPath<Config, String>, _ set: @escaping (String) -> Void) -> Binding<String> {
        Binding(get: { cfg[keyPath: key] }, set: { cfg[keyPath: key] = $0; set($0); reload() })
    }

    static func cacheSizeMB() -> Double {
        let dirs = [CACHE_DIR.appendingPathComponent("thumbs"), CACHE_DIR.appendingPathComponent("posters")]
        var total = 0
        for d in dirs {
            guard let en = fm.enumerator(at: d, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            for case let u as URL in en {
                total += (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            }
        }
        return Double(total) / 1_048_576
    }

    private func clearCache() {
        for d in [CACHE_DIR.appendingPathComponent("thumbs"), CACHE_DIR.appendingPathComponent("posters")] {
            try? fm.removeItem(at: d)
            try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
        say("CACHE 已清除縮圖與海報")
    }

    private func copyDiagnostics() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(diagnostics(), forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
    }

    private func diagnostics() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let screen = NSScreen.main.map { "\(Int($0.frame.width))x\(Int($0.frame.height)) @\(Int($0.backingScaleFactor))x" } ?? "?"
        let cfgJSON = (try? String(contentsOf: CONFIG_URL, encoding: .utf8)) ?? "(讀不到)"
        let log = (try? String(contentsOfFile: LOG_PATH, encoding: .utf8))?.split(separator: "\n").suffix(80).joined(separator: "\n") ?? ""
        return """
        DynWall \(version) / macOS \(os) / 螢幕 \(screen)
        --- config.json ---
        \(cfgJSON)
        --- 最近的日誌 ---
        \(log)
        """
    }
}
