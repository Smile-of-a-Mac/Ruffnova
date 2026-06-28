// ContentView — Glass-based main application view.
// Window glass is the foundation. Sidebar blends in. Content floats above.
// Toolbar is invisible. Only floating controls exist.

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @State private var isDropTargeted = false


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
            if !appState.isStageMaximized {
                AppToolbar()
            }
        }
        .onDrop(of: [.fileURL, .folder].compactMap { $0 }, isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSWFFile)) { n in
            if let url = n.userInfo?["url"] as? URL { appState.openFile(url) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewportChanged)) { n in
            guard let i = n.userInfo,
                  let w = i["width"] as? UInt32, let h = i["height"] as? UInt32,
                  let s = i["scaleFactor"] as? Float else { return }
            DispatchQueue.main.async { appState.bridge?.setViewport(width: w, height: h, scaleFactor: s) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyEvent)) { n in
            guard let i = n.userInfo,
                  let kc = i["keyCode"] as? UInt32, let cc = i["charCode"] as? UInt32,
                  let dn = i["isDown"] as? Bool, let mod = i["modifiers"] as? UInt else { return }
            appState.bridge?.sendKeyEvent(keyCode: kc, charCode: cc, isDown: dn, modifiers: UInt32(mod))
        }
        .onChange(of: appState.selectedSection) { newSection in
            if newSection != .library && appState.currentFileURL != nil {
                appState.pausePlayback()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSWFInfo)) { _ in
            appState.showSWFInfoPanel.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTraceConsole)) { _ in
            appState.showTraceConsole.toggle()
        }
        .sheet(isPresented: $appState.showSWFInfoPanel) {
            SWFInfoPanel()
                .environmentObject(appState)
                .frame(width: 280, height: 300)
        }
        .sheet(isPresented: $appState.showTraceConsole) {
            TraceConsoleView()
                .frame(width: 500, height: 400)
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

    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
            VStack(alignment: .leading, spacing: NativeSpacing.sm) {
                Text(locManager.localized("search.results"))
                    .font(.largeTitle)
                Text(String(format: locManager.localized("search.results.count"), appState.searchResults.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, NativeSpacing.section)
            .padding(.top, NativeSpacing.section)

            if appState.searchResults.isEmpty {
                emptySearchState
            } else {
                ScrollView {
                    LazyVStack(spacing: NativeSpacing.sm) {
                        ForEach(appState.searchResults) { file in
                            RecentFileRow(file: file)
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
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var playerView: some View {
        ZStack {
            Color.clear
                .background(.regularMaterial)
                .ignoresSafeArea()

            if appState.isStageMaximized {
                Color.black
                    .ignoresSafeArea()

                playerStage
                    .ignoresSafeArea()

                playerTitleBadge
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, NativeSpacing.md)
                    .padding(.top, NativeSpacing.md)

                if appState.showToolbar && appState.currentFileURL != nil {
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
                            playerTitleBadge
                                .padding(.top, NativeSpacing.sm)
                                .padding(.trailing, NativeSpacing.sm)
                        }
                        .layoutPriority(1)

                    if appState.showToolbar {
                        PlayerControlBar()
                            .environmentObject(appState)
                            .padding(.vertical, NativeSpacing.md)
                    }
                }
            } else {
                playerStage
                    .onHover { hovering in
                        if hovering { appState.showControlBarTemporarily() }
                    }

                if appState.showToolbar && appState.currentFileURL != nil {
                    VStack {
                        Spacer()
                        PlayerControlBar()
                            .environmentObject(appState)
                            .padding(.horizontal, NativeSpacing.xxxl)
                            .padding(.bottom, NativeSpacing.xl)
                    }
                }

                playerTitleBadge
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, NativeSpacing.xl)
                    .padding(.top, 56)
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
        .onExitCommand {
            appState.exitStageMaximized()
        }
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
        }
    }

    // MARK: - Error Toast

    private func errorToast(_ msg: String) -> some View {
        HStack(spacing: NativeSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(msg).font(.callout)
            Spacer()
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
                    let ext = url.pathExtension.lowercased()

                    if ext == "swf" {
                        DispatchQueue.main.async { appState.openFile(url) }
                    } else if ext == "zip" {
                        handleZipDrop(url)
                    } else if url.hasDirectoryPath {
                        DispatchQueue.main.async { appState.browseDirectory(url) }
                    }
                }
            }
        }
        return hasSupported
    }

    private func handleZipDrop(_ url: URL) {
        do {
            let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", url.path, "-d", tmpDir.path]
            try process.run()
            process.waitUntilExit()
            DispatchQueue.main.async { appState.browseDirectory(tmpDir) }
        } catch {
            DispatchQueue.main.async { appState.errorMessage = locManager.localized("error.zipExtract") }
        }
    }
}

#Preview("Content") {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
}
