import XCTest
@testable import Ruffnova

final class GameStorageServiceTests: XCTestCase {
    private var rootURL: URL!
    private var service: GameStorageService!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        service = GameStorageService(paths: SharedObjectStoragePaths(rootURL: rootURL))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func testListsReadsReplacesAndDeletesEntry() throws {
        let libraryID = UUID()
        try service.replace(Data("first".utf8), named: "example.com/game/save", for: libraryID)

        XCTAssertEqual(try service.entries(for: libraryID).map(\.name), ["example.com/game/save"])
        XCTAssertEqual(try service.read("example.com/game/save", for: libraryID), Data("first".utf8))

        try service.importData(Data("second".utf8), named: "example.com/game/save", for: libraryID)
        XCTAssertEqual(try service.read("example.com/game/save", for: libraryID), Data("second".utf8))

        try service.delete("example.com/game/save", for: libraryID)
        XCTAssertTrue(try service.entries(for: libraryID).isEmpty)
    }

    func testDoesNotExposeAnotherLibraryStorage() throws {
        try service.replace(Data("private".utf8), named: "save", for: UUID())

        XCTAssertTrue(try service.entries(for: UUID()).isEmpty)
    }

    func testReadsEmptyEntry() throws {
        let libraryID = UUID()
        try service.replace(Data(), named: "empty", for: libraryID)

        XCTAssertEqual(try service.read("empty", for: libraryID), Data())
    }

    func testRejectsParentDirectoryEntryName() {
        XCTAssertThrowsError(try service.replace(Data(), named: "../outside", for: UUID()))
    }
}
