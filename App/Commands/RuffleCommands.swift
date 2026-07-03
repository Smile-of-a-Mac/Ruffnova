import SwiftUI

struct RuffleCommands: Commands {
    @ObservedObject var appState: AppState
    @ObservedObject private var locManager = LocalizationManager.shared
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    private var loc: LocalizationManager { locManager }

    var body: some Commands {
        // MARK: - File Menu
        CommandGroup(replacing: .newItem) {
            Button(loc.localized("menu.open")) {
                AppCommandRouter.openFile(appState: appState, loc: loc)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button(loc.localized("toolbar.importFolder")) {
                AppCommandRouter.importFolder(appState: appState, loc: loc)
            }

            Divider()

            Button(loc.localized("menu.reload")) {
                AppCommandRouter.reloadCurrentFile(appState: appState)
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(appState.currentFileURL == nil)

            Button(loc.localized("menu.close")) {
                AppCommandRouter.closeCurrentFile(appState: appState)
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(appState.currentFileURL == nil)

            Button(appState.isFavorite ? loc.localized("favorites.remove") : loc.localized("favorites.add")) {
                AppCommandRouter.toggleFavorite(appState: appState)
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(appState.currentFileURL == nil)

            #if os(macOS)
            Button(loc.localized("menu.showInFinder")) {
                AppCommandRouter.showCurrentFileInFinder(appState: appState)
            }
            .disabled(appState.currentFileURL == nil)
            #endif

            Divider()

            Menu(loc.localized("menu.openRecent")) {
                if appState.recentFiles.isEmpty {
                    Text(loc.localized("menu.noRecent"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.recentFiles) { recent in
                        Button(recent.name) {
                            appState.openFile(recent.url)
                        }
                    }

                    Divider()

                    Button(loc.localized("menu.clearMenu")) {
                        appState.recentFiles.removeAll()
                    }
                }
            }
        }

        // MARK: - Edit Menu
        CommandGroup(replacing: .appSettings) {
            #if os(macOS)
            Button(loc.localized("menu.preferences")) {
                openWindow(id: "ruffnova-settings")
            }
            .keyboardShortcut(",", modifiers: .command)
            #endif
        }

        // MARK: - Control Menu
        CommandMenu(loc.localized("menu.control")) {
            Button(appState.isPlaying ? loc.localized("menu.pause") : loc.localized("menu.play")) {
                appState.togglePlayPause()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(appState.currentFileURL == nil)

            Button(loc.localized("menu.stepForward")) {
                appState.stepForward()
            }
            .keyboardShortcut(.space, modifiers: .command)
            .disabled(appState.currentFileURL == nil)

            Divider()

            Button(loc.localized("menu.mute")) {
                appState.toggleMute()
            }
            .keyboardShortcut("m", modifiers: .command)
            .disabled(appState.currentFileURL == nil)

            Divider()

            Button(loc.localized("menu.rewind")) {
                appState.rewind()
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .disabled(appState.currentFileURL == nil)

            Button(loc.localized("menu.stepBackward")) {
                appState.stepBackward()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
            .disabled(appState.currentFileURL == nil)

            Divider()

            Menu(loc.localized("menu.speed")) {
                ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0], id: \.self) { s in
                    Button(String(format: "%.2fx", s)) {
                        appState.setSpeed(Float(s))
                    }
                }
            }
            .disabled(appState.currentFileURL == nil)

            Toggle(loc.localized("menu.loop"), isOn: $appState.isLooping)
                .keyboardShortcut("l", modifiers: .command)
                .disabled(appState.currentFileURL == nil)

            Divider()

            Button(loc.localized("menu.saveScreenshot")) {
                AppCommandRouter.saveScreenshot(appState: appState)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(appState.currentFileURL == nil)

            #if os(macOS)
            Button(loc.localized("menu.copyScreenshot")) {
                AppCommandRouter.copyScreenshot(appState: appState)
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(appState.currentFileURL == nil)
            #endif

            Divider()

            Button(appState.isFullscreen ? loc.localized("menu.exitFullscreen") : loc.localized("menu.enterFullscreen")) {
                appState.toggleFullscreen()
            }
            .keyboardShortcut("f", modifiers: [.control, .command])
            .disabled(appState.currentFileURL == nil)

            Divider()

            Button(loc.localized("menu.playerMode.normal")) {
                appState.setPlayerMode(.normal)
            }
            .disabled(appState.currentFileURL == nil)

            Button(loc.localized("menu.playerMode.cinema")) {
                appState.setPlayerMode(.cinema)
            }
            .disabled(appState.currentFileURL == nil)

            Button(loc.localized("menu.playerMode.game")) {
                AppCommandRouter.enterGameMode(appState: appState)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(appState.currentFileURL == nil)

            Button(loc.localized("menu.exitGameMode")) {
                AppCommandRouter.exitGameMode(appState: appState)
            }
            .keyboardShortcut(.escape, modifiers: .command)
            .disabled(appState.currentFileURL == nil || appState.playerMode != .game)
        }

        // MARK: - View Menu
        CommandGroup(before: .toolbar) {
            Button(appState.sidebarCollapsed ? loc.localized("toolbar.showSidebar") : loc.localized("toolbar.hideSidebar")) {
                appState.toggleSidebar()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button(loc.localized("search.placeholder")) {
                AppCommandRouter.focusSearch(appState: appState)
            }
            .keyboardShortcut("f", modifiers: .command)

            Divider()

            Menu(loc.localized("menu.quality")) {
                qualityButton(loc.localized("menu.quality.low"), .low)
                qualityButton(loc.localized("menu.quality.medium"), .medium)
                qualityButton(loc.localized("menu.quality.high"), .high)
                qualityButton(loc.localized("menu.quality.best"), .best)
            }
            .disabled(appState.currentFileURL == nil)

            Divider()

            Toggle(loc.localized("menu.showControls"), isOn: $appState.showToolbar)
                .keyboardShortcut("t", modifiers: [.command, .option])

            Toggle(loc.localized("menu.showDebugUI"), isOn: $appState.showDebugUI)
                .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            Button(loc.localized("menu.swfInfo")) {
                AppCommandRouter.showSWFInfo(appState: appState)
            }
            .disabled(appState.currentFileURL == nil)

            Button(loc.localized("diagnostics.title")) {
                AppCommandRouter.showDiagnostics(appState: appState)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(appState.currentFileURL == nil)

            Button(loc.localized("menu.traceConsole")) {
                AppCommandRouter.toggleTraceConsole(appState: appState)
            }
        }

        // MARK: - Window Menu
        CommandGroup(replacing: .windowSize) {
            Button(loc.localized("menu.backToWorkspace")) {
                appState.closeFile()
            }
            .disabled(appState.currentFileURL == nil)
        }

        // MARK: - Help Menu
        CommandGroup(replacing: .help) {
            Button(loc.localized("menu.about")) {
                AppCommandRouter.showAbout(loc: loc)
            }

            Divider()

            Button(loc.localized("menu.help")) {
                AppCommandRouter.openHelp()
            }

            Button(loc.localized("menu.reportIssue")) {
                AppCommandRouter.reportIssue()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func qualityButton(_ label: String, _ quality: RuffleQuality) -> some View {
        if appState.quality == quality {
            Button(label) {
                appState.quality = quality
            }
            .foregroundStyle(.tint)
        } else {
            Button(label) {
                appState.quality = quality
            }
        }
    }
}
