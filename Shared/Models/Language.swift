import Foundation

enum Language: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func detectDeviceLanguage() -> Language {
        if let preferred = Locale.preferredLanguages.first {
            if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") {
                return .traditionalChinese
            }
            if preferred.hasPrefix("zh") {
                return .simplifiedChinese
            }
            if preferred.hasPrefix("ja") {
                return .japanese
            }
            if preferred.hasPrefix("ko") {
                return .korean
            }
        }
        return .english
    }
}
