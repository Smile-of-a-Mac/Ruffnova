import Foundation

struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let addedDate: Date
    var frame: UInt32?
}

@MainActor
final class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()

    @Published var bookmarks: [Bookmark] = []
    private let storageURL: URL

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
            try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("RuffleFlashPlayer")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("bookmarks.json")
        }
        load()
    }

    func add(url: URL, name: String? = nil, frame: UInt32? = nil) {
        let bookmark = Bookmark(
            id: UUID(),
            url: url,
            name: name ?? url.lastPathComponent,
            addedDate: Date(),
            frame: frame
        )
        guard !contains(url) else { return }
        bookmarks.insert(bookmark, at: 0)
        save()
    }

    func remove(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func remove(url: URL) {
        bookmarks.removeAll { urlsMatch($0.url, url) }
        save()
    }

    func contains(_ url: URL) -> Bool {
        bookmarks.contains { urlsMatch($0.url, url) }
    }

    func removeAll() {
        bookmarks.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
        else { return }
        bookmarks = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        try? data.write(to: storageURL)
    }

    private func urlsMatch(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.resolvingSymlinksInPath() == rhs.standardizedFileURL.resolvingSymlinksInPath()
    }
}
