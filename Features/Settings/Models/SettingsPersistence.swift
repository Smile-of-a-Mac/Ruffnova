import Foundation

/// Centralized settings persistence using UserDefaults.
/// All keys are unprefixed to be compatible with SwiftUI @AppStorage.
/// This is the single source of truth for player preferences.
final class SettingsPersistence {
    static let shared = SettingsPersistence()
    private let defaults = UserDefaults.standard

    // Keys match @AppStorage keys used in settings views
    var quality: Int32 {
        get {
            guard defaults.object(forKey: "quality") != nil else { return RuffleQuality.high.rawValue }
            return Int32(defaults.integer(forKey: "quality"))
        }
        set { defaults.set(Int(newValue), forKey: "quality") }
    }
    var volume: Float {
        get { let v = defaults.float(forKey: "volume"); return v == 0 ? 1.0 : v }
        set { defaults.set(newValue, forKey: "volume") }
    }
    var isMuted: Bool {
        get { defaults.bool(forKey: "isMuted") }
        set { defaults.set(newValue, forKey: "isMuted") }
    }
    var isLooping: Bool {
        get { defaults.bool(forKey: "loop") }
        set { defaults.set(newValue, forKey: "loop") }
    }
    var speed: Float {
        get { let v = defaults.float(forKey: "speed"); return v == 0 ? 1.0 : v }
        set { defaults.set(newValue, forKey: "speed") }
    }
    var showDebugUI: Bool {
        get { defaults.bool(forKey: "showDebugUI") }
        set { defaults.set(newValue, forKey: "showDebugUI") }
    }
    var showToolbar: Bool {
        get {
            if defaults.object(forKey: "showToolbar") == nil { return true }
            return defaults.bool(forKey: "showToolbar")
        }
        set { defaults.set(newValue, forKey: "showToolbar") }
    }
    var maxExecutionDuration: Double {
        get {
            let v = defaults.double(forKey: "maxExecutionDuration")
            return v == 0 ? 15.0 : v
        }
        set { defaults.set(newValue, forKey: "maxExecutionDuration") }
    }
    var letterbox: String {
        get { defaults.string(forKey: "letterbox") ?? "fullscreen" }
        set { defaults.set(newValue, forKey: "letterbox") }
    }
    var autoplay: Bool {
        get {
            if defaults.object(forKey: "autoplay") == nil { return true }
            return defaults.bool(forKey: "autoplay")
        }
        set { defaults.set(newValue, forKey: "autoplay") }
    }
    var defaultPlayerMode: PlayerMode {
        get {
            guard let rawValue = defaults.string(forKey: "defaultPlayerMode") else { return .normal }
            return PlayerMode(rawValue: rawValue) ?? .normal
        }
        set { defaults.set(newValue.rawValue, forKey: "defaultPlayerMode") }
    }

    func resetAll() {
        for key in ["quality", "volume", "isMuted", "loop",
                      "speed", "showDebugUI", "showToolbar",
                      "maxExecutionDuration", "letterbox", "autoplay",
                      "graphicsBackend", "networkAccess", "filesystemAccess",
                      "defaultPlayerMode"] {
            defaults.removeObject(forKey: key)
        }
    }
}
