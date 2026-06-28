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
    @Published var bookmarks: [Bookmark] = []
    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RuffleFlashPlayer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("bookmarks.json")
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
        guard !bookmarks.contains(where: { $0.url == url }) else { return }
        bookmarks.insert(bookmark, at: 0)
        save()
    }

    func remove(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
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
}
