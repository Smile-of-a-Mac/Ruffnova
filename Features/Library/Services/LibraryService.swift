import Foundation
import OSLog

@MainActor
final class LibraryService: ObservableObject {
    static let shared = LibraryService()
    static let currentSchemaVersion = 4

    @Published private(set) var items: [LibraryItem] = []
    @Published private(set) var migrationFailures: [PersistenceMigrationFailure] = []

    private let directoryURL: URL
    private let storageURL: URL
    private let versionURL: URL
    private let schemaVersion = LibraryService.currentSchemaVersion
    private let logger = Logger(subsystem: "com.ruffnova", category: "library")
    private let fileManager = FileManager.default
    private let thumbnailService: ThumbnailService
    private var libraryLoadFailed = false

    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RuffleFlashPlayer")
        self.init(directory: dir, thumbnailService: .shared)
    }

    convenience init(directory: URL) {
        self.init(directory: directory, thumbnailService: .shared)
    }

    init(directory: URL, thumbnailService: ThumbnailService) {
        self.directoryURL = directory
        self.storageURL = directory.appendingPathComponent("library.json")
        self.versionURL = directory.appendingPathComponent("library.version")
        self.thumbnailService = thumbnailService
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
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

    func importFiles(_ urls: [URL]) -> ImportResult {
        let preview = ImportPreview(candidates: urls, existingURLs: items.map(\.url))
        guard !preview.newURLs.isEmpty else {
            return ImportResult(addedURLs: [], duplicateURLs: preview.duplicateURLs)
        }

        let now = Date()
        for url in preview.newURLs {
            let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
            var item = LibraryItem(
                url: url,
                fileSize: Int64(resourceValues?.fileSize ?? 0),
                lastOpened: now,
                dateAdded: now
            )
            item.bookmarkData = createBookmarkData(for: url)
            items.append(item)
        }
        save()
        return ImportResult(addedURLs: preview.newURLs, duplicateURLs: preview.duplicateURLs)
    }

    func update(_ id: UUID, changes: (inout LibraryItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        objectWillChange.send()
        changes(&items[index])
        save()
    }

    func remove(_ id: UUID) {
        if let item = item(with: id) {
            thumbnailService.remove(item.thumbnailIdentifier)
            BookmarkManager.shared.remove(url: item.url)
            CollectionService.shared.removeItemFromAllCollections(item.id)
        }
        items.removeAll { $0.id == id }
        save()
    }

    func removeAll() {
        for item in items {
            thumbnailService.remove(item.thumbnailIdentifier)
        }
        BookmarkManager.shared.removeAll()
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

    func effectiveRuntimeProfile(for url: URL, defaults: RuntimeDefaults) -> RuntimeDefaults {
        item(for: url)?.runtimeProfile?.resolved(using: defaults) ?? defaults
    }

    // MARK: - Sorting

    func sorted(by order: LibrarySortOrder, ascending: Bool = true) -> [LibraryItem] {
        sortedItems(items, by: order, ascending: ascending)
    }

    func items(matching filter: LibraryFilter, sortedBy order: LibrarySortOrder, ascending: Bool = true) -> [LibraryItem] {
        sortedItems(filteredItems(items, by: filter), by: order, ascending: ascending)
    }

    private func sortedItems(_ items: [LibraryItem], by order: LibrarySortOrder, ascending: Bool) -> [LibraryItem] {
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
        filteredItems(items, by: filter)
    }

    private func filteredItems(_ items: [LibraryItem], by filter: LibraryFilter) -> [LibraryItem] {
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
            return items.filter { $0.contentType == .animation }
        case .interactive:
            return items.filter { $0.contentType == .interactive }
        case .continuePlaying:
            return items.filter { $0.availabilityStatus == .available && ($0.lastPlaybackFrame ?? 0) > 0 }
        case .recentlyAdded:
            return items.sorted { $0.dateAdded > $1.dateAdded }
        case .untagged:
            return items.filter { $0.tags.isEmpty }
        }
    }

    // MARK: - Bookmark Resolution

    func resolveBookmarks() {
        objectWillChange.send()
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
        objectWillChange.send()
        items[index].url = newURL
        items[index].name = newURL.lastPathComponent
        items[index].bookmarkData = createBookmarkData(for: newURL)
        items[index].availabilityStatus = .available
        if let resourceValues = try? newURL.resourceValues(forKeys: [.fileSizeKey]) {
            items[index].fileSize = Int64(resourceValues.fileSize ?? 0)
        }
        save()
    }

    func resetRuntimeProfile(for id: UUID) {
        update(id) { $0.runtimeProfile = nil }
    }

    // MARK: - Migration

    @discardableResult
    func migrateIfNeeded() -> PersistenceMigrationReport {
        var report = PersistenceMigrationReport(failures: migrationFailures)
        guard !libraryLoadFailed else { return report }
        let currentVersion = max(readSchemaVersion(), readLibraryStoreSchemaVersion())
        guard currentVersion < schemaVersion else { return report }
        logger.info("Starting library migration (schema \(currentVersion) -> \(self.schemaVersion))")

        let originalItems = items
        guard backupLibraryIfNeeded(for: currentVersion, into: &report) else {
            migrationFailures = report.failures
            return report
        }

        migrateFromRecentFiles(into: &report)
        migrateFromBookmarks(into: &report)
        _ = migrateLegacyThumbnails(in: &items, report: &report)

        guard save(into: &report) else {
            items = originalItems
            migrationFailures = report.failures
            return report
        }

        if writeSchemaVersion(schemaVersion, into: &report) {
            logger.info("Library migration complete")
        }
        migrationFailures = report.failures
        return report
    }

    private func migrateFromRecentFiles(into report: inout PersistenceMigrationReport) {
        let recentURL = directoryURL.appendingPathComponent("recentFiles.json")

        guard fileManager.fileExists(atPath: recentURL.path) else { return }
        let persisted: [PersistedRecentFile]
        do {
            let data = try Data(contentsOf: recentURL)
            persisted = try JSONDecoder().decode([PersistedRecentFile].self, from: data)
        } catch {
            recordFailure(store: "recentFiles.json", error: error, requiresUserAction: false, into: &report)
            return
        }

        for persistedFile in persisted {
            var isStale = false
            let url: URL
            do {
                let resolved = try URL(
                    resolvingBookmarkData: persistedFile.bookmarkData,
                    options: .withoutUI,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                url = resolved
            } catch {
                recordFailure(store: "recentFiles.json", error: error, requiresUserAction: false, into: &report)
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

    private func migrateFromBookmarks(into report: inout PersistenceMigrationReport) {
        let bookmarksURL = directoryURL.appendingPathComponent("bookmarks.json")

        guard fileManager.fileExists(atPath: bookmarksURL.path) else { return }
        let bookmarks: [LegacyBookmark]
        do {
            let data = try Data(contentsOf: bookmarksURL)
            bookmarks = try JSONDecoder().decode([LegacyBookmark].self, from: data)
        } catch {
            recordFailure(store: "bookmarks.json", error: error, requiresUserAction: false, into: &report)
            return
        }

        for bookmark in bookmarks {
            if let index = items.firstIndex(where: { urlsMatch($0.url, bookmark.url) }) {
                objectWillChange.send()
                items[index].isFavorite = true
                if items[index].lastPlaybackFrame == nil {
                    items[index].lastPlaybackFrame = bookmark.frame
                }
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

    private func readLibraryStoreSchemaVersion() -> Int {
        guard let data = try? Data(contentsOf: storageURL),
              let store = try? JSONDecoder().decode(LibraryStore.self, from: data)
        else { return 0 }
        return store.schemaVersion
    }

    private func backupLibraryIfNeeded(for version: Int, into report: inout PersistenceMigrationReport) -> Bool {
        guard fileManager.fileExists(atPath: storageURL.path) else { return true }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: storageURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            recordFailure(
                store: "library.json",
                message: "Library storage is not a regular file.",
                requiresUserAction: true,
                into: &report
            )
            return false
        }

        let backupURL = directoryURL.appendingPathComponent("library.json.schema-\(version).backup")
        guard !fileManager.fileExists(atPath: backupURL.path) else { return true }
        do {
            try fileManager.copyItem(at: storageURL, to: backupURL)
            return true
        } catch {
            recordFailure(store: "library.json.backup", error: error, requiresUserAction: true, into: &report)
            return false
        }
    }

    @discardableResult
    private func writeSchemaVersion(_ version: Int, into report: inout PersistenceMigrationReport) -> Bool {
        do {
            let data = try JSONEncoder().encode(version)
            try data.write(to: versionURL, options: .atomic)
            return true
        } catch {
            recordFailure(store: "library.version", error: error, requiresUserAction: false, into: &report)
            return false
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        do {
            var report = PersistenceMigrationReport()
            var decoded = try decodeLibraryItems(from: data)
            let migratedThumbnails = migrateLegacyThumbnails(in: &decoded, report: &report)
            items = decoded
            if migratedThumbnails || legacyArrayStoreExists(in: data) {
                save(into: &report)
            }
            migrationFailures = report.failures
            logger.info("Loaded \(decoded.count) library items")
        } catch {
            libraryLoadFailed = true
            var report = PersistenceMigrationReport()
            recordFailure(store: "library.json", error: error, requiresUserAction: true, into: &report)
            migrationFailures = report.failures
            items = []
        }
    }

    private func decodeLibraryItems(from data: Data) throws -> [LibraryItem] {
        if let store = try? JSONDecoder().decode(LibraryStore.self, from: data) {
            return store.items
        }
        return try JSONDecoder().decode([LibraryItem].self, from: data)
    }

    private func legacyArrayStoreExists(in data: Data) -> Bool {
        (try? JSONDecoder().decode(LibraryStore.self, from: data)) == nil
    }

    private func migrateLegacyThumbnails(in decoded: inout [LibraryItem], report: inout PersistenceMigrationReport) -> Bool {
        var didMigrate = false
        for index in decoded.indices {
            guard decoded[index].thumbnailIdentifier == nil,
                  let thumbnailData = decoded[index].thumbnailData
            else { continue }

            guard let identifier = thumbnailService.store(thumbnailData, for: decoded[index].id) else {
                recordFailure(
                    store: "library.json",
                    message: "Failed to migrate thumbnail for \(decoded[index].name)",
                    requiresUserAction: false,
                    into: &report
                )
                continue
            }

            decoded[index].thumbnailIdentifier = identifier
            decoded[index].thumbnailData = nil
            didMigrate = true
        }
        return didMigrate
    }

    private func save() {
        var report = PersistenceMigrationReport()
        _ = save(into: &report)
        migrationFailures.append(contentsOf: report.failures)
    }

    @discardableResult
    private func save(into report: inout PersistenceMigrationReport) -> Bool {
        do {
            let data = try JSONEncoder().encode(LibraryStore(schemaVersion: schemaVersion, items: items))
            try data.write(to: storageURL, options: .atomic)
            return true
        } catch {
            recordFailure(store: "library.json", error: error, requiresUserAction: false, into: &report)
            return false
        }
    }

    private func createBookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func urlsMatch(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.resolvingSymlinksInPath() == rhs.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func recordFailure(
        store: String,
        error: Error,
        requiresUserAction: Bool,
        into report: inout PersistenceMigrationReport
    ) {
        recordFailure(
            store: store,
            message: error.localizedDescription,
            requiresUserAction: requiresUserAction,
            into: &report
        )
    }

    private func recordFailure(
        store: String,
        message: String,
        requiresUserAction: Bool,
        into report: inout PersistenceMigrationReport
    ) {
        logger.error("Migration failure in \(store): \(message)")
        report.failures.append(PersistenceMigrationFailure(
            store: store,
            message: message,
            requiresUserAction: requiresUserAction
        ))
    }
}

struct PersistenceMigrationReport: Equatable {
    var failures: [PersistenceMigrationFailure] = []

    var requiresUserAction: Bool {
        failures.contains { $0.requiresUserAction }
    }
}

struct PersistenceMigrationFailure: Identifiable, Equatable {
    let id = UUID()
    var store: String
    var message: String
    var requiresUserAction: Bool
}

struct LibraryStore: Codable {
    var schemaVersion: Int
    var items: [LibraryItem]
}

// MARK: - Legacy Bookmark Type (for migration)

private struct LegacyBookmark: Codable {
    let id: UUID
    let url: URL
    let name: String
    let addedDate: Date
    var frame: UInt32?
}
