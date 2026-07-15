import Foundation

struct RuntimeDefaults: Equatable {
    var quality: RuffleQuality
    var letterbox: String
    var playbackSpeed: Float
    var isLooping: Bool
    var autoplay: Bool
    var maxExecutionDuration: TimeInterval

    init(
        quality: RuffleQuality = .high,
        letterbox: String = "fullscreen",
        playbackSpeed: Float = 1.0,
        isLooping: Bool = false,
        autoplay: Bool = true,
        maxExecutionDuration: TimeInterval = 15.0
    ) {
        self.quality = quality
        self.letterbox = letterbox
        self.playbackSpeed = playbackSpeed
        self.isLooping = isLooping
        self.autoplay = autoplay
        self.maxExecutionDuration = maxExecutionDuration
    }
}

struct FileRuntimeProfile: Codable, Equatable {
    var qualityRawValue: Int32?
    var letterbox: String?
    var playbackSpeed: Float?
    var isLooping: Bool?
    var autoplay: Bool?
    var maxExecutionDuration: TimeInterval?

    init(
        qualityRawValue: Int32? = nil,
        letterbox: String? = nil,
        playbackSpeed: Float? = nil,
        isLooping: Bool? = nil,
        autoplay: Bool? = nil,
        maxExecutionDuration: TimeInterval? = nil
    ) {
        self.qualityRawValue = qualityRawValue
        self.letterbox = letterbox
        self.playbackSpeed = playbackSpeed
        self.isLooping = isLooping
        self.autoplay = autoplay
        self.maxExecutionDuration = maxExecutionDuration
    }

    func resolved(using defaults: RuntimeDefaults) -> RuntimeDefaults {
        RuntimeDefaults(
            quality: qualityRawValue.flatMap(RuffleQuality.init(rawValue:)) ?? defaults.quality,
            letterbox: letterbox ?? defaults.letterbox,
            playbackSpeed: playbackSpeed ?? defaults.playbackSpeed,
            isLooping: isLooping ?? defaults.isLooping,
            autoplay: autoplay ?? defaults.autoplay,
            maxExecutionDuration: maxExecutionDuration ?? defaults.maxExecutionDuration
        )
    }

    var isEmpty: Bool {
        qualityRawValue == nil && letterbox == nil && playbackSpeed == nil &&
            isLooping == nil && autoplay == nil && maxExecutionDuration == nil
    }
}

struct LibraryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var name: String
    var fileSize: Int64
    var lastOpened: Date
    var dateAdded: Date
    var thumbnailIdentifier: String?
    var thumbnailData: Data?
    var thumbnailGenerationFailedAt: Date?
    var metadata: SWFMetadata?
    var bookmarkData: Data?
    var tags: [String]
    var notes: String
    var isFavorite: Bool
    var lastPlaybackFrame: UInt32?
    var playbackPreferences: PlaybackPreferences?
    var runtimeProfile: FileRuntimeProfile?
    var showsVirtualControls: Bool?
    var inputProfile: InputProfile?
    var gameStoragePreferences: GameStoragePreferences?
    var compatibilityAssessment: PersistedCompatibilityAssessment?
    var contentType: LibraryContentType?
    var compatibilityStatus: CompatibilityStatus
    var availabilityStatus: AvailabilityStatus

    init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        fileSize: Int64 = 0,
        lastOpened: Date = Date(),
        dateAdded: Date = Date(),
        thumbnailIdentifier: String? = nil,
        thumbnailData: Data? = nil,
        thumbnailGenerationFailedAt: Date? = nil,
        metadata: SWFMetadata? = nil,
        bookmarkData: Data? = nil,
        tags: [String] = [],
        notes: String = "",
        isFavorite: Bool = false,
        lastPlaybackFrame: UInt32? = nil,
        playbackPreferences: PlaybackPreferences? = nil,
        runtimeProfile: FileRuntimeProfile? = nil,
        showsVirtualControls: Bool? = nil,
        inputProfile: InputProfile? = nil,
        gameStoragePreferences: GameStoragePreferences? = nil,
        compatibilityAssessment: PersistedCompatibilityAssessment? = nil,
        contentType: LibraryContentType? = nil,
        compatibilityStatus: CompatibilityStatus = .unknown,
        availabilityStatus: AvailabilityStatus = .available
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.fileSize = fileSize
        self.lastOpened = lastOpened
        self.dateAdded = dateAdded
        self.thumbnailIdentifier = thumbnailIdentifier
        self.thumbnailData = thumbnailData
        self.thumbnailGenerationFailedAt = thumbnailGenerationFailedAt
        self.metadata = metadata
        self.bookmarkData = bookmarkData
        self.tags = tags
        self.notes = notes
        self.isFavorite = isFavorite
        self.lastPlaybackFrame = lastPlaybackFrame
        self.playbackPreferences = playbackPreferences
        self.runtimeProfile = runtimeProfile
        self.showsVirtualControls = showsVirtualControls
        self.inputProfile = inputProfile
        self.gameStoragePreferences = gameStoragePreferences
        self.compatibilityAssessment = compatibilityAssessment
        self.contentType = contentType
        self.compatibilityStatus = compatibilityStatus
        self.availabilityStatus = availabilityStatus
    }

    static func == (lhs: LibraryItem, rhs: LibraryItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum LibraryRemovalPolicy {
    static func shouldClosePlayer(currentFileURL: URL?, removing item: LibraryItem) -> Bool {
        currentFileURL?.standardizedFileURL == item.url.standardizedFileURL
    }
}

enum CompatibilityStatus: String, Codable, CaseIterable {
    case compatible
    case unknown
    case unsupported
}

enum LibraryContentType: String, Codable, CaseIterable {
    case animation
    case interactive
}

enum AvailabilityStatus: String, Codable, CaseIterable {
    case available
    case missing
}

enum LibraryItemDetailsSection: String, CaseIterable, Hashable, Identifiable {
    case overview
    case compatibility
    case controls
    case storage
    case permissions

    var id: String { rawValue }

    var localizedKey: String {
        "library.details.section.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "doc.text"
        case .compatibility:
            return "stethoscope"
        case .controls:
            return "gamecontroller"
        case .storage:
            return "externaldrive"
        case .permissions:
            return "lock.shield"
        }
    }
}

enum LibrarySortOrder: String, Codable, CaseIterable {
    case name
    case lastOpened
    case dateAdded
    case fileSize

    var localizedKey: String {
        switch self {
        case .name: return "sort.name"
        case .lastOpened: return "sort.lastOpened"
        case .dateAdded: return "sort.dateAdded"
        case .fileSize: return "sort.fileSize"
        }
    }
}

enum LibraryFilter: String, CaseIterable {
    case all
    case favorites
    case recent
    case missing
    case compatibilityIssues
    case animation
    case interactive
    case continuePlaying
    case recentlyAdded
    case untagged

    var localizedKey: String {
        switch self {
        case .all: return "filter.all"
        case .favorites: return "filter.favorites"
        case .recent: return "filter.recent"
        case .missing: return "filter.missing"
        case .compatibilityIssues: return "filter.compatibilityIssues"
        case .animation: return "filter.animation"
        case .interactive: return "filter.interactive"
        case .continuePlaying: return "filter.continuePlaying"
        case .recentlyAdded: return "filter.recentlyAdded"
        case .untagged: return "filter.untagged"
        }
    }
}
