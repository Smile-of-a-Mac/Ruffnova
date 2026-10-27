#if os(macOS)
import AppKit

enum WindowAppearancePolicy {
    static func shouldConfigure(_ window: NSWindow) -> Bool {
        guard !(window is NSPanel) else { return false }

        // Only the app's own WindowGroup windows opt into the glass styling.
        // SwiftUI's Settings window has no identifier and manages its own title,
        // toolbar, and tab layout; forcing the main window's hidden title and
        // compact toolbar on it makes the title and tab icons jump between clicks.
        guard let identifier = window.identifier?.rawValue,
              identifier.contains("AppWindow") || identifier.contains("WindowGroup")
        else {
            return false
        }

        return true
    }
}
#endif
