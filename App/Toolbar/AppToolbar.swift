import SwiftUI
import UniformTypeIdentifiers

struct AppToolbar: ToolbarContent {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            sidebarButton
        }

        ToolbarItemGroup(placement: .primaryAction) {
            importMenu
            settingsButton
        }
    }

    // MARK: - Import Menu

    private var sidebarButton: some View {
        Button {
            withAnimation(.default) {
                appState.toggleSidebar()
            }
        } label: {
            Label(locManager.localized("toolbar.showSidebar"), systemImage: "sidebar.left")
        }
        .help(appState.sidebarCollapsed
              ? locManager.localized("toolbar.showSidebar")
              : locManager.localized("toolbar.hideSidebar"))
        .keyboardShortcut("s", modifiers: [.command, .control])
    }

    private var importMenu: some View {
        Menu {
            Button { showOpenPanel() } label: {
                Label(locManager.localized("toolbar.openSwf"), systemImage: "doc")
            }
            Button { showImportFolderPanel() } label: {
                Label(locManager.localized("toolbar.importFolder"), systemImage: "folder")
            }
        } label: {
            Label(locManager.localized("toolbar.importHelp"), systemImage: "plus")
        }
        .help(locManager.localized("toolbar.importHelp"))
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button {
            appState.selectedSection = .settings
        } label: {
            Label(locManager.localized("toolbar.settings"), systemImage: "gearshape")
        }
        .help(locManager.localized("toolbar.settings"))
        .keyboardShortcut(",", modifiers: .command)
    }

    // MARK: - Panel Helpers

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "swf")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.message = locManager.localized("workspace.openPanel.message")
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.openFile(url)
        }
    }

    private func showImportFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = locManager.localized("library.chooseFolder.message")
        if panel.runModal() == .OK, let url = panel.url {
            appState.browseDirectory(url)
        }
    }
}

#Preview("Toolbar") {
    Text("Preview not available for ToolbarContent")
        .frame(width: 600, height: 44)
}
