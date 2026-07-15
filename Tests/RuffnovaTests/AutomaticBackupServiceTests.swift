import XCTest
@testable import Ruffnova

final class AutomaticBackupServiceTests: XCTestCase {
    private var rootURL: URL!
    private var paths: SharedObjectStoragePaths!
    private var storageService: GameStorageService!
    private var snapshotService: SharedObjectSnapshotService!
    private var backupService: AutomaticBackupService!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        paths = SharedObjectStoragePaths(rootURL: rootURL.appendingPathComponent("SharedObjects", isDirectory: true))
        storageService = GameStorageService(paths: paths)
        snapshotService = SharedObjectSnapshotService(storageService: storageService, paths: paths)
        backupService = AutomaticBackupService(snapshotService: snapshotService)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func testCreatesAutomaticSnapshotOnlyAfterStorageChanges() async throws {
        let libraryID = UUID()
        try storageService.replace(Data("first".utf8), named: "save", for: libraryID)

        let firstResult = try await backupService.createIfNeeded(for: libraryID)

        guard case let .created(firstSnapshot) = firstResult else {
            return XCTFail("Expected an automatic snapshot")
        }
        XCTAssertEqual(firstSnapshot.kind, .automatic)
        XCTAssertEqual(snapshotService.automaticSnapshots(for: libraryID).map(\.id), [firstSnapshot.id])
        let unchangedResult = try await backupService.createIfNeeded(for: libraryID)
        XCTAssertEqual(unchangedResult, .unchanged)

        try storageService.replace(Data("second".utf8), named: "save", for: libraryID)

        guard case let .created(secondSnapshot) = try await backupService.createIfNeeded(for: libraryID) else {
            return XCTFail("Expected a changed storage snapshot")
        }
        XCTAssertNotEqual(secondSnapshot.id, firstSnapshot.id)
        XCTAssertEqual(snapshotService.automaticSnapshots(for: libraryID).count, 2)
    }
}
