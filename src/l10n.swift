import Foundation

// MARK: - 語言清單

enum AppLang: String, CaseIterable, Identifiable {
    case zhHant = "zh-Hant"
    case zhHans = "zh-Hans"
    case en = "en"
    case ja = "ja", ko = "ko", es = "es", fr = "fr", de = "de", it = "it"
    case ptBR = "pt-BR", ru = "ru", uk = "uk", pl = "pl", nl = "nl"
    case tr = "tr", vi = "vi", th = "th", id = "id", ms = "ms"
    case ar = "ar", hi = "hi", he = "he", sv = "sv", da = "da"
    case nb = "nb", fi = "fi", cs = "cs", el = "el"

    var id: String { rawValue }

    /// 用該語言自己的寫法顯示
    var label: String {
        switch self {
        case .zhHant: return "繁體中文"
        case .zhHans: return "简体中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .ptBR: return "Português (Brasil)"
        case .ru: return "Русский"
        case .uk: return "Українська"
        case .pl: return "Polski"
        case .nl: return "Nederlands"
        case .tr: return "Türkçe"
        case .vi: return "Tiếng Việt"
        case .th: return "ไทย"
        case .id: return "Bahasa Indonesia"
        case .ms: return "Bahasa Melayu"
        case .ar: return "العربية"
        case .hi: return "हिन्दी"
        case .he: return "עברית"
        case .sv: return "Svenska"
        case .da: return "Dansk"
        case .nb: return "Norsk bokmål"
        case .fi: return "Suomi"
        case .cs: return "Čeština"
        case .el: return "Ελληνικά"
        }
    }

    /// 第一次啟動依系統語言自動選一個
    static func detect() -> AppLang {
        for pref in Locale.preferredLanguages {
            let lower = pref.lowercased()
            if lower.hasPrefix("zh-hant") || lower.hasPrefix("zh-tw") || lower.hasPrefix("zh-hk") { return .zhHant }
            if lower.hasPrefix("zh") { return .zhHans }
            for lang in AppLang.allCases where lang != .zhHant && lang != .zhHans {
                if lower.hasPrefix(lang.rawValue.lowercased()) { return lang }
            }
        }
        return .en
    }
}

// MARK: - 翻譯

enum L10n {
    static var current: AppLang = .zhHant
    private static var cache: [String: [String: String]] = [:]

    /// 繁體中文是原文；其他語言查 resources/lang/<code>.json，缺的往英文、再往原文退
    static func t(_ zh: String) -> String {
        guard current != .zhHant else { return zh }
        if let hit = table(current)[zh], !hit.isEmpty { return hit }
        if current != .en, let en = table(.en)[zh], !en.isEmpty { return en }
        return zh
    }

    static func table(_ lang: AppLang) -> [String: String] {
        if let c = cache[lang.rawValue] { return c }
        let url = Bundle.main.url(forResource: lang.rawValue, withExtension: "json", subdirectory: "lang")
            ?? Bundle.main.url(forResource: lang.rawValue, withExtension: "json")
        guard let url,
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            cache[lang.rawValue] = [:]
            return [:]
        }
        cache[lang.rawValue] = dict
        return dict
    }

    /// 這個語言收錄了幾條（設定頁顯示用）
    static func coverage(_ lang: AppLang) -> Int {
        lang == .zhHant ? 999 : table(lang).count
    }
}

/// 短版呼叫
func T(_ zh: String) -> String { L10n.t(zh) }
