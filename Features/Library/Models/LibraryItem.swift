import Foundation

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
        self.contentType = contentType
        self.compatibilityStatus = compatibilityStatus
        self.availabilityStatus = availabilityStatus
    }

    static func == (lhs: LibraryItem, rhs: LibraryItem) -> Bool {
        lhs.id == rhs.id
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

    var localizedKey: String {
        switch self {
        case .all: return "filter.all"
        case .favorites: return "filter.favorites"
        case .recent: return "filter.recent"
        case .missing: return "filter.missing"
        case .compatibilityIssues: return "filter.compatibilityIssues"
        case .animation: return "filter.animation"
        case .interactive: return "filter.interactive"
        }
    }
}
