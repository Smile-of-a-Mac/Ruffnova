import XCTest
@testable import Ruffnova

@MainActor
final class ImportWorkflowTests: XCTestCase {
    func testPreviewSeparatesNewAndDuplicateURLsUsingCanonicalIdentity() {
        let existing = URL(fileURLWithPath: "/tmp/library/game.swf")
        let duplicate = URL(fileURLWithPath: "/tmp/library/./game.swf")
        let newFile = URL(fileURLWithPath: "/tmp/library/other.swf")

        let preview = ImportPreview(candidates: [duplicate, newFile], existingURLs: [existing])

        XCTAssertEqual(preview.newURLs, [newFile])
        XCTAssertEqual(preview.duplicateURLs, [duplicate])
    }

    func testBulkImportAddsOnlyNewFilesAndSavesOnce() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = directory.appendingPathComponent("existing.swf")
        let newFile = directory.appendingPathComponent("new.swf")
        try Data("swf".utf8).write(to: existing)
        try Data("swf".utf8).write(to: newFile)
        let service = LibraryService(directory: directory, thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails")))
        service.add(LibraryItem(url: existing))

        let result = service.importFiles([existing, newFile])

        XCTAssertEqual(result.addedURLs, [newFile])
        XCTAssertEqual(result.duplicateURLs, [existing])
        XCTAssertEqual(service.items.count, 2)
    }

    func testSmartFiltersUseCurrentLibraryState() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = LibraryService(directory: directory, thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails")))
        let resumed = LibraryItem(url: directory.appendingPathComponent("resumed.swf"), lastPlaybackFrame: 5)
        let untagged = LibraryItem(url: directory.appendingPathComponent("untagged.swf"))
        let tagged = LibraryItem(url: directory.appendingPathComponent("tagged.swf"), tags: ["game"])
        service.add([resumed, untagged, tagged])

        XCTAssertEqual(service.filtered(by: .continuePlaying).map(\.id), [resumed.id])
        XCTAssertEqual(Set(service.filtered(by: .untagged).map(\.id)), Set([resumed.id, untagged.id]))
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
