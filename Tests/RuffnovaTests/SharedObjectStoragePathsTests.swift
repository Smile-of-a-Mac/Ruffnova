import XCTest
@testable import Ruffnova

final class SharedObjectStoragePathsTests: XCTestCase {
    func testSameLibraryIDUsesSameNamespace() {
        let root = URL(fileURLWithPath: "/tmp/RuffnovaTests")
        let paths = SharedObjectStoragePaths(rootURL: root)
        let libraryID = UUID(uuidString: "4FEC2E3A-02B5-4B89-AF33-7333B5B8E132")!

        XCTAssertEqual(paths.namespace(for: libraryID), paths.namespace(for: libraryID))
    }

    func testDistinctLibraryIDsAreIsolated() {
        let paths = SharedObjectStoragePaths(rootURL: URL(fileURLWithPath: "/tmp/RuffnovaTests"))

        XCTAssertNotEqual(paths.namespace(for: UUID()), paths.namespace(for: UUID()))
    }

    func testSnapshotStorageIsOutsideActiveSharedObjectStorage() {
        let paths = SharedObjectStoragePaths(rootURL: URL(fileURLWithPath: "/tmp/RuffleFlashPlayer/SharedObjects"))

        XCTAssertEqual(paths.snapshotRootURL, URL(fileURLWithPath: "/tmp/RuffleFlashPlayer/SharedObjectSnapshots", isDirectory: true))
        XCTAssertNotEqual(paths.snapshotNamespace(for: UUID()), paths.namespace(for: UUID()))
    }
}
