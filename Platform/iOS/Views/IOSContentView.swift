// IOSContentView — iOS/iPadOS main application view.
// TabView for iPhone, NavigationSplitView for iPad.

#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IOSContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var libraryService = LibraryService.shared
    @Namespace private var playerNamespace
    @State private var selectedIPadSection: AppState.Section? = .library
    @State private var iPadColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var hidesStageSystemChrome = false
    @State private var showingCollectionsSheet = false

    private let iPadSections: [AppState.Section] = [.recent, .library, .player, .favorites, .settings]

    private var hasLibrarySearchContent: Bool {
        !libraryService.items.isEmpty
    }

    private var hasRecentSearchContent: Bool {
        libraryService.sorted(by: .lastOpened).contains { $0.availabilityStatus == .available }
    }

    private var hasFavoriteSearchContent: Bool {
        libraryService.items.contains { $0.isFavorite }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onAppear {
            appState.handleScenePhaseChanged(scenePhase)
            appState.setPlayerSurfaceVisible(appState.isPlayerVisible)
            hidesStageSystemChrome = appState.isStageMaximized
        }
        .onChange(of: scenePhase) { _, phase in
            appState.handleScenePhaseChanged(phase)
        }
        .onChange(of: appState.isStageMaximized) { _, maximized in
            syncStageSystemChrome(for: maximized)
        }
        .sheet(isPresented: $showingCollectionsSheet) {
            collectionsSheet
        }
        .sheet(isPresented: $appState.showDiagnostics) {
            DiagnosticsView()
                .environmentObject(appState)
                .environmentObject(locManager)
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
        .statusBarHidden(hidesStageSystemChrome)
    }

    // MARK: - iPad Layout (NavigationSplitView)

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $iPadColumnVisibility) {
            iPadSidebar
        } detail: {
            iPadDetailContent(for: appState.selectedSection)
                .id(appState.selectedSection)
        }
        .onAppear {
            selectedIPadSection = appState.selectedCollectionID == nil ? appState.selectedSection : nil
            iPadColumnVisibility = appState.isStageMaximized ? .detailOnly : .all
        }
        .onChange(of: selectedIPadSection) { _, section in
            guard let section else { return }
            appState.selectSection(section)
        }
        .onChange(of: appState.selectedSection) { _, newSection in
            if appState.selectedCollectionID == nil, selectedIPadSection != newSection {
                selectedIPadSection = newSection
            }
            if newSection == .player {
                appState.setPlayerSurfaceVisible(appState.isPlayerVisible)
            } else if appState.currentFileURL != nil {
                appState.setPlayerSurfaceVisible(false)
            }
        }
        .onChange(of: appState.selectedCollectionID) { _, collectionID in
            selectedIPadSection = collectionID == nil ? appState.selectedSection : nil
        }
        .onChange(of: appState.isStageMaximized) { _, maximized in
            withAnimation(.stageFullscreen) {
                iPadColumnVisibility = maximized ? .detailOnly : .all
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSWFFile)) { n in
            if let url = n.userInfo?["url"] as? URL { appState.openFile(url) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyEvent)) { notification in
            guard let userInfo = notification.userInfo,
                  let keyCode = userInfo["keyCode"] as? UInt32,
                  let charCode = userInfo["charCode"] as? UInt32,
                  let isDown = userInfo["isDown"] as? Bool,
                  let modifiers = userInfo["modifiers"] as? UInt
            else { return }
            appState.routePhysicalKeyboardEvent(physicalHID: keyCode, charCode: charCode, isDown: isDown, modifiers: UInt32(modifiers))
        }
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

    private var iPadSidebar: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.md) {
            List(iPadSections, id: \.self, selection: $selectedIPadSection) { section in
                NavigationLink(value: section) {
                    Label(locManager.localized("sidebar.\(section.rawValue)"), systemImage: section.icon)
                }
            }
            .listStyle(.sidebar)
            .frame(minHeight: 240, idealHeight: 280, maxHeight: 320)

            ScrollView {
                SidebarCollectionsView()
                    .environmentObject(appState)
                    .environmentObject(locManager)
            }
            .frame(maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                AppBrandHeader(size: .sidebar)
            }
            ToolbarItem(placement: .primaryAction) {
                addContentMenu
            }
        }
    }

    // MARK: - iPhone Layout (TabView)

    private var iPhoneLayout: some View {
        TabView(selection: $appState.selectedSection) {
            NavigationStack {
                libraryTab
            }
            .tabItem {
                Label(locManager.localized("sidebar.library"), systemImage: "play.rectangle")
            }
            .tag(AppState.Section.library)

            NavigationStack {
                recentTab
            }
            .tabItem {
                Label(locManager.localized("sidebar.recent"), systemImage: "clock")
            }
            .tag(AppState.Section.recent)

            NavigationStack {
                playerTab
            }
            .tabItem {
                Label(locManager.localized("sidebar.player"), systemImage: "play.circle")
            }
            .tag(AppState.Section.player)

            NavigationStack {
                favoritesTab
            }
            .tabItem {
                Label(locManager.localized("sidebar.favorites"), systemImage: "star")
            }
            .tag(AppState.Section.favorites)

            NavigationStack {
                settingsTab
            }
            .tabItem {
                Label(locManager.localized("sidebar.settings"), systemImage: "gearshape")
            }
            .tag(AppState.Section.settings)
        }
        .onChange(of: appState.selectedSection) { _, newSection in
            if newSection == .player {
                appState.setPlayerSurfaceVisible(appState.isPlayerVisible)
            } else if appState.currentFileURL != nil {
                appState.setPlayerSurfaceVisible(false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSWFFile)) { n in
            if let url = n.userInfo?["url"] as? URL { appState.openFile(url) }
        }
    }

    // MARK: - Tab Content

    private var libraryTab: some View {
        LibraryContentView(isDropTargeted: .constant(false)) {
            showingCollectionsSheet = true
        }
            .environmentObject(appState)
            .environmentObject(locManager)
            .navigationTitle(locManager.localized("sidebar.library"))
            .navigationBarTitleDisplayMode(.large)
            .iosSearchable(
                hasLibrarySearchContent,
                text: searchBinding,
                prompt: locManager.localized("search.placeholder")
            )
            .onChange(of: hasLibrarySearchContent) { _, hasContent in
                clearSearchIfNeeded(hasContent: hasContent)
            }
            .toolbar(.visible, for: .navigationBar)
    }

    private var addContentMenu: some View {
        Menu {
            Button {
                AppCommandRouter.openFile(appState: appState, loc: locManager)
            } label: {
                Label(locManager.localized("toolbar.openSwf"), systemImage: "doc")
            }
            .keyboardShortcut("o", modifiers: .command)

            Button {
                AppCommandRouter.importFolder(appState: appState, loc: locManager)
            } label: {
                Label(locManager.localized("toolbar.importFolder"), systemImage: "folder")
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel(locManager.localized("toolbar.importHelp"))
    }

    private var collectionsSheet: some View {
        NavigationStack {
            ScrollView {
                SidebarCollectionsView { _ in
                    showingCollectionsSheet = false
                }
                .environmentObject(appState)
                .environmentObject(locManager)
                .padding(.horizontal, NativeSpacing.lg)
                .padding(.top, NativeSpacing.md)
            }
            .navigationTitle(locManager.localized("sidebar.collections"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locManager.localized("menu.close")) {
                        showingCollectionsSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var playerTab: some View {
        Group {
            if appState.isPlayerVisible {
                playerView
                    .navigationBarHidden(appState.isStageMaximized)
            } else {
                playerEmptyState
            }
        }
        .navigationTitle(locManager.localized("sidebar.player"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(appState.isStageMaximized ? .hidden : .visible, for: .navigationBar)
    }

    private var recentTab: some View {
        RecentListView()
            .environmentObject(appState)
            .environmentObject(locManager)
            .navigationTitle(locManager.localized("sidebar.recent"))
            .navigationBarTitleDisplayMode(.large)
            .iosSearchable(
                hasRecentSearchContent,
                text: searchBinding,
                prompt: locManager.localized("search.placeholder")
            )
            .onChange(of: hasRecentSearchContent) { _, hasContent in
                clearSearchIfNeeded(hasContent: hasContent)
            }
            .toolbar(.visible, for: .navigationBar)
    }

    private var favoritesTab: some View {
        FavoritesGridView()
            .environmentObject(appState)
            .environmentObject(locManager)
            .navigationTitle(locManager.localized("sidebar.favorites"))
            .navigationBarTitleDisplayMode(.large)
            .iosSearchable(
                hasFavoriteSearchContent,
                text: searchBinding,
                prompt: locManager.localized("search.placeholder")
            )
            .onChange(of: hasFavoriteSearchContent) { _, hasContent in
                clearSearchIfNeeded(hasContent: hasContent)
            }
            .toolbar(.visible, for: .navigationBar)
    }

    private var settingsTab: some View {
        SettingsView(settingsActions: SettingsActions(appState: appState))
            .environmentObject(appState)
            .environmentObject(locManager)
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { appState.searchText },
            set: { appState.updateSearchText($0) }
        )
    }

    private func clearSearchIfNeeded(hasContent: Bool) {
        if !hasContent, !appState.searchText.isEmpty {
            appState.updateSearchText("")
        }
    }

    // MARK: - Detail Content (iPad)

    @ViewBuilder
    private var detailContent: some View {
        iPadDetailContent(for: appState.selectedSection)
    }

    @ViewBuilder
    private func iPadDetailContent(for section: AppState.Section) -> some View {
        switch section {
        case .settings:
            NavigationStack {
                SettingsView(settingsActions: SettingsActions(appState: appState))
                    .environmentObject(appState)
                    .environmentObject(locManager)
            }
        case .player where appState.isPlayerVisible:
            playerView
        case .player:
            playerEmptyState
        case .library where appState.recentFiles.isEmpty:
            EmptyStateView(isDropTargeted: .constant(false))
                .environmentObject(appState)
                .environmentObject(locManager)
        default:
            LibraryContentView(isDropTargeted: .constant(false))
                .environmentObject(appState)
                .environmentObject(locManager)
        }
    }

    // MARK: - Player View

    private var playerEmptyState: some View {
        ContentUnavailableView {
            Label(locManager.localized("player.noMedia.title"), systemImage: "play.circle")
        } description: {
            Text(locManager.localized("player.noMedia.subtitle"))
        } actions: {
            Button {
                AppCommandRouter.openFile(appState: appState, loc: locManager)
            } label: {
                Label(locManager.localized("empty.openSwf"), systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var stageBackgroundARGB: UInt32 {
        appState.isStageMaximized ? 0xFF000000 : (colorScheme == .dark ? 0xFF000000 : 0xFFFFFFFF)
    }

    private var usesInlineFullscreen: Bool {
        appState.isStageMaximized
    }

    private var playerView: some View {
        playerSurface
            .onAppear {
                appState.setPlayerSurfaceVisible(true)
                syncStageBackground()
            }
            .onDisappear {
                appState.setPlayerSurfaceVisible(false)
            }
            .onChange(of: colorScheme) { _, _ in syncStageBackground() }
            .onReceive(NotificationCenter.default.publisher(for: .viewportChanged)) { n in
                guard let i = n.userInfo,
                      let w = i["width"] as? UInt32, let h = i["height"] as? UInt32,
                      let s = i["scaleFactor"] as? Float else { return }
                appState.bridge?.setViewport(width: w, height: h, scaleFactor: s)
                syncStageBackground()
            }
    }

    private var playerSurface: some View {
        GeometryReader { geo in
            let stageWidth = usesInlineFullscreen ? geo.size.width : max(0, geo.size.width - NativeSpacing.xxxl)
            let stageHeight = usesInlineFullscreen ? geo.size.height : max(220, geo.size.height * 0.58)
            let normalPanelReserve = NativeSpacing.xxl + 132
            let normalStageCenterMinY = stageHeight / 2 + NativeSpacing.md
            let normalStageCenterMaxY = max(normalStageCenterMinY, geo.size.height - stageHeight / 2 - NativeSpacing.md)
            let normalStageCenterY = min(
                max(geo.size.height - stageHeight / 2 - normalPanelReserve, normalStageCenterMinY),
                normalStageCenterMaxY
            )
            let stageCenterY = usesInlineFullscreen ? geo.size.height / 2 : normalStageCenterY

            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                Color.black
                    .opacity(usesInlineFullscreen ? 1 : 0)
                    .ignoresSafeArea()

                RufflePlayerView()
                    .environmentObject(appState)
                    .clipShape(RoundedRectangle(cornerRadius: usesInlineFullscreen ? 0 : NativeRadius.xl, style: .continuous))
                    .matchedGeometryEffect(id: "player-stage", in: playerNamespace)
                    .frame(width: stageWidth, height: stageHeight)
                    .position(x: geo.size.width / 2, y: stageCenterY)
                    .zIndex(0)

                VStack {
                    Spacer()
                    nowPlayingPanel
                        .padding(.horizontal, NativeSpacing.md)
                        .padding(.bottom, NativeSpacing.md)
                        .opacity(usesInlineFullscreen ? 0 : 1)
                        .offset(y: usesInlineFullscreen ? 24 : 0)
                        .allowsHitTesting(!usesInlineFullscreen)
                        .accessibilityHidden(usesInlineFullscreen)
                }
                .zIndex(2)

                if appState.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .zIndex(3)
                }

                if let errorMessage = appState.errorMessage {
                    VStack(spacing: NativeSpacing.md) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .multilineTextAlignment(.center)

                        HStack(spacing: NativeSpacing.sm) {
                            Button(locManager.localized("menu.reload")) {
                                appState.retryCurrentFile()
                            }
                            .disabled(appState.currentFileURL == nil)

                            Button(locManager.localized("menu.backToWorkspace")) {
                                appState.closeFile()
                            }

                            if !appState.playerIssues.isEmpty {
                                Button(locManager.localized("diagnostics.openDetails")) {
                                    appState.openCurrentFileDetails(section: .compatibility)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(NativeSpacing.lg)
                    .nativeLiquidGlass(in: RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous))
                    .padding(NativeSpacing.lg)
                    .zIndex(5)
                }

            }
            .overlay(alignment: .bottomLeading) {
                if appState.swfContentType == .interactive && appState.showVirtualControls {
                    let orientation: TouchLayoutOrientation = geo.size.width >= geo.size.height ? .landscape : .portrait
                    GameControlsView(
                        controls: appState.currentTouchControls(for: orientation),
                        safeAreaInsets: geo.safeAreaInsets
                    ) { instanceID, action, isDown in
                        appState.sendVirtualGameAction(action, instanceID: instanceID, isDown: isDown)
                    }
                    .onChange(of: orientation) { _, _ in
                        appState.releasePlayerInput()
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if usesInlineFullscreen {
                    glassIconButton(
                        "arrow.down.right.and.arrow.up.left",
                        accessibilityLabel: locManager.localized("menu.exitFullscreen")
                    ) {
                        withAnimation(.stageFullscreen) { appState.exitStageMaximized() }
                    }
                    .padding(.top, max(geo.safeAreaInsets.top, NativeSpacing.md))
                    .padding(.trailing, max(geo.safeAreaInsets.trailing, NativeSpacing.md))
                }
            }
        }
        .ignoresSafeArea(.container, edges: hidesStageSystemChrome ? .all : [])
        .statusBarHidden(hidesStageSystemChrome)
        .toolbar(hidesStageSystemChrome ? .hidden : .visible, for: .navigationBar)
        .toolbar(hidesStageSystemChrome ? .hidden : .visible, for: .tabBar)
        .animation(.stageFullscreen, value: appState.isStageMaximized)
        .animation(.easeInOut(duration: 0.2), value: hidesStageSystemChrome)
    }

    private var nowPlayingPanel: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.sm) {
            HStack(alignment: .center, spacing: NativeSpacing.sm) {
                VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                    Text(appState.currentFileURL?.deletingPathExtension().lastPathComponent ?? locManager.localized("player.nowPlaying"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(appState.currentFileURL?.lastPathComponent ?? locManager.localized("workspace.openIOSMessage"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                glassIconButton(
                    appState.isFavorite ? "star.fill" : "star",
                    accessibilityLabel: locManager.localized(appState.isFavorite ? "favorites.remove" : "favorites.add")
                ) {
                    if let url = appState.currentFileURL { appState.toggleFavorite(for: url) }
                }
                glassIconButton(
                    "arrow.up.left.and.arrow.down.right",
                    accessibilityLabel: locManager.localized("menu.enterFullscreen")
                ) {
                    withAnimation(.stageFullscreen) { appState.toggleStageMaximized() }
                }
                glassIconButton(
                    "xmark",
                    accessibilityLabel: locManager.localized("menu.close")
                ) {
                    appState.closeFile()
                }
            }

            PlayerControlBar()
                .environmentObject(appState)
                .frame(maxWidth: .infinity)
        }
        .padding(NativeSpacing.md)
        .nativeLiquidGlass(in: RoundedRectangle(cornerRadius: NativeRadius.xl, style: .continuous))
    }

    private func glassIconButton(_ systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .nativeLiquidGlass(in: Circle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var permissionPromptPresented: Binding<Bool> {
        Binding(
            get: { appState.pendingPermissionRequest != nil },
            set: { if !$0 { appState.pendingPermissionRequest = nil } }
        )
    }

    private var permissionPromptTitle: String {
        guard let request = appState.pendingPermissionRequest else {
            return locManager.localized("permission.prompt.title")
        }
        return locManager.localized(request.scope == .network
            ? "permission.prompt.network.title"
            : "permission.prompt.filesystem.title")
    }

    private var permissionPromptMessage: String {
        guard let request = appState.pendingPermissionRequest else { return "" }
        let fileName = request.fileURL?.lastPathComponent ?? locManager.localized("diagnostics.unavailable")
        let resource = request.requestedResource ?? locManager.localized("permission.prompt.resource.unspecified")
        let key = request.scope == .network
            ? "permission.prompt.network.message"
            : "permission.prompt.filesystem.message"
        return String(format: locManager.localized(key), fileName, resource)
    }

    private func syncStageBackground() {
        appState.bridge?.setBackgroundColor(stageBackgroundARGB)
    }

    private func syncStageSystemChrome(for maximized: Bool) {
        withAnimation(.stageFullscreen) {
            hidesStageSystemChrome = maximized
        }
    }
}

private extension View {
    @ViewBuilder
    func iosSearchable(_ isEnabled: Bool, text: Binding<String>, prompt: String) -> some View {
        if isEnabled {
            searchable(
                text: text,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: prompt
            )
        } else {
            self
        }
    }
}

#endif
