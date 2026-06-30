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
    @Namespace private var playerNamespace
    @State private var selectedIPadSection: AppState.Section? = .library

    private let iPadSections: [AppState.Section] = [.player, .library, .recent, .favorites, .settings]

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad Layout (NavigationSplitView)

    private var iPadLayout: some View {
        NavigationSplitView {
            List(iPadSections, id: \.self, selection: $selectedIPadSection) { section in
                NavigationLink(value: section) {
                    Label(locManager.localized("sidebar.\(section.rawValue)"), systemImage: section.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(locManager.localized("app.name"))
        } detail: {
            iPadDetailContent(for: appState.selectedSection)
                .id(appState.selectedSection)
        }
        .onAppear {
            selectedIPadSection = appState.selectedSection
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
                appState.resumePlaybackForNavigation()
            } else if appState.currentFileURL != nil {
                appState.pausePlaybackForNavigation()
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
                appState.resumePlaybackForNavigation()
            } else if appState.currentFileURL != nil {
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
                        appState.showFilePicker()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
    }

    private var playerTab: some View {
        Group {
            if appState.isPlayerVisible {
                playerView
                    .navigationBarHidden(appState.isStageMaximized)
            } else {
                ZStack {
                    Color.clear
                        .background(.regularMaterial)

                    VStack(spacing: 20) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text(locManager.localized("player.nowPlaying"))
                            .font(.largeTitle)
                    Text(locManager.localized("workspace.openIOSMessage"))
                        .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
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
        SettingsView()
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
            SettingsView()
                .environmentObject(appState)
                .environmentObject(locManager)
        case .player where appState.isPlayerVisible:
            playerView
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

    private var stageBackgroundColor: Color {
        appState.isStageMaximized ? .black : Color(.systemBackground)
    }

    private var stageBackgroundARGB: UInt32 {
        appState.isStageMaximized ? 0xFF000000 : (colorScheme == .dark ? 0xFF000000 : 0xFFFFFFFF)
    }

    private var playerView: some View {
        playerSurface
            .onAppear(perform: syncStageBackground)
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
            let stageWidth = appState.isStageMaximized ? geo.size.width : max(0, geo.size.width - NativeSpacing.xxxl)
            let stageHeight = appState.isStageMaximized ? geo.size.height : max(220, geo.size.height * 0.58)

            ZStack {
                stageBackgroundColor.ignoresSafeArea()

                VStack(spacing: appState.isStageMaximized ? 0 : NativeSpacing.xl) {
                    if !appState.isStageMaximized {
                        Spacer(minLength: NativeSpacing.md)
                    }

                    RufflePlayerView()
                        .environmentObject(appState)
                        .clipShape(RoundedRectangle(cornerRadius: appState.isStageMaximized ? 0 : NativeRadius.xl, style: .continuous))
                        .matchedGeometryEffect(id: "player-stage", in: playerNamespace)
                        .frame(width: stageWidth, height: stageHeight)
                        .zIndex(0)

                    if !appState.isStageMaximized {
                        nowPlayingPanel
                            .padding(.horizontal, NativeSpacing.xxxl)
                            .padding(.bottom, NativeSpacing.xl)
                            .zIndex(2)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                if appState.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .zIndex(3)
                }

                if appState.isStageMaximized {
                    VStack {
                        HStack {
                            Spacer()
                            glassIconButton("arrow.down.right.and.arrow.up.left") {
                                withAnimation(.glassSpring) { appState.exitStageMaximized() }
                            }
                            .padding(NativeSpacing.md)
                        }
                        Spacer()
                    }
                    .zIndex(4)
                }
            }
        }
        .ignoresSafeArea(.container, edges: appState.isStageMaximized ? .all : [])
        .statusBarHidden(appState.isStageMaximized)
        .toolbar(appState.isStageMaximized ? .hidden : .visible, for: .navigationBar)
        .toolbar(appState.isStageMaximized ? .hidden : .visible, for: .tabBar)
        .animation(.glassSpring, value: appState.isStageMaximized)
    }

    private var nowPlayingPanel: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.sm) {
            HStack(alignment: .center, spacing: NativeSpacing.sm) {
                VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                    Text(appState.currentFileURL?.deletingPathExtension().lastPathComponent ?? locManager.localized("player.nowPlaying"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(appState.currentFileURL?.lastPathComponent ?? locManager.localized("workspace.dropMessage"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                glassIconButton(appState.isFavorite ? "star.fill" : "star") {
                    if let url = appState.currentFileURL { appState.toggleFavorite(for: url) }
                }
                glassIconButton("arrow.up.left.and.arrow.down.right") {
                    withAnimation(.glassSpring) { appState.toggleStageMaximized() }
                }
            }

            PlayerControlBar()
                .environmentObject(appState)
                .frame(maxWidth: .infinity)
        }
        .padding(NativeSpacing.md)
        .liquidGlassRounded(cornerRadius: NativeRadius.xl, material: GlassMaterial.light)
    }

    private func glassIconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(LiquidGlassModifier(shape: Circle(), material: GlassMaterial.ultraLight))
    }

    private func syncStageBackground() {
        appState.bridge?.setBackgroundColor(stageBackgroundARGB)
    }
}
#endif
