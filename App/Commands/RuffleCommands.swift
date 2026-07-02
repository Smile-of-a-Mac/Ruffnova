import SwiftUI
import UniformTypeIdentifiers

struct RuffleCommands: Commands {
    @ObservedObject var appState: AppState
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some Commands {
        // MARK: - File Menu
        CommandGroup(replacing: .newItem) {
            Button(loc.localized("menu.open")) {
                showOpenPanel()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button(loc.localized("menu.close")) {
                appState.closeFile()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(appState.currentFileURL == nil)

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
                appState.saveScreenshot()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(appState.currentFileURL == nil)

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
                appState.setPlayerMode(.game)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(appState.currentFileURL == nil)
        }

        // MARK: - View Menu
        CommandGroup(before: .toolbar) {
            Button(loc.localized("search.placeholder")) {
                NotificationCenter.default.post(name: .focusSearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)

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
                NotificationCenter.default.post(name: .toggleSWFInfo, object: nil)
            }
            .disabled(appState.currentFileURL == nil)

            Button(loc.localized("menu.traceConsole")) {
                NotificationCenter.default.post(name: .toggleTraceConsole, object: nil)
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
                #if os(macOS)
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
                    styleMask: [.titled, .closable],
                    backing: .buffered, defer: false
                )
                window.title = loc.localized("menu.about")
                window.contentView = NSHostingView(rootView: AboutView().environmentObject(LocalizationManager.shared))
                window.center()
                window.isReleasedWhenClosed = false
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                #endif
            }

            Divider()

            Button(loc.localized("menu.help")) {
                #if os(macOS)
                if let url = URL(string: "https://ruffle.rs") {
                    NSWorkspace.shared.open(url)
                }
                #endif
            }

            Button(loc.localized("menu.reportIssue")) {
                #if os(macOS)
                if let url = URL(string: "https://github.com/ruffle-rs/ruffle/issues") {
                    NSWorkspace.shared.open(url)
                }
                #endif
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

    private func showOpenPanel() {
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
        #endif
    }
}
