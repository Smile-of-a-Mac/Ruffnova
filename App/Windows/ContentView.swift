// ContentView — macOS glass-based main application view.
// Window glass is the foundation. Sidebar blends in. Content floats above.
// Toolbar is invisible. Only floating controls exist.

import Combine
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @State private var isDropTargeted = false

    private enum PresentedSheet: String, Identifiable {
        case swfInfo
        case traceConsole
        case diagnostics

        var id: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            if !appState.sidebarCollapsed && !appState.isStageMaximized {
                AppSidebar()
                    .environmentObject(appState)
                    .environmentObject(locManager)
                    .frame(width: 240)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
                    .opacity(0.35)
            }

            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, minHeight: 480)
        .glassWindowBase()
        .animation(.glassSpring, value: appState.sidebarCollapsed)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !appState.isStageMaximized {
                StatusBarView()
                    .environmentObject(appState)
            }
        }
        .toolbar {
            AppToolbar(refreshToken: appState.toolbarRefreshToken)
        }
        #if os(macOS)
        .toolbar(appState.isStageMaximized ? .hidden : .visible, for: .windowToolbar)
        #endif
        .onDrop(of: [.fileURL, .folder].compactMap { $0 }, isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSWFFile)) { n in
            if let url = n.userInfo?["url"] as? URL { appState.openFile(url) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewportChanged)) { n in
            guard let i = n.userInfo,
                  let w = i["width"] as? UInt32, let h = i["height"] as? UInt32,
                  let s = i["scaleFactor"] as? Float,
                  w >= 16, h >= 16
            else { return }
            DispatchQueue.main.async { appState.bridge?.setViewport(width: w, height: h, scaleFactor: s) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyEvent)) { n in
            guard let i = n.userInfo,
                  let kc = i["keyCode"] as? UInt32, let cc = i["charCode"] as? UInt32,
                  let dn = i["isDown"] as? Bool, let mod = i["modifiers"] as? UInt else { return }
            appState.routePhysicalKeyboardEvent(physicalHID: kc, charCode: cc, isDown: dn, modifiers: UInt32(mod))
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSWFInfo)) { _ in
            appState.showSWFInfoPanel.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTraceConsole)) { _ in
            appState.showTraceConsole.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .importFolder)) { _ in
            #if os(macOS)
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.message = locManager.localized("library.chooseFolder.message")
            panel.prompt = locManager.localized("library.chooseFolder")

            if panel.runModal() == .OK, let url = panel.url {
                appState.browseDirectory(url)
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            appState.requestSearchFocus()
        }
        .sheet(item: presentedSheet) { sheet in
            switch sheet {
            case .swfInfo:
                SWFInfoPanel()
                    .environmentObject(appState)
                    .frame(width: 280, height: 300)
            case .traceConsole:
                TraceConsoleView()
                    .environmentObject(locManager)
                    .frame(width: 500, height: 400)
            case .diagnostics:
                DiagnosticsView()
                    .environmentObject(appState)
                    .environmentObject(locManager)
                .frame(width: 560, height: 560)
            }
        }
        .sheet(isPresented: libraryDetailsPresented) {
            if let itemID = appState.libraryDetailsItemID {
                LibraryItemDetailsView(itemID: itemID, initialSection: appState.libraryDetailsSection)
                    .environmentObject(appState)
                    .environmentObject(locManager)
            }
        }
        .alert(permissionPromptTitle, isPresented: permissionPromptPresented) {
            Button(locManager.localized("permission.allowOnce")) {
                appState.resolvePendingPermission(with: .allowOnce)
            }
            Button(locManager.localized("permission.allowForFile")) {
                appState.resolvePendingPermission(with: .allowForFile)
            }
            Button(locManager.localized("permission.denyForFile"), role: .destructive) {
                appState.resolvePendingPermission(with: .denyForFile)
            }
            Button(locManager.localized("collection.cancel"), role: .cancel) {
                appState.pendingPermissionRequest = nil
            }
        } message: {
            Text(permissionPromptMessage)
        }
    }

    private var presentedSheet: Binding<PresentedSheet?> {
        Binding(
            get: {
                if appState.showDiagnostics { return .diagnostics }
                if appState.showTraceConsole { return .traceConsole }
                if appState.showSWFInfoPanel { return .swfInfo }
                return nil
            },
            set: { newValue in
                appState.showSWFInfoPanel = newValue == .swfInfo
                appState.showTraceConsole = newValue == .traceConsole
                appState.showDiagnostics = newValue == .diagnostics
            }
        )
    }

    private var permissionPromptPresented: Binding<Bool> {
        Binding(
            get: { appState.pendingPermissionRequest != nil },
            set: { isPresented in
                if !isPresented {
                    appState.pendingPermissionRequest = nil
                }
            }
        )
    }

    private var libraryDetailsPresented: Binding<Bool> {
        Binding(
            get: { appState.libraryDetailsItemID != nil },
            set: { isPresented in
                if !isPresented {
                    appState.libraryDetailsItemID = nil
                }
            }
        )
    }

    private var permissionPromptTitle: String {
        guard let request = appState.pendingPermissionRequest else {
            return locManager.localized("permission.prompt.title")
        }
        switch request.scope {
        case .network:
            return locManager.localized("permission.prompt.network.title")
        case .filesystem:
            return locManager.localized("permission.prompt.filesystem.title")
        }
    }

    private var permissionPromptMessage: String {
        guard let request = appState.pendingPermissionRequest else { return "" }
        let fileName = request.fileURL?.lastPathComponent ?? locManager.localized("diagnostics.unavailable")
        let resource = request.requestedResource ?? locManager.localized("permission.prompt.resource.unspecified")
        switch request.scope {
        case .network:
            return String(format: locManager.localized("permission.prompt.network.message"), fileName, resource)
        case .filesystem:
            return String(format: locManager.localized("permission.prompt.filesystem.message"), fileName, resource)
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        ZStack {
            if appState.isSearching && !appState.searchText.isEmpty {
                searchResultsView
            } else if appState.isPlayerVisible {
                playerView
            } else if appState.selectedSection == .player {
                playerEmptyState
            } else {
                LibraryContentView(isDropTargeted: $isDropTargeted)
                    .environmentObject(appState)
                    .environmentObject(locManager)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search Results

    private var searchViewModel: SearchViewModel { appState.searchViewModel }

    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
            VStack(alignment: .leading, spacing: NativeSpacing.sm) {
                Text(locManager.localized("search.results"))
                    .font(.largeTitle)
                Text(String(format: locManager.localized("search.results.count"), searchViewModel.searchResults.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, NativeSpacing.section)
            .padding(.top, NativeSpacing.section)

            if searchViewModel.searchResults.isEmpty {
                emptySearchState
            } else {
                ScrollView {
                    LazyVStack(spacing: NativeSpacing.sm) {
                        ForEach(searchViewModel.searchResults) { file in
                            SearchRow(item: file, viewModel: searchViewModel)
                        }
                    }
                    .padding(.horizontal, NativeSpacing.xxxl)
                    .padding(.bottom, NativeSpacing.xxl)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySearchState: some View {
        VStack(spacing: NativeSpacing.xl) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.quaternary)
            Text(locManager.localized("search.noResults"))
                .font(.title)
            Text(String(format: locManager.localized("search.noResults.match"), appState.searchText))
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: NativeSpacing.md) {
                Button {
                    appState.clearSearch()
                } label: {
                    Text(locManager.localized("search.clear"))
                }
                .buttonStyle(.bordered)

                Button {
                    NotificationCenter.default.post(name: .importFolder, object: nil)
                } label: {
                    Text(locManager.localized("empty.importFolder"))
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private struct SearchRow: View {
        let item: LibraryItem
        let viewModel: SearchViewModel

        var body: some View {
            Button {
                viewModel.openResult(item)
            } label: {
                HStack(spacing: NativeSpacing.md) {
                    Image(systemName: item.isFavorite ? "star.fill" : "doc")
                        .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                        Text(item.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(item.url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if !item.tags.isEmpty {
                        Text(item.tags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, NativeSpacing.md)
                .padding(.vertical, NativeSpacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Player View

    private var playerEmptyState: some View {
        VStack(spacing: NativeSpacing.xl) {
            Image(systemName: "play.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(spacing: NativeSpacing.sm) {
                Text(locManager.localized("player.nowPlaying"))
                    .font(.largeTitle)
                Text(locManager.localized("workspace.dropMessage"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var platformBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    private var playerView: some View {
        ZStack {
            Color.clear
                .background(platformBackground)
                .ignoresSafeArea()

            if appState.isStageMaximized {
                Color.black
                    .ignoresSafeArea()

                playerStage
                    .ignoresSafeArea()

                if shouldShowPlayerChrome {
                    playerTitleBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.trailing, NativeSpacing.md)
                        .padding(.top, NativeSpacing.md)
                }

                if shouldShowPlayerControls {
                    VStack {
                        Spacer()
                        PlayerControlBar()
                            .environmentObject(appState)
                            .padding(.horizontal, NativeSpacing.xxxl)
                            .padding(.bottom, NativeSpacing.xl)
                    }
                }
            } else if appState.swfContentType == .interactive {
                VStack(spacing: 0) {
                    playerStage
                        .overlay(alignment: .topTrailing) {
                            if shouldShowPlayerChrome || appState.playerMode == .normal {
                                playerTitleBadge
                                    .padding(.top, NativeSpacing.sm)
                                    .padding(.trailing, NativeSpacing.sm)
                            }
                        }
                        .layoutPriority(1)

                    if shouldShowPlayerControls {
                        PlayerControlBar()
                            .environmentObject(appState)
                            .padding(.vertical, NativeSpacing.md)
                    }
                }
            } else {
                playerStage
                    .onHover { hovering in
                        if hovering { appState.handlePlayerPointerActivity() }
                    }

                if shouldShowPlayerControls {
                    VStack {
                        Spacer()
                        PlayerControlBar()
                            .environmentObject(appState)
                            .padding(.horizontal, NativeSpacing.xxxl)
                            .padding(.bottom, NativeSpacing.xl)
                    }
                }

                if shouldShowPlayerChrome || appState.playerMode == .normal {
                    playerTitleBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.trailing, NativeSpacing.xl)
                        .padding(.top, 56)
                }
            }

            if appState.showDebugUI {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        DebugOverlayView()
                            .environmentObject(appState)
                            .environmentObject(locManager)
                            .padding(NativeSpacing.md)
                    }
                }
            }

            if appState.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(GlassMaterial.light)
            }

            if let err = appState.errorMessage {
                VStack {
                    Spacer()
                    errorToast(err)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .onExitCommand {
            appState.handlePlayerEscape()
        }
        #endif
    }

    private var shouldShowPlayerChrome: Bool {
        appState.showToolbar && appState.showControlBar && appState.currentFileURL != nil
    }

    private var shouldShowPlayerControls: Bool {
        shouldShowPlayerChrome && appState.playerMode != .game
    }

    private var playerTitleBadge: some View {
        HStack(spacing: NativeSpacing.sm) {
            Text(appState.currentFileURL?.lastPathComponent ?? "")
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Button {
                if let url = appState.currentFileURL {
                    appState.toggleFavorite(for: url)
                }
            } label: {
                Image(systemName: appState.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundStyle(.tint)
                    .opacity(appState.isFavorite ? 1.0 : 0.3)
            }
            .buttonStyle(.plain)

            Button {
                if appState.isStageMaximized {
                    appState.exitStageMaximized()
                } else {
                    appState.toggleStageMaximized()
                }
            } label: {
                Image(systemName: appState.isStageMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            PlayerModeMenu()
                .environmentObject(appState)
                .environmentObject(locManager)
        }
        .padding(.horizontal, NativeSpacing.md)
        .padding(.vertical, NativeSpacing.xs)
        .background(GlassMaterial.ultraLight, in: Capsule())
    }

    // MARK: - Player Stage

    private var playerStage: some View {
        GeometryReader { geo in
            RufflePlayerView()
                .environmentObject(appState)
                .aspectRatio(
                    CGFloat(appState.stageWidth) / CGFloat(max(appState.stageHeight, 1)),
                    contentMode: .fit
                )
                .clipShape(RoundedRectangle(cornerRadius: appState.isStageMaximized ? 0 : NativeRadius.sm, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, appState.isStageMaximized ? 0 : max(NativeSpacing.sm, (geo.size.width - geo.size.height * CGFloat(appState.stageWidth) / CGFloat(max(appState.stageHeight, 1))) / 2))
                .padding(.vertical, appState.isStageMaximized ? 0 : NativeSpacing.sm)
                .onHover { hovering in
                    if hovering { appState.handlePlayerPointerActivity() }
                }
        }
    }

    // MARK: - Error Toast

    private func errorToast(_ msg: String) -> some View {
        HStack(spacing: NativeSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(msg).font(.callout)
            Spacer()
            if !appState.playerIssues.isEmpty {
                Button(locManager.localized("diagnostics.openDetails")) {
                    appState.openCurrentFileDetails(section: .compatibility)
                }
                .controlSize(.small)
            }
            Button(locManager.localized("menu.reload")) {
                appState.retryCurrentFile()
            }
            .controlSize(.small)
            .disabled(appState.currentFileURL == nil)
            Button(locManager.localized("menu.backToWorkspace")) {
                appState.closeFile()
            }
            .controlSize(.small)
            Button(locManager.localized("player.dismiss")) { appState.errorMessage = nil }
                .controlSize(.small)
        }
        .padding(NativeSpacing.lg)
        .background(GlassMaterial.light, in: Capsule())
        .padding()
    }

    // MARK: - Drop Handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var hasSupported = false
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                hasSupported = true
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let d = data as? Data,
                          let url = URL(dataRepresentation: d, relativeTo: nil) else { return }

                    do {
                        let importedContent = try ImportService.shared.resolveImport(for: url)
                        DispatchQueue.main.async { appState.openImportedContent(importedContent) }
                    } catch {
                        DispatchQueue.main.async { appState.presentImportError(error) }
                    }
                }
            }
        }
        return hasSupported
    }
}

#Preview("Content") {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
}
