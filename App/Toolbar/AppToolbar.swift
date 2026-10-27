import SwiftUI

struct AppToolbar: ToolbarContent {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            importMenu
            settingsButton
        }
    }

    // MARK: - Import Menu

    private var importMenu: some View {
        Menu {
            Button { AppCommandRouter.openFile(appState: appState) } label: {
                Label(locManager.localized("toolbar.openSwf"), systemImage: "doc")
            }
            Button { AppCommandRouter.importFolder(appState: appState) } label: {
                Label(locManager.localized("toolbar.importFolder"), systemImage: "folder")
            }
        } label: {
            Label(locManager.localized("toolbar.importHelp"), systemImage: "plus")
        }
        .help(locManager.localized("toolbar.importHelp"))
    }

    // MARK: - Settings Button

    @ViewBuilder
    private var settingsButton: some View {
        #if os(macOS)
        SettingsLink {
            Label(locManager.localized("toolbar.settings"), systemImage: "gearshape")
        }
        .help(locManager.localized("toolbar.settings"))
        #else
        Button {
            appState.selectedSection = .settings
        } label: {
            Label(locManager.localized("toolbar.settings"), systemImage: "gearshape")
        }
        .help(locManager.localized("toolbar.settings"))
        #endif
    }

}

#Preview("Toolbar") {
    Text("Preview not available for ToolbarContent")
        .frame(width: 600, height: 44)
}
