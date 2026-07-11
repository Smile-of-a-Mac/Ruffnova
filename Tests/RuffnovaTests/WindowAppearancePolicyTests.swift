#if os(macOS)
import AppKit
import XCTest
@testable import Ruffnova

final class WindowAppearancePolicyTests: XCTestCase {
    func testConfiguresApplicationWindows() {
        let window = NSWindow()

        XCTAssertTrue(WindowAppearancePolicy.shouldConfigure(window))
    }

    func testDoesNotConfigureSystemPanels() {
        let panel = NSPanel()

        XCTAssertFalse(WindowAppearancePolicy.shouldConfigure(panel))
    }
}
#endif
