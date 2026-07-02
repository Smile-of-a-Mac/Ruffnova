import XCTest
@testable import Ruffnova

@MainActor
final class BookmarkManagerTests: XCTestCase {
    func testRemovingURLClearsPersistedFavoriteForReaddedFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storageURL = directory.appendingPathComponent("bookmarks.json")
        let fileURL = directory.appendingPathComponent("game.swf")
        try Data().write(to: fileURL)

        let manager = BookmarkManager(storageURL: storageURL)
        manager.add(url: fileURL)
        XCTAssertTrue(manager.contains(fileURL))

        manager.remove(url: fileURL.standardizedFileURL)
        XCTAssertFalse(manager.contains(fileURL))

        let reloadedManager = BookmarkManager(storageURL: storageURL)
        XCTAssertFalse(reloadedManager.contains(fileURL))
    }
}
