import XCTest
@testable import Ruffnova

@MainActor
final class LibraryMigrationTests: XCTestCase {
    func testMigratesRecentFilesAndBookmarksIdempotentlyWithoutDeletingLegacyFiles() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let gameURL = directory.appendingPathComponent("game.swf")
        try Data("swf".utf8).write(to: gameURL)
        let recentURL = directory.appendingPathComponent("recentFiles.json")
        let bookmarksURL = directory.appendingPathComponent("bookmarks.json")
        let bookmarkData = try gameURL.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let itemID = UUID()
        let recent = PersistedRecentFile(
            id: itemID,
            name: "game.swf",
            lastOpened: Date(timeIntervalSince1970: 100),
            fileSize: 3,
            bookmarkData: bookmarkData,
            thumbnailData: nil
        )
        try JSONEncoder().encode([recent]).write(to: recentURL)
        let bookmark = Bookmark(id: UUID(), url: gameURL, name: "game.swf", addedDate: Date(timeIntervalSince1970: 90), frame: 12)
        try JSONEncoder().encode([bookmark]).write(to: bookmarksURL)

        let service = LibraryService(directory: directory, thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails")))

        let firstReport = service.migrateIfNeeded()
        let secondReport = service.migrateIfNeeded()

        XCTAssertTrue(firstReport.failures.isEmpty)
        XCTAssertTrue(secondReport.failures.isEmpty)
        XCTAssertEqual(service.items.count, 1)
        XCTAssertEqual(service.items.first?.id, itemID)
        XCTAssertEqual(service.items.first?.isFavorite, true)
        XCTAssertEqual(service.items.first?.lastPlaybackFrame, 12)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recentURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bookmarksURL.path))
        XCTAssertEqual(try readLibraryStore(from: directory).schemaVersion, LibraryService.currentSchemaVersion)
        XCTAssertEqual(try readLibraryVersion(from: directory), LibraryService.currentSchemaVersion)
    }

    func testMigratesLegacyThumbnailBlobToCacheReferenceAndSchemaStore() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let itemID = UUID()
        let item = LibraryItem(
            id: itemID,
            url: directory.appendingPathComponent("thumb.swf"),
            thumbnailData: Self.pngData
        )
        try JSONEncoder().encode([item]).write(to: directory.appendingPathComponent("library.json"))

        let service = LibraryService(directory: directory, thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails")))

        XCTAssertEqual(service.items.count, 1)
        XCTAssertNil(service.items.first?.thumbnailData)
        let identifier = try XCTUnwrap(service.items.first?.thumbnailIdentifier)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Thumbnails").appendingPathComponent(identifier).path))
        XCTAssertEqual(try readLibraryStore(from: directory).items.first?.thumbnailIdentifier, identifier)
    }

    func testMigratesSchemaTwoLibraryWithoutRuntimeProfileToSchemaThree() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyItem = LibraryItem(url: directory.appendingPathComponent("legacy.swf"))
        try JSONEncoder().encode(LibraryStore(schemaVersion: 2, items: [legacyItem]))
            .write(to: directory.appendingPathComponent("library.json"))
        try JSONEncoder().encode(2).write(to: directory.appendingPathComponent("library.version"))

        let service = LibraryService(directory: directory, thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails")))
        let report = service.migrateIfNeeded()

        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertNil(service.items.first?.runtimeProfile)
        XCTAssertEqual(try readLibraryStore(from: directory).schemaVersion, 3)
        XCTAssertEqual(try readLibraryVersion(from: directory), 3)
    }

    func testCorruptLibraryDoesNotCrashAndReportsRecoveryFailure() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("library.json"))

        let service = LibraryService(directory: directory, thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails")))
        let report = service.migrateIfNeeded()

        XCTAssertTrue(service.items.isEmpty)
        XCTAssertFalse(report.failures.isEmpty)
        XCTAssertTrue(report.requiresUserAction)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func readLibraryStore(from directory: URL) throws -> LibraryStore {
        let data = try Data(contentsOf: directory.appendingPathComponent("library.json"))
        return try JSONDecoder().decode(LibraryStore.self, from: data)
    }

    private func readLibraryVersion(from directory: URL) throws -> Int {
        let data = try Data(contentsOf: directory.appendingPathComponent("library.version"))
        return try JSONDecoder().decode(Int.self, from: data)
    }

    private static let pngData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lTn5WQAAAABJRU5ErkJggg==")!
}
