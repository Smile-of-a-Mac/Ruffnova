import SwiftUI

struct AppToolbar: ToolbarContent {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    let refreshToken: Int
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            sidebarButton
                .id(refreshToken)
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
    }

    private var importMenu: some View {
        Menu {
            Button { AppCommandRouter.openFile(appState: appState, loc: locManager) } label: {
                Label(locManager.localized("toolbar.openSwf"), systemImage: "doc")
            }
            Button { AppCommandRouter.importFolder(appState: appState, loc: locManager) } label: {
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
            #if os(macOS)
            openWindow(id: "ruffnova-settings")
            #else
            appState.selectedSection = .settings
            #endif
        } label: {
            Label(locManager.localized("toolbar.settings"), systemImage: "gearshape")
        }
        .help(locManager.localized("toolbar.settings"))
    }

}

#Preview("Toolbar") {
    Text("Preview not available for ToolbarContent")
        .frame(width: 600, height: 44)
}
