import XCTest
@testable import Ruffnova

final class LibraryRemovalPolicyTests: XCTestCase {
    func testClosesPlayerWhenRemovingCurrentLibraryItem() {
        let url = URL(fileURLWithPath: "/tmp/current.swf")
        let item = LibraryItem(url: url)

        XCTAssertTrue(LibraryRemovalPolicy.shouldClosePlayer(currentFileURL: url, removing: item))
    }

    func testKeepsPlayerOpenWhenRemovingDifferentLibraryItem() {
        let currentURL = URL(fileURLWithPath: "/tmp/current.swf")
        let item = LibraryItem(url: URL(fileURLWithPath: "/tmp/other.swf"))

        XCTAssertFalse(LibraryRemovalPolicy.shouldClosePlayer(currentFileURL: currentURL, removing: item))
    }
}
