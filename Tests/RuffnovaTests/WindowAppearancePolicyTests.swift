#if os(macOS)
import AppKit
import XCTest
@testable import Ruffnova

final class WindowAppearancePolicyTests: XCTestCase {
    func testConfiguresApplicationWindows() {
        let window = NSWindow()
        window.identifier = NSUserInterfaceItemIdentifier("SwiftUI.WindowGroup-Ruffnova-1-AppWindow-1")

        XCTAssertTrue(WindowAppearancePolicy.shouldConfigure(window))
    }

    func testDoesNotConfigureWindowsWithoutAnIdentifier() {
        let window = NSWindow()

        XCTAssertFalse(WindowAppearancePolicy.shouldConfigure(window))
    }

    func testDoesNotConfigureSystemPanels() {
        let panel = NSPanel()

        XCTAssertFalse(WindowAppearancePolicy.shouldConfigure(panel))
    }

    func testDoesNotConfigureTheSettingsWindow() {
        let window = NSWindow()
        window.identifier = NSUserInterfaceItemIdentifier("com.apple.SwiftUI.Settings_window")

        XCTAssertFalse(WindowAppearancePolicy.shouldConfigure(window))
    }
}
#endif
