// AppDelegate — Handles application lifecycle and macOS-specific integration.

import Cocoa
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = nil
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        configureOpenWindows()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure any pending state is saved
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(self)
                return true
            }
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.pathExtension.lowercased() == "swf" else { continue }
            NotificationCenter.default.post(
                name: .openSWFFile,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }

    @objc private func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        configure(window)
    }

    private func configureOpenWindows() {
        DispatchQueue.main.async { [weak self] in
            NSApp.windows.forEach { self?.configure($0) }
        }
    }

    private func configure(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.hasShadow = true
    }
}
