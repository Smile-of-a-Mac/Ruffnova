// RuffleApp — Universal app entry point for macOS and iOS.
// Window glass is the foundation on macOS. Content-first on iOS.

import SwiftUI

@main
struct RuffleApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) var appDelegate
    #endif

    @StateObject private var appState = AppState()
    @StateObject private var locManager = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            ContentView()
                .environmentObject(appState)
                .environmentObject(locManager)
            #elseif os(iOS)
            IOSContentView()
                .environmentObject(appState)
                .environmentObject(locManager)
                .onOpenURL { url in
                    guard url.pathExtension.lowercased() == "swf" else { return }
                    appState.openFile(url)
                }
            #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1080, height: 720)
        .commands {
            RuffleCommands(appState: appState)
        }
        #endif

        #if os(macOS)
        WindowGroup("Settings", id: "ruffnova-settings") {
            InlineSettingsView()
                .environmentObject(appState)
                .environmentObject(locManager)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 580, height: 480)
        #endif
    }
}
