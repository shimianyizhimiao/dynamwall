import Foundation

/// 使用者自己取的「名字 / 標籤」，存在 meta.json，不強制填。
struct ItemMeta: Codable {
    var title: String?
    var tags: [String]?
}

enum MetaStore {
    static var url: URL { SUPPORT_DIR.appendingPathComponent("meta.json") }
    private(set) static var cache: [String: ItemMeta] = load()

    static func load() -> [String: ItemMeta] {
        guard let d = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode([String: ItemMeta].self, from: d) else { return [:] }
        return m
    }

    static func meta(_ id: String) -> ItemMeta? { cache[id] }

    static func set(_ id: String, title: String?, tags: [String]?) {
        var m = cache[id] ?? ItemMeta(title: nil, tags: nil)
        m.title = (title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? title : nil
        let clean = (tags ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        m.tags = clean.isEmpty ? nil : clean
        if m.title == nil && m.tags == nil { cache.removeValue(forKey: id) } else { cache[id] = m }
        save()
        say("META set id=\(id) title=\(m.title ?? "-") tags=\(m.tags?.joined(separator: ",") ?? "-")")
    }

    static func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let d = try? enc.encode(cache) { try? d.write(to: url) }
    }
}
