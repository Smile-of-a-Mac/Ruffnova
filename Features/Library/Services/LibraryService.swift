import Foundation
import OSLog

@MainActor
final class LibraryService {
    static let shared = LibraryService()

    private(set) var items: [LibraryItem] = []

    private let storageURL: URL
    private let versionURL: URL
    private let schemaVersion = 1
    private let logger = Logger(subsystem: "com.ruffnova", category: "library")
    private let fileManager = FileManager.default

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RuffleFlashPlayer")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("library.json")
        versionURL = dir.appendingPathComponent("library.version")
        load()
    }

    // MARK: - CRUD

    func add(_ item: LibraryItem) {
        guard !items.contains(where: { $0.url.resolvingSymlinksInPath() == item.url.resolvingSymlinksInPath() }) else { return }
        var mutable = item
        if mutable.bookmarkData == nil {
            mutable.bookmarkData = createBookmarkData(for: item.url)
        }
        items.append(mutable)
        save()
    }

    func add(_ items: [LibraryItem]) {
        for item in items {
            guard !self.items.contains(where: { $0.url.resolvingSymlinksInPath() == item.url.resolvingSymlinksInPath() }) else { continue }
            var mutable = item
            if mutable.bookmarkData == nil {
                mutable.bookmarkData = createBookmarkData(for: item.url)
            }
            self.items.append(mutable)
        }
        save()
    }

    func update(_ id: UUID, changes: (inout LibraryItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        changes(&items[index])
        save()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func removeAll() {
        items.removeAll()
        save()
    }

    func item(for url: URL) -> LibraryItem? {
        items.first(where: { $0.url.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() })
    }

    func item(with id: UUID) -> LibraryItem? {
        items.first(where: { $0.id == id })
    }

    func contains(_ url: URL) -> Bool {
        items.contains(where: { $0.url.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() })
    }

    // MARK: - Sorting

    func sorted(by order: LibrarySortOrder, ascending: Bool = true) -> [LibraryItem] {
        let sorted: [LibraryItem]
        switch order {
        case .name:
            sorted = items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .lastOpened:
            sorted = items.sorted { $0.lastOpened > $1.lastOpened }
        case .dateAdded:
            sorted = items.sorted { $0.dateAdded > $1.dateAdded }
        case .fileSize:
            sorted = items.sorted { $0.fileSize > $1.fileSize }
        }
        return ascending ? sorted : sorted.reversed()
    }

    // MARK: - Filtering

    func filtered(by filter: LibraryFilter) -> [LibraryItem] {
        switch filter {
        case .all:
            return items
        case .favorites:
            return items.filter { $0.isFavorite }
        case .recent:
            return items.sorted { $0.lastOpened > $1.lastOpened }
                .prefix(20).map { $0 }
        case .missing:
            return items.filter { $0.availabilityStatus == .missing }
        case .compatibilityIssues:
            return items.filter { $0.compatibilityStatus == .unsupported }
        case .animation:
            return items.filter { $0.compatibilityStatus == .compatible }
        case .interactive:
            return items.filter { $0.compatibilityStatus == .unknown }
        }
    }

    // MARK: - Bookmark Resolution

    func resolveBookmarks() {
        for index in items.indices {
            guard let bookmarkData = items[index].bookmarkData else {
                let data = createBookmarkData(for: items[index].url)
                items[index].bookmarkData = data
                continue
            }
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                items[index].url = resolved
                items[index].availabilityStatus = .available
                if isStale, let freshData = createBookmarkData(for: resolved) {
                    items[index].bookmarkData = freshData
                }
            } else {
                let fileExists = fileManager.fileExists(atPath: items[index].url.path)
                items[index].availabilityStatus = fileExists ? .available : .missing
                if fileExists, let freshData = createBookmarkData(for: items[index].url) {
                    items[index].bookmarkData = freshData
                }
            }
        }
        save()
    }

    // MARK: - Locate Missing File

    func locateFile(for id: UUID, newURL: URL) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].url = newURL
        items[index].name = newURL.lastPathComponent
        items[index].bookmarkData = createBookmarkData(for: newURL)
        items[index].availabilityStatus = .available
        if let resourceValues = try? newURL.resourceValues(forKeys: [.fileSizeKey]) {
            items[index].fileSize = Int64(resourceValues.fileSize ?? 0)
        }
        save()
    }

    // MARK: - Migration

    func migrateIfNeeded() {
        let currentVersion = readSchemaVersion()
        guard currentVersion < schemaVersion else { return }
        logger.info("Starting library migration (schema \(currentVersion) -> \(self.schemaVersion))")

        migrateFromRecentFiles()
        migrateFromBookmarks()

        writeSchemaVersion(schemaVersion)
        logger.info("Library migration complete")
    }

    private func migrateFromRecentFiles() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RuffleFlashPlayer")
        let recentURL = dir.appendingPathComponent("recentFiles.json")

        guard let data = try? Data(contentsOf: recentURL),
              let persisted = try? JSONDecoder().decode([PersistedRecentFile].self, from: data)
        else { return }

        for persistedFile in persisted {
            var isStale = false
            let url: URL
            if let resolved = try? URL(
                resolvingBookmarkData: persistedFile.bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                url = resolved
            } else {
                continue
            }

            guard !contains(url) else { continue }

            let item = LibraryItem(
                id: persistedFile.id,
                url: url,
                name: persistedFile.name,
                fileSize: persistedFile.fileSize,
                lastOpened: persistedFile.lastOpened,
                dateAdded: persistedFile.lastOpened,
                thumbnailData: persistedFile.thumbnailData,
                bookmarkData: persistedFile.bookmarkData,
                availabilityStatus: fileManager.fileExists(atPath: url.path) ? .available : .missing
            )
            items.append(item)
        }
        logger.info("Migrated \(persisted.count) recent files")
    }

    private func migrateFromBookmarks() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RuffleFlashPlayer")
        let bookmarksURL = dir.appendingPathComponent("bookmarks.json")

        guard let data = try? Data(contentsOf: bookmarksURL),
              let bookmarks = try? JSONDecoder().decode([LegacyBookmark].self, from: data)
        else { return }

        for bookmark in bookmarks {
            if let index = items.firstIndex(where: { $0.url == bookmark.url }) {
                items[index].isFavorite = true
            } else {
                let item = LibraryItem(
                    url: bookmark.url,
                    name: bookmark.name,
                    dateAdded: bookmark.addedDate,
                    isFavorite: true,
                    lastPlaybackFrame: bookmark.frame,
                    availabilityStatus: fileManager.fileExists(atPath: bookmark.url.path) ? .available : .missing
                )
                items.append(item)
            }
        }
        logger.info("Migrated \(bookmarks.count) bookmarks")
    }

    // MARK: - Schema Version

    private func readSchemaVersion() -> Int {
        guard let data = try? Data(contentsOf: versionURL),
              let version = try? JSONDecoder().decode(Int.self, from: data)
        else { return 0 }
        return version
    }

    private func writeSchemaVersion(_ version: Int) {
        guard let data = try? JSONEncoder().encode(version) else { return }
        try? data.write(to: versionURL, options: .atomic)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([LibraryItem].self, from: data)
            items = decoded
            logger.info("Loaded \(decoded.count) library items")
        } catch {
            logger.error("Failed to load library: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save library: \(error.localizedDescription)")
        }
    }

    private func createBookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}

// MARK: - Legacy Bookmark Type (for migration)

private struct LegacyBookmark: Codable {
    let id: UUID
    let url: URL
    let name: String
    let addedDate: Date
    var frame: UInt32?
}
