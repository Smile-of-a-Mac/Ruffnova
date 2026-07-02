import Foundation

enum PlayerMode: String, Codable, CaseIterable, Identifiable {
    case normal
    case cinema
    case game

    var id: String { rawValue }

    var localizedKey: String {
        switch self {
        case .normal: return "player.mode.normal"
        case .cinema: return "player.mode.cinema"
        case .game: return "player.mode.game"
        }
    }
}

struct PlaybackPreferences: Codable, Equatable {
    var volume: Float
    var isMuted: Bool
    var qualityRawValue: Int32
    var letterbox: String
    var isLooping: Bool
    var speed: Float
    var lastPlaybackFrame: UInt32?
    var preferredMode: PlayerMode

    init(
        volume: Float = 1.0,
        isMuted: Bool = false,
        qualityRawValue: Int32 = RuffleQuality.high.rawValue,
        letterbox: String = "fullscreen",
        isLooping: Bool = false,
        speed: Float = 1.0,
        lastPlaybackFrame: UInt32? = nil,
        preferredMode: PlayerMode = .normal
    ) {
        self.volume = volume
        self.isMuted = isMuted
        self.qualityRawValue = qualityRawValue
        self.letterbox = letterbox
        self.isLooping = isLooping
        self.speed = speed
        self.lastPlaybackFrame = lastPlaybackFrame
        self.preferredMode = preferredMode
    }

    var quality: RuffleQuality {
        RuffleQuality(rawValue: qualityRawValue) ?? .high
    }
}
