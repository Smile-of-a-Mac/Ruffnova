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
    @Namespace private var playerNamespace
    @State private var selectedIPadSection: AppState.Section? = .library
    @State private var iPadColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var hidesStageSystemChrome = false

    private let iPadSections: [AppState.Section] = [.player, .library, .recent, .favorites, .settings]

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onAppear {
            appState.handleSceneActiveStateChanged(scenePhase == .active)
            appState.setPlayerSurfaceVisible(appState.isPlayerVisible)
            hidesStageSystemChrome = appState.isStageMaximized
        }
        .onChange(of: scenePhase) { _, phase in
            appState.handleSceneActiveStateChanged(phase == .active)
        }
        .onChange(of: appState.isStageMaximized) { _, maximized in
            syncStageSystemChrome(for: maximized)
        }
        .statusBarHidden(hidesStageSystemChrome)
    }

    // MARK: - iPad Layout (NavigationSplitView)

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $iPadColumnVisibility) {
            List(iPadSections, id: \.self, selection: $selectedIPadSection) { section in
                NavigationLink(value: section) {
                    Label(locManager.localized("sidebar.\(section.rawValue)"), systemImage: section.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(locManager.localized("app.name"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addContentMenu
                }
            }
        } detail: {
            iPadDetailContent(for: appState.selectedSection)
                .id(appState.selectedSection)
        }
        .onAppear {
            selectedIPadSection = appState.selectedSection
            iPadColumnVisibility = appState.isStageMaximized ? .detailOnly : .all
        }
        .onChange(of: selectedIPadSection) { _, section in
            guard let section else { return }
            appState.selectedSection = section
        }
        .onChange(of: appState.selectedSection) { _, newSection in
            if selectedIPadSection != newSection {
                selectedIPadSection = newSection
            }
            if newSection == .player {
                appState.setPlayerSurfaceVisible(appState.isPlayerVisible)
                appState.resumePlaybackForNavigation()
            } else if appState.currentFileURL != nil {
                appState.setPlayerSurfaceVisible(false)
                appState.pausePlaybackForNavigation()
            }
        }
        .onChange(of: appState.isStageMaximized) { _, maximized in
            withAnimation(.stageFullscreen) {
                iPadColumnVisibility = maximized ? .detailOnly : .all
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSWFFile)) { n in
            if let url = n.userInfo?["url"] as? URL { appState.openFile(url) }
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
                playerTab
            }
            .tabItem {
                Label(locManager.localized("sidebar.player"), systemImage: "play.circle")
            }
            .tag(AppState.Section.player)

            NavigationStack {
                recentTab
            }
            .tabItem {
                Label(locManager.localized("sidebar.recent"), systemImage: "clock")
            }
            .tag(AppState.Section.recent)

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
                appState.resumePlaybackForNavigation()
            } else if appState.currentFileURL != nil {
                appState.setPlayerSurfaceVisible(false)
                appState.pausePlaybackForNavigation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSWFFile)) { n in
            if let url = n.userInfo?["url"] as? URL { appState.openFile(url) }
        }
    }

    // MARK: - Tab Content

    private var libraryTab: some View {
        LibraryContentView(isDropTargeted: .constant(false))
            .environmentObject(appState)
            .environmentObject(locManager)
            .navigationTitle(locManager.localized("sidebar.library"))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        AppCommandRouter.openFile(appState: appState, loc: locManager)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("o", modifiers: .command)
                    .accessibilityLabel(locManager.localized("toolbar.openSwf"))
                }
            }
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
    }

    private var recentTab: some View {
        RecentListView()
            .environmentObject(appState)
            .environmentObject(locManager)
            .navigationTitle(locManager.localized("sidebar.recent"))
    }

    private var favoritesTab: some View {
        FavoritesGridView()
            .environmentObject(appState)
            .environmentObject(locManager)
            .navigationTitle(locManager.localized("sidebar.favorites"))
    }

    private var settingsTab: some View {
        SettingsView(settingsActions: SettingsActions(appState: appState))
            .environmentObject(appState)
            .environmentObject(locManager)
            .navigationTitle(locManager.localized("sidebar.settings"))
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
            SettingsView(settingsActions: SettingsActions(appState: appState))
                .environmentObject(appState)
                .environmentObject(locManager)
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

                VStack {
                    HStack {
                        Spacer()
                        glassIconButton(
                            "arrow.down.right.and.arrow.up.left",
                            accessibilityLabel: locManager.localized("menu.exitFullscreen")
                        ) {
                            withAnimation(.stageFullscreen) { appState.exitStageMaximized() }
                        }
                        .padding(.top, max(geo.safeAreaInsets.top, NativeSpacing.md))
                        .padding(.trailing, max(geo.safeAreaInsets.trailing, NativeSpacing.md))
                    }
                    Spacer()
                }
                .opacity(usesInlineFullscreen ? 1 : 0)
                .offset(y: usesInlineFullscreen ? 0 : -10)
                .allowsHitTesting(usesInlineFullscreen)
                .accessibilityHidden(!usesInlineFullscreen)
                .zIndex(4)
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
        .liquidGlassRounded(cornerRadius: NativeRadius.xl, material: GlassMaterial.light)
    }

    private func glassIconButton(_ systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(LiquidGlassModifier(shape: Circle(), material: GlassMaterial.ultraLight))
        .accessibilityLabel(accessibilityLabel)
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
#endif
