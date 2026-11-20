import Foundation

/// 檢查 GitHub Release 是否有新版本。
/// 只有「檢查更新」與「下載」需要網路；播壁紙本身完全離線。
final class Updater {
    static let shared = Updater()

    static let repo = "shimianyizhimiao/macos-live-wallpaper"
    static let latestAPI = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
    static let downloadPage = URL(string: "https://github.com/\(repo)/releases/latest")!

    struct Release {
        let version: String      // 0.9.11
        let name: String
        let notes: String
        let pageURL: URL
        let dmgURL: URL?
        let published: String
    }

    var latest: Release?
    var lastError: String?
    private var inFlight = false

    /// 目前 App 的版本（Info.plist，build.sh 由 VERSION 寫入）
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// a > b ?
    static func newer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0
            let r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    var hasUpdate: Bool {
        guard let l = latest else { return false }
        return Self.newer(l.version, than: Self.currentVersion)
    }

    func check(_ done: ((Release?) -> Void)? = nil) {
        if inFlight { return }
        inFlight = true
        var req = URLRequest(url: Self.latestAPI)
        req.timeoutInterval = 12
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("DynWall/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { data, resp, err in
            defer { self.inFlight = false }
            func finish(_ r: Release?) {
                DispatchQueue.main.async {
                    self.latest = r
                    if let r = r { say("UPDATE latest=\(r.version) current=\(Self.currentVersion) newer=\(self.hasUpdate)") }
                    else { say("UPDATE check failed \(self.lastError ?? "?")") }
                    done?(r)
                }
            }
            if let err = err { self.lastError = err.localizedDescription; finish(nil); return }
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200, let data = data else {
                self.lastError = "HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)"
                finish(nil); return
            }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.lastError = "JSON 解析失敗"; finish(nil); return
            }
            let tag = (obj["tag_name"] as? String ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let assets = obj["assets"] as? [[String: Any]] ?? []
            let dmg = assets.first { ($0["name"] as? String)?.lowercased().hasSuffix(".dmg") == true }
            finish(Release(
                version: tag,
                name: obj["name"] as? String ?? tag,
                notes: obj["body"] as? String ?? "",
                pageURL: URL(string: obj["html_url"] as? String ?? Self.downloadPage.absoluteString) ?? Self.downloadPage,
                dmgURL: (dmg?["browser_download_url"] as? String).flatMap(URL.init(string:)),
                published: obj["published_at"] as? String ?? ""
            ))
        }.resume()
    }
}
