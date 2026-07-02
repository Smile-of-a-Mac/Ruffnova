import Foundation

struct LibraryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var name: String
    var fileSize: Int64
    var lastOpened: Date
    var dateAdded: Date
    var thumbnailData: Data?
    var bookmarkData: Data?
    var tags: [String]
    var notes: String
    var isFavorite: Bool
    var lastPlaybackFrame: UInt32?
    var compatibilityStatus: CompatibilityStatus
    var availabilityStatus: AvailabilityStatus

    init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        fileSize: Int64 = 0,
        lastOpened: Date = Date(),
        dateAdded: Date = Date(),
        thumbnailData: Data? = nil,
        bookmarkData: Data? = nil,
        tags: [String] = [],
        notes: String = "",
        isFavorite: Bool = false,
        lastPlaybackFrame: UInt32? = nil,
        compatibilityStatus: CompatibilityStatus = .unknown,
        availabilityStatus: AvailabilityStatus = .available
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.fileSize = fileSize
        self.lastOpened = lastOpened
        self.dateAdded = dateAdded
        self.thumbnailData = thumbnailData
        self.bookmarkData = bookmarkData
        self.tags = tags
        self.notes = notes
        self.isFavorite = isFavorite
        self.lastPlaybackFrame = lastPlaybackFrame
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

enum AvailabilityStatus: String, Codable, CaseIterable {
    case available
    case missing
}

enum LibrarySortOrder: String, CaseIterable {
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
