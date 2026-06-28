import Foundation

struct PersistedRecentFile: Codable, Identifiable {
    let id: UUID
    let name: String
    var lastOpened: Date
    let fileSize: Int64
    let bookmarkData: Data
    let thumbnailData: Data?
}

final class LibraryPersistence {
    static let shared = LibraryPersistence()

    private let storageURL: URL
    private let maxRecentCount = 50

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RuffleFlashPlayer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("recentFiles.json")
    }

    func loadRecentFiles() -> [RecentFile] {
        guard let data = try? Data(contentsOf: storageURL),
              let persisted = try? JSONDecoder().decode([PersistedRecentFile].self, from: data)
        else { return [] }

        return persisted.compactMap { resolve($0) }
    }

    func saveRecentFiles(_ files: [RecentFile]) {
        let persisted = files.prefix(maxRecentCount).compactMap { persist($0) }
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        try? data.write(to: storageURL)
    }

    func removeFromRecent(_ id: UUID) {
        var files = loadRecentFiles()
        files.removeAll { $0.id == id }
        saveRecentFiles(files)
    }

    private func persist(_ file: RecentFile) -> PersistedRecentFile? {
        let bookmarkData = (try? file.url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )) ?? Data()
        guard !bookmarkData.isEmpty else { return nil }
        return PersistedRecentFile(
            id: file.id,
            name: file.name,
            lastOpened: file.lastOpened,
            fileSize: file.fileSize,
            bookmarkData: bookmarkData,
            thumbnailData: file.thumbnailData
        )
    }

    private func resolve(_ persisted: PersistedRecentFile) -> RecentFile? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: persisted.bookmarkData,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        _ = isStale
        return RecentFile(
            id: persisted.id,
            url: url,
            name: persisted.name,
            lastOpened: persisted.lastOpened,
            fileSize: persisted.fileSize,
            thumbnailData: persisted.thumbnailData
        )
    }
}
