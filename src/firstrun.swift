import SwiftUI
import AppKit

/// 第一次啟動：先問語言（使用者要求「下了軟件先讓他換語言」）
struct FirstRunView: View {
    let onPick: (AppLang) -> Void
    @State private var hovered: AppLang?

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("DynWall")
                    .font(.system(size: 30, weight: .bold))
                Text("選擇語言 · Choose your language")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 6)

            VStack(spacing: 10) {
                ForEach(AppLang.allCases) { lang in
                    Button {
                        onPick(lang)
                    } label: {
                        HStack {
                            Text(lang.label).font(.system(size: 15, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(hovered == lang ? 0.12 : 0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(hovered == lang ? 0.30 : 0.10))
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovered = $0 ? lang : nil }
                }
            }

            Text("之後可以在「設定 → 一般」更改 · You can change this later in Settings")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 380)
    }
}

enum FirstRun {
    private static var window: NSWindow?

    static func show(onPick: @escaping (AppLang) -> Void) {
        guard window == nil else { window?.makeKeyAndOrderFront(nil); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 340),
                         styleMask: [.titled, .closable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = "DynWall"
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.level = .floating
        w.contentView = NSHostingView(rootView: FirstRunView { lang in
            onPick(lang)
            window?.close()
            window = nil
        })
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
