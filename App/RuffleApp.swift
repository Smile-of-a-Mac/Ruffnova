// RuffleApp — macOS 26 Liquid Glass native frontend for the Ruffle Flash Player.
// Window glass is the foundation. Everything else layers above it.

import SwiftUI

@main
struct RuffleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var locManager = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(locManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1080, height: 720)
        .commands {
            RuffleCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(locManager)
                .frame(width: 900, height: 640)
        }
    }
}
