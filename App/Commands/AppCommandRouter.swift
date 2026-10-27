import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
enum AppCommandRouter {
    static func openFile(appState: AppState) {
        Task { await appState.presentOpenFilePanel() }
    }

    static func importFolder(appState: AppState) {
        Task { await appState.presentFolderPicker() }
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
