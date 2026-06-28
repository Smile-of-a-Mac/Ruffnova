import Foundation

enum Language: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func detectDeviceLanguage() -> Language {
        let code = Locale.current.language.languageCode?.identifier ?? ""
        if code.hasPrefix("zh") {
            return .simplifiedChinese
        }
        return .english
    }
}
