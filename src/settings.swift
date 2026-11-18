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
            general.tabItem { Label("一般", systemImage: "gearshape") }
            playback.tabItem { Label("播放", systemImage: "play.rectangle") }
            advanced.tabItem { Label("進階", systemImage: "wrench.and.screwdriver") }
            about.tabItem { Label("關於", systemImage: "info.circle") }
        }
        .frame(width: 620, height: 470)
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("完成") { closeSelf() }
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
                toggleRow("登入時自動啟動", "開機後在背景直接開始播壁紙，不開視窗。",
                          bind(\.autoStart, { Engine.shared.setAutoStart($0) }))
                toggleRow("關掉 App 後保留桌面", "結束 App 時把當下畫面存成靜態圖設為桌布，桌面不會變回原本的壁紙。",
                          bind(\.poster, { Engine.shared.setPoster($0) }))
            } header: { Text("啟動") }

            Section {
                Picker("預設畫面縮放", selection: bindString(\.gravity, { Engine.shared.setGravity($0) })) {
                    Text("填滿畫面（裁切邊緣）").tag("fill")
                    Text("完整顯示（可能留黑邊）").tag("fit")
                    Text("延展變形").tag("stretch")
                }
                Text("「填滿」適合影片與照片；「完整顯示」適合有文字或介面的自訂 HTML。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text("畫面") }

            Section {
                Button("重播使用導覽") { TourState.shared.replay() }
                Text("導覽只會自動出現一次；之後想看就從這裡重播。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text("導覽") }
        }
        .formStyle(.grouped)
    }

    // MARK: 播放

    private var playback: some View {
        Form {
            Section {
                toggleRow("播放中", "關掉就暫停壁紙（影片停在當下這一格）。",
                          Binding(get: { !cfg.paused }, set: { Engine.shared.setPaused(!$0); reload() }))
                toggleRow("靜音", "影片壁紙的聲音；預設靜音。",
                          bind(\.mute, { Engine.shared.setMute($0) }))
                toggleRow("允許滑鼠互動", "只有自訂 HTML 壁紙有作用：滑鼠點擊、滾動會傳給網頁。",
                          bind(\.interactive, { Engine.shared.setInteractive($0) }))
            } header: { Text("播放") }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("播放速度：\(String(format: "%.2fx", cfg.rate))")
                        .font(.system(size: 12))
                    Slider(value: Binding(get: { cfg.rate }, set: { cfg.rate = $0; Engine.shared.setRate($0); reload() }),
                           in: 0.25...2.0, step: 0.25)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("暗化：\(Int(cfg.dim * 100))%（讓桌面圖示更清楚）")
                        .font(.system(size: 12))
                    Slider(value: Binding(get: { cfg.dim }, set: { cfg.dim = $0; Engine.shared.setDim($0); reload() }),
                           in: 0...0.7, step: 0.1)
                }
            } header: { Text("調整") }

            Section {
                toggleRow("視差（景深）", "滑鼠移動時，壁紙往同方向微微位移，看起來有前後層次。預設關閉。",
                          Binding(get: { cfg.parallaxOn },
                                  set: { cfg.parallaxOn = $0; Engine.shared.setParallax($0, cfg.parallax); reload() }))
                VStack(alignment: .leading, spacing: 6) {
                    Text("位移幅度：\(Int(cfg.parallax)) px")
                        .font(.system(size: 12))
                    Slider(value: Binding(
                        get: { cfg.parallax },
                        set: { cfg.parallax = $0; Engine.shared.setParallax(cfg.parallaxOn, $0); reload() }),
                           in: 0...30, step: 1)
                }
                .disabled(!cfg.parallaxOn)
                Text("壁紙會先放大一點，所以位移時不會露出黑邊；影片、圖片、HTML 都適用。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text("視差（景深）") }
        }
        .formStyle(.grouped)
    }

    // MARK: 進階

    private var advanced: some View {
        Form {
            Section {
                HStack {
                    Button("開啟壁紙資料夾") {
                        try? fm.createDirectory(at: LIBRARY_DIR, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(LIBRARY_DIR)
                    }
                    Spacer()
                    Text("\(LIBRARY_DIR.path)")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.head)
                }
            } header: { Text("壁紙庫") }

            Section {
                HStack {
                    Text("縮圖與海報快取：\(String(format: "%.0f MB", cacheMB))")
                    Spacer()
                    Button("清除快取") {
                        clearCache()
                        cacheMB = Self.cacheSizeMB()
                    }
                }
                Text("清掉不會影響壁紙本身，下次開啟會重新產生縮圖。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text("快取") }

            Section {
                HStack {
                    Button(copied ? "已複製 ✓" : "複製診斷資訊") { copyDiagnostics() }
                    Button("開啟日誌資料夾") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: LOG_PATH)])
                    }
                }
                Text("回報問題時把診斷資訊貼給我，比猜快很多。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } header: { Text("診斷") }
        }
        .formStyle(.grouped)
    }

    // MARK: 關於

    private var about: some View {
        VStack(spacing: 10) {
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon).resizable().frame(width: 84, height: 84)
            }
            Text("動態壁紙 DynWall").font(.system(size: 18, weight: .bold))
            Text("版本 \(version) ・ macOS 原生・影片／圖片／GIF／自訂 HTML")
                .font(.system(size: 11)).foregroundColor(.secondary)

            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                row("作者", "shimianyizhimiao")
                row("授權", "PolyForm Noncommercial 1.0.0 + Share-Alike")
                row("原始碼", "github.com/shimianyizhimiao/dynwall")
                row("系統需求", "macOS 13 以上・Apple Silicon 與 Intel")
            }
            .frame(width: 460, alignment: .leading)

            Text("個人專案，可能還有一些 BUG；若你是從付費管道拿到，那不是作者發布的版本。")
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
