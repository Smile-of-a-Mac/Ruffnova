import CryptoKit
import XCTest
@testable import Ruffnova

final class SharedObjectSnapshotServiceTests: XCTestCase {
    private var rootURL: URL!
    private var paths: SharedObjectStoragePaths!
    private var storageService: GameStorageService!
    private var snapshotService: SharedObjectSnapshotService!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        paths = SharedObjectStoragePaths(rootURL: rootURL.appendingPathComponent("SharedObjects", isDirectory: true))
        storageService = GameStorageService(paths: paths)
        snapshotService = SharedObjectSnapshotService(storageService: storageService, paths: paths)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func testCreatesAndVerifiesSnapshotOfAllStorageEntries() throws {
        let libraryID = UUID()
        try storageService.replace(Data("progress".utf8), named: "game/progress", for: libraryID)
        try storageService.replace(Data(), named: "game/empty", for: libraryID)

        let snapshot = try snapshotService.createSnapshot(for: libraryID)

        XCTAssertEqual(snapshot.libraryID, libraryID)
        XCTAssertEqual(snapshot.entries.map(\.name), ["game/empty", "game/progress"])
        XCTAssertEqual(snapshot.totalBytes, Int64(Data("progress".utf8).count))
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshot.directoryURL.appendingPathComponent("manifest.json").path))
        XCTAssertEqual(try snapshotService.verifySnapshot(snapshot), snapshot)
    }

    func testSnapshotsAreIsolatedByLibraryID() throws {
        let firstLibraryID = UUID()
        let secondLibraryID = UUID()
        try storageService.replace(Data("first".utf8), named: "save", for: firstLibraryID)
        try storageService.replace(Data("second".utf8), named: "save", for: secondLibraryID)

        let firstSnapshot = try snapshotService.createSnapshot(for: firstLibraryID)
        let secondSnapshot = try snapshotService.createSnapshot(for: secondLibraryID)

        XCTAssertEqual(snapshotService.snapshots(for: firstLibraryID).map(\.id), [firstSnapshot.id])
        XCTAssertEqual(snapshotService.snapshots(for: secondLibraryID).map(\.id), [secondSnapshot.id])
    }

    func testRestoresAssignedSlotAndRemovesExtraActiveEntries() throws {
        let libraryID = UUID()
        try storageService.replace(Data("first".utf8), named: "game/progress", for: libraryID)
        try storageService.replace(Data(), named: "game/empty", for: libraryID)
        let snapshot = try snapshotService.saveCurrentStorage(to: .one, for: libraryID)

        try storageService.replace(Data("changed".utf8), named: "game/progress", for: libraryID)
        try storageService.replace(Data("obsolete".utf8), named: "obsolete", for: libraryID)

        try snapshotService.restore(slot: .one, for: libraryID)

        XCTAssertEqual(try storageService.read("game/progress", for: libraryID), Data("first".utf8))
        XCTAssertEqual(try storageService.read("game/empty", for: libraryID), Data())
        XCTAssertEqual(try storageService.entries(for: libraryID).map(\.name), ["game/empty", "game/progress"])
        XCTAssertEqual(try snapshotService.snapshot(in: .one, for: libraryID).id, snapshot.id)
    }

    func testRestoringEmptySlotFailsWithoutChangingActiveStorage() throws {
        let libraryID = UUID()
        try storageService.replace(Data("current".utf8), named: "save", for: libraryID)

        XCTAssertThrowsError(try snapshotService.restore(slot: .one, for: libraryID)) { error in
            XCTAssertEqual(error as? SharedObjectSnapshotError, .slotIsEmpty)
        }
        XCTAssertEqual(try storageService.read("save", for: libraryID), Data("current".utf8))
    }

    func testTamperedSnapshotIsNotListedAndFailsVerification() throws {
        let libraryID = UUID()
        try storageService.replace(Data("progress".utf8), named: "save", for: libraryID)
        let snapshot = try snapshotService.createSnapshot(for: libraryID)

        let objectURL = snapshot.directoryURL
            .appendingPathComponent("objects", isDirectory: true)
            .appendingPathComponent(Self.digest(for: Data(snapshot.entries[0].name.utf8)))
        try Data("tampered".utf8).write(to: objectURL, options: .atomic)

        XCTAssertThrowsError(try snapshotService.verifySnapshot(snapshot))
        XCTAssertTrue(snapshotService.snapshots(for: libraryID).isEmpty)
    }

    private static func digest(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testSnapshotDirectoryDoesNotExposeOriginalEntryPath() throws {
        let libraryID = UUID()
        let entryName = "example.com/game/save"
        try storageService.replace(Data("progress".utf8), named: entryName, for: libraryID)

        let snapshot = try snapshotService.createSnapshot(for: libraryID)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: snapshot.directoryURL.appendingPathComponent("objects").appendingPathComponent(entryName).path
        ))
    }
}
