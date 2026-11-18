import SwiftUI

// MARK: ───────────────────────── 使用導覽（GuideKit 式）
//
// 做法跟 WaifuX 的 GuideKit 一樣的精神，但簡化成適合我們的規模：
//   · 每一步綁一個「錨點」，用 PreferenceKey 取得該元件在視窗內的實際位置
//   · 遮罩挖洞 + 高亮外框 + 說明卡，卡片自動避開錨點（錨點在下半部就放上面）
//   · 看過就記版本（UserDefaults），改版號可以讓老使用者再看一次
//   · 選單列「顯示使用導覽…」或壁紙庫右上角 ? 可隨時重播

struct TourStep {
    let anchor: String?          // nil = 置中卡片（例如選單列這種視窗外的東西）
    let title: String
    let body: String
}

final class TourState: ObservableObject {
    static let shared = TourState()
    static let version = 1
    private let seenKey = "tourSeenVersion"

    @Published var active = false
    @Published var step = 0
    @Published var rects: [String: CGRect] = [:]

    let steps: [TourStep] = [
        TourStep(anchor: "grid",
                 title: "這裡是你的壁紙庫",
                 body: "所有壁紙都在這一格一格的縮圖裡：內建的、你自己加的影片、圖片、GIF、HTML 都在一起。上面可以切換類型、搜尋名稱，按 ↻ 重新整理。滑鼠移上去就能看動態預覽。"),
        TourStep(anchor: "add",
                 title: "加入你自己的壁紙",
                 body: "按「加入壁紙」選檔案，或直接把檔案拖進這個視窗。支援 MP4 / MOV、PNG / JPG / HEIC、GIF，以及整個 HTML 資料夾。放進來的檔案會複製一份到 App 自己的資料夾，所以之後把原檔刪掉也不會壞。"),
        TourStep(anchor: "inspector",
                 title: "右邊是預覽和這張壁紙的設定",
                 body: "點縮圖，右邊就會即時播放這一張。下面的選項是全域的：暫停、靜音、允許滑鼠互動、開機自動啟動，以及「關掉 App 後桌面保留同一張」。"),
        TourStep(anchor: "apply",
                 title: "按這裡換掉桌面",
                 body: "按「套用到桌面」就立刻換。被套用的那一張會標上「使用中」。想調速度、暗化、填滿方式，就在下面的滑桿調整，改動是即時的。"),
        TourStep(anchor: nil,
                 title: "平常從選單列回來",
                 body: "App 平时躲在選單列（🖼 圖示）。這台 Mac 的選單列是自動隱藏的 —— 把滑鼠移到螢幕最上面，圖示才會出現，點它就能開壁紙庫（⌘L）、暫停或退出。看完按「開始使用」就可以關掉這個導覽。")
    ]

    var current: TourStep { steps[min(step, steps.count - 1)] }
    var isLast: Bool { step >= steps.count - 1 }

    func startIfNeeded() {
        guard UserDefaults.standard.integer(forKey: seenKey) < Self.version else { return }
        start()
    }

    func start() {
        step = 0
        active = true
        say("TOUR start version=\(Self.version) steps=\(steps.count)")
    }

    func next() {
        guard active else { return }
        if isLast { finish(); return }
        step += 1
        say("TOUR step=\(step + 1)/\(steps.count) anchor=\(current.anchor ?? "-")")
    }

    func prev() {
        guard active, step > 0 else { return }
        step -= 1
        say("TOUR step=\(step + 1)/\(steps.count) anchor=\(current.anchor ?? "-")")
    }

    func finish() {
        active = false
        UserDefaults.standard.set(Self.version, forKey: seenKey)
        say("TOUR finish seen=\(Self.version)")
    }

    /// 重播：把「看過」清掉再開
    func replay() {
        UserDefaults.standard.set(0, forKey: seenKey)
        start()
    }

    /// 給自動測試用：目前這一步的錨點有沒有抓到、在不在視窗內
    func anchorReport(_ windowSize: CGSize) -> String {
        guard let a = current.anchor else { return "anchor=center" }
        guard let r = rects[a] else { return "anchor=\(a) rect=nil" }
        let inside = r.minX >= -1 && r.minY >= -1 && r.maxX <= windowSize.width + 1 && r.maxY <= windowSize.height + 1
        return "anchor=\(a) rect=\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width))x\(Int(r.height)) inside=\(inside)"
    }
}

// MARK: 錨點回報

struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// 標記一個導覽錨點（座標系是壁紙庫視窗）
    func tourAnchor(_ id: String) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: TourAnchorKey.self,
                                   value: [id: g.frame(in: .named("dynwall-window"))])
        })
    }
}

// MARK: 導覽畫面

struct TourOverlay: View {
    @ObservedObject var tour: TourState

    var body: some View {
        GeometryReader { geo in
            let step = tour.current
            let r = step.anchor.flatMap { tour.rects[$0] }
            ZStack(alignment: .topLeading) {
                // 半透明遮罩，錨點處挖一個洞
                Color.black.opacity(0.62)
                    .overlay(alignment: .topLeading) {
                        if let r = r {
                            RoundedRectangle(cornerRadius: 14)
                                .frame(width: r.width + 16, height: r.height + 16)
                                .offset(x: r.minX - 8, y: r.minY - 8)
                                .blendMode(.destinationOut)
                        }
                    }
                    .compositingGroup()

                // 高亮外框
                if let r = r {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor, lineWidth: 2.5)
                        .frame(width: r.width + 16, height: r.height + 16)
                        .offset(x: r.minX - 8, y: r.minY - 8)
                        .allowsHitTesting(false)
                        .shadow(color: Color.accentColor.opacity(0.5), radius: 12)
                }

                card(step: step, geo: geo, anchor: r)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    private func card(step: TourStep, geo: GeometryProxy, anchor: CGRect?) -> some View {
        let w: CGFloat = 400
        // 錨點在下半部 → 卡片放上面；否則放下面，避免擋住正在講的東西
        let anchorLow = (anchor?.midY ?? geo.size.height / 2) > geo.size.height * 0.55
        let y: CGFloat = anchorLow ? 28 : max(28, geo.size.height - 210)
        let x: CGFloat = min(max(16, (anchor?.midX ?? geo.size.width / 2) - w / 2), geo.size.width - w - 16)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("第 \(tour.step + 1) / \(tour.steps.count) 步")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button("略過") { tour.finish() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Text(step.title).font(.system(size: 17, weight: .bold))
            Text(step.body)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            HStack(spacing: 8) {
                if tour.step > 0 {
                    Button("上一步") { tour.prev() }
                }
                Spacer()
                Button(tour.isLast ? "開始使用" : "下一步") { tour.next() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: w, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.35), radius: 22, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.12)))
        .offset(x: x, y: y)
    }
}
