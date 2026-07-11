#if os(macOS)
import AppKit

enum WindowAppearancePolicy {
    static func shouldConfigure(_ window: NSWindow) -> Bool {
        !(window is NSPanel)
    }
}
#endif
