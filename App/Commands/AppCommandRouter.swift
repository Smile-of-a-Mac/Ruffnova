import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

@MainActor
enum AppCommandRouter {
    static func openFile(appState: AppState, loc: LocalizationManager) {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "swf")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = loc.localized("workspace.openPanel.title")
        panel.message = loc.localized("workspace.openPanel.message")

        if panel.runModal() == .OK, let url = panel.url {
            appState.openFile(url)
        }
        #elseif os(iOS)
        appState.showFilePicker()
        #endif
    }

    static func importFolder(appState: AppState, loc: LocalizationManager) {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = loc.localized("library.chooseFolder.message")
        panel.prompt = loc.localized("library.chooseFolder")
        if panel.runModal() == .OK, let url = panel.url {
            appState.browseDirectory(url)
        }
        #elseif os(iOS)
        appState.showFolderPicker()
        #endif
    }

    static func reloadCurrentFile(appState: AppState) {
        guard let url = appState.currentFileURL else { return }
        appState.openFile(url)
    }

    static func closeCurrentFile(appState: AppState) {
        appState.closeFile()
    }

    static func toggleFavorite(appState: AppState) {
        guard let url = appState.currentFileURL else { return }
        appState.toggleFavorite(for: url)
    }

    static func showCurrentFileInFinder(appState: AppState) {
        #if os(macOS)
        guard let url = appState.currentFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

    static func focusSearch(appState: AppState) {
        appState.requestSearchFocus()
    }

    static func showSWFInfo(appState: AppState) {
        appState.showSWFInfoPanel = true
    }

    static func showDiagnostics(appState: AppState) {
        appState.showDiagnostics = true
    }

    static func toggleTraceConsole(appState: AppState) {
        appState.showTraceConsole.toggle()
    }

    static func saveScreenshot(appState: AppState) {
        appState.saveScreenshot()
    }

    static func copyScreenshot(appState: AppState) {
        appState.copyScreenshot()
    }

    static func enterGameMode(appState: AppState) {
        appState.setPlayerMode(.game)
    }

    static func exitGameMode(appState: AppState) {
        appState.setPlayerMode(.normal)
    }

    static func showAbout(loc: LocalizationManager) {
        #if os(macOS)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = loc.localized("menu.about")
        window.contentView = NSHostingView(
            rootView: InlineSettingsView(initialCategory: .about)
                .environmentObject(LocalizationManager.shared)
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        #endif
    }

    static func openHelp() {
        #if os(macOS)
        if let url = URL(string: "https://ruffle.rs") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    static func reportIssue() {
        #if os(macOS)
        if let url = URL(string: "https://github.com/ruffle-rs/ruffle/issues") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}
