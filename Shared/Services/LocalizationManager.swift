import Foundation

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var selectedLanguage: Language {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "appLanguage")
            reload()
        }
    }

    private var translations: [String: String] = [:]
    private var fallbackTranslations: [String: String] = [:]

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = Language(rawValue: saved) {
            selectedLanguage = lang
        } else {
            selectedLanguage = Language.detectDeviceLanguage()
        }
        load(language: selectedLanguage, into: &translations)
        load(language: .english, into: &fallbackTranslations)
    }

    func localized(_ key: String) -> String {
        if let value = translations[key], !value.isEmpty {
            return value
        }
        if let value = fallbackTranslations[key], !value.isEmpty {
            return value
        }
        return key
    }

    func setLanguage(_ language: Language) {
        selectedLanguage = language
    }

    private func reload() {
        load(language: selectedLanguage, into: &translations)
        objectWillChange.send()
        NotificationCenter.default.post(name: .localizationChanged, object: nil)
    }

    private func load(language: Language, into dict: inout [String: String]) {
        guard let url = Bundle.main.url(forResource: language.rawValue, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            dict = [:]
            return
        }
        dict = json
    }
}
