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

    func testMigratesSchemaTwoLibraryWithoutRuntimeProfileToSchemaFour() throws {
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
        XCTAssertEqual(try readLibraryStore(from: directory).schemaVersion, 4)
        XCTAssertEqual(try readLibraryVersion(from: directory), 4)
    }

    func testMigratesSchemaThreeFixtureToSchemaFourAndNormalizesInputProfile() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let item = LibraryItem(
            url: directory.appendingPathComponent("legacy.swf"),
            inputProfile: InputProfile(version: 1, mapping: [.primary: 4])
        )
        try JSONEncoder().encode(LibraryStore(schemaVersion: 3, items: [item]))
            .write(to: directory.appendingPathComponent("library.json"))
        try JSONEncoder().encode(3).write(to: directory.appendingPathComponent("library.version"))

        let service = LibraryService(directory: directory, thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails")))

        let firstReport = service.migrateIfNeeded()
        let firstStore = try readLibraryStore(from: directory)
        let secondReport = service.migrateIfNeeded()
        let secondStore = try readLibraryStore(from: directory)

        XCTAssertTrue(firstReport.failures.isEmpty)
        XCTAssertTrue(secondReport.failures.isEmpty)
        XCTAssertEqual(firstStore.schemaVersion, 4)
        XCTAssertEqual(secondStore.schemaVersion, 4)
        XCTAssertEqual(service.items.first?.inputProfile?.version, 2)
        XCTAssertEqual(service.items.first?.inputProfile?.mapping[.primary], 4)
        XCTAssertEqual(firstStore.items, secondStore.items)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("library.json.schema-3.backup").path))
        XCTAssertEqual(try readLibraryVersion(from: directory), 4)
    }

    func testMigrationWriteFailureDoesNotAdvanceSchemaVersion() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let libraryURL = directory.appendingPathComponent("library.json", isDirectory: true)
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: false)

        let service = LibraryService(directory: directory, thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails")))
        let report = service.migrateIfNeeded()

        XCTAssertTrue(report.failures.contains { $0.store == "library.json" })
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("library.version").path))
    }

    func testSchemaFourPersistsNewLibraryConfigurationFields() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let assessment = PersistedCompatibilityAssessment(
            status: .compatible,
            inputFingerprint: "input",
            engineBuildIdentifier: "engine",
            appBuildIdentifier: "app",
            isCompleteObservation: true
        )
        let item = LibraryItem(
            url: directory.appendingPathComponent("configured.swf"),
            inputProfile: InputProfile(version: 2, mapping: [.primary: 7]),
            gameStoragePreferences: GameStoragePreferences(automaticBackupEnabled: false),
            compatibilityAssessment: assessment
        )
        try JSONEncoder().encode(LibraryStore(schemaVersion: 4, items: [item]))
            .write(to: directory.appendingPathComponent("library.json"))
        try JSONEncoder().encode(4).write(to: directory.appendingPathComponent("library.version"))

        let service = LibraryService(directory: directory, thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails")))

        XCTAssertEqual(service.items.first?.gameStoragePreferences?.automaticBackupEnabled, false)
        XCTAssertEqual(service.items.first?.compatibilityAssessment?.status, .compatible)
        XCTAssertEqual(service.items.first?.compatibilityAssessment?.schemaVersion, 1)
        XCTAssertEqual(service.items.first?.inputProfile?.mapping[.primary], 7)
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
