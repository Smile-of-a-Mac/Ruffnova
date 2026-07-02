import SwiftUI
import Combine
import QuartzCore
import MetalKit
import UniformTypeIdentifiers
import OSLog
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
#if RUST_FFI_AVAILABLE
import CRuffleFFI
#endif

struct RecentFile: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    var lastOpened: Date
    let fileSize: Int64
    var thumbnailData: Data?

    static func == (lhs: RecentFile, rhs: RecentFile) -> Bool {
        lhs.id == rhs.id
    }
}

enum SwfContentType: String {
    case animation
    case interactive
}

@MainActor
final class AppState: ObservableObject {
    enum Section: String, CaseIterable, Equatable {
        case player
        case library
        case recent
        case favorites
        case settings

        var icon: String {
            switch self {
            case .player:      return "play.circle"
            case .library:     return "play.rectangle"
            case .recent:      return "clock"
            case .favorites:   return "star"
            case .settings:    return "gearshape"
            }
        }

        var title: String {
            switch self {
            case .player:      return "Playing"
            case .library:     return "Library"
            case .recent:      return "Recent"
            case .favorites:   return "Favorites"
            case .settings:    return "Settings"
            }
        }
    }

    @Published var isPlaying: Bool = false
    @Published var volume: Float = 1.0
    @Published var isMuted: Bool = false
    @Published var isFullscreen: Bool = false
    @Published var isStageMaximized: Bool = false
    @Published var stageWidth: UInt32 = 550
    @Published var stageHeight: UInt32 = 400

    @Published var swfContentType: SwfContentType = .animation

    @Published var showControlBar: Bool = true
    private var hideControlBarTask: DispatchWorkItem?

    @Published var currentFileURL: URL?
    @Published var recentFiles: [RecentFile] = [] {
        didSet { LibraryPersistence.shared.saveRecentFiles(recentFiles) }
    }
    @Published var bookmarks: [URL] = []
    let bookmarkManager = BookmarkManager()

    var favoriteEntries: [Bookmark] { bookmarkManager.bookmarks }

    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    var searchResults: [RecentFile] {
        guard !searchText.isEmpty else { return [] }
        return recentFiles.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var librarySearchResults: [LibraryItem] {
        guard !searchText.isEmpty else { return [] }
        return LibraryService.shared.items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    @Published var librarySize: String = "--"
    @Published var swfCount: Int = 0

    @Published var selectedSection: Section = .library
    @Published var showToolbar: Bool = true
    @Published var showDebugUI: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var sidebarCollapsed: Bool = false
    @Published var showSWFInfoPanel: Bool = false
    @Published var showTraceConsole: Bool = false
    private var pausedForNavigation = false

    var formattedCurrentTime: String {
        let secs = frameRate > 0 ? Double(currentFrame) / Double(frameRate) : 0
        return formatTime(secs)
    }

    var formattedTotalTime: String {
        let secs = frameRate > 0 ? Double(totalFrames) / Double(frameRate) : 0
        return formatTime(secs)
    }

    private func formatTime(_ secs: Double) -> String {
        let m = Int(secs) / 60
        let s = Int(secs) % 60
        return String(format: "%d:%02d", m, s)
    }

    @Published var quality: RuffleQuality = .high
    @Published var maxExecutionDuration: TimeInterval = 15.0
    @Published var avm2OptimizerEnabled: Bool = true

    var language: String {
        LocalizationManager.shared.selectedLanguage.locale.identifier
    }

    @Published var currentFrame: UInt32 = 0
    @Published var totalFrames: UInt32 = 0
    @Published var frameRate: Float = 30.0
    @Published var isLooping: Bool = false
    @Published var playbackSpeed: Float = 1.0
    @Published var seekPosition: Double = 0

    @Published var debugFrameRate: Double = 0
    @Published var debugCurrentFrame: UInt64 = 0

    private(set) var bridge: RuffleBridge?
    private var pendingFileURL: URL?
    #if os(iOS)
    private var filePickerService: IOSFilePickerService?
    private var securityScopedURL: URL?
    #endif
    private var timelinePollTimer: Timer?
    private var loadTimeoutTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    #if os(iOS)
    private var pausedForSystemInterruption = false
    private var sceneIsActive = true
    private var playerSurfaceVisible = false
    #endif

    var libraryItems: [LibraryItem] {
        LibraryService.shared.items
    }

    init() {
        setupNotifications()
        setupFullscreenObserver()
        restoreSettings()
        setupPersistence()
        LibraryService.shared.migrateIfNeeded()
        LibraryService.shared.resolveBookmarks()
        recentFiles = LibraryPersistence.shared.loadRecentFiles()
        bookmarks = bookmarkManager.bookmarks.map { $0.url }
        bookmarkManager.$bookmarks.sink { [weak self] newBookmarks in
            self?.bookmarks = newBookmarks.map { $0.url }
        }.store(in: &cancellables)
    }

    private func restoreSettings() {
        let settings = SettingsPersistence.shared
        quality = RuffleQuality(rawValue: settings.quality) ?? .high
        volume = settings.volume
        isMuted = settings.isMuted
        isLooping = settings.isLooping
        playbackSpeed = settings.speed
        showDebugUI = settings.showDebugUI
        showToolbar = settings.showToolbar
        maxExecutionDuration = settings.maxExecutionDuration
    }

    private func setupPersistence() {
        let s = SettingsPersistence.shared
        $quality.sink { s.quality = $0.rawValue }.store(in: &cancellables)
        $volume.sink { s.volume = $0 }.store(in: &cancellables)
        $isMuted.sink { s.isMuted = $0 }.store(in: &cancellables)
        $isLooping.sink { s.isLooping = $0 }.store(in: &cancellables)
        $playbackSpeed.sink { s.speed = $0 }.store(in: &cancellables)
        $showDebugUI.sink { s.showDebugUI = $0 }.store(in: &cancellables)
        $showToolbar.sink { s.showToolbar = $0 }.store(in: &cancellables)
        $maxExecutionDuration.sink { s.maxExecutionDuration = $0 }.store(in: &cancellables)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSWF(_:)),
            name: .openSWFFile,
            object: nil
        )
    }

    private func setupFullscreenObserver() {
        #if os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFullscreenExit),
            name: NSWindow.didExitFullScreenNotification,
            object: nil
        )
        #endif
    }

    @objc private func handleFullscreenExit() {
        isStageMaximized = false
    }

    @objc private func handleOpenSWF(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        openFile(url)
    }

    func initializeBridge(metalLayer: CAMetalLayer, width: UInt32, height: UInt32, scaleFactor: Float) {
        if let bridge {
            bridge.updateSurface(metalLayer: metalLayer, width: width, height: height)
            bridge.setViewport(width: width, height: height, scaleFactor: scaleFactor)
            updateIOSRenderLoopAvailability()
            return
        }
        let storedQuality = SettingsPersistence.shared.quality
        let storedAutoplay = SettingsPersistence.shared.autoplay
        let storedMaxExec = SettingsPersistence.shared.maxExecutionDuration
        bridge = RuffleBridge(
            metalLayer: metalLayer, width: width, height: height, scaleFactor: scaleFactor,
            quality: storedQuality,
            autoplay: storedAutoplay,
            maxExecutionSecs: Float(storedMaxExec)
        )
        bridge?.onFrameUpdate = { [weak self] fps, frame in
            DispatchQueue.main.async {
                self?.debugFrameRate = fps
                self?.debugCurrentFrame = frame
            }
        }
        bridge?.setVolume(isMuted ? 0.0 : volume)
        bridge?.setLooping(isLooping)
        bridge?.setSpeed(playbackSpeed)
        updateIOSRenderLoopAvailability()
        #if RUST_FFI_AVAILABLE
        let letterboxSetting = UserDefaults.standard.string(forKey: "letterbox") ?? "fullscreen"
        switch letterboxSetting {
        case "on":
            bridge?.setLetterboxMode(RuffleLetterbox_On)
        case "off":
            bridge?.setLetterboxMode(RuffleLetterbox_Off)
        default:
            bridge?.setLetterboxMode(RuffleLetterbox_Fullscreen)
        }
        #endif

        if let url = pendingFileURL {
            bridge?.loadURL(url)
            pendingFileURL = nil
            afterMovieLoaded()
        }
    }

    func openFile(_ url: URL) {
        #if os(iOS)
        if securityScopedURL != url {
            securityScopedURL?.stopAccessingSecurityScopedResource()
            securityScopedURL = url.startAccessingSecurityScopedResource() ? url : nil
        }
        #endif
        isLoading = true
        errorMessage = nil
        currentFileURL = url
        loadTimeoutTask?.cancel()

        let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let recentFile = RecentFile(
            id: UUID(),
            url: url,
            name: url.lastPathComponent,
            lastOpened: Date(),
            fileSize: Int64(resourceValues?.fileSize ?? 0)
        )
        if !recentFiles.contains(where: { $0.url == url }) {
            recentFiles.insert(recentFile, at: 0)
            if recentFiles.count > 20 {
                recentFiles.removeLast()
            }
        } else if let idx = recentFiles.firstIndex(where: { $0.url == url }) {
            var updated = recentFiles[idx]
            updated.lastOpened = Date()
            recentFiles.remove(at: idx)
            recentFiles.insert(updated, at: 0)
        }

        if LibraryService.shared.contains(url) {
            LibraryService.shared.update(LibraryService.shared.item(for: url)!.id) {
                $0.lastOpened = Date()
            }
        } else {
            LibraryService.shared.add(LibraryItem(
                url: url,
                fileSize: Int64(resourceValues?.fileSize ?? 0),
                lastOpened: Date()
            ))
        }

        loadTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard let self, self.isLoading else { return }
            self.isLoading = false
            self.errorMessage = LocalizationManager.shared.localized("error.loadTimeout")
        }

        if let bridge {
            bridge.loadURL(url)
            afterMovieLoaded()
        } else {
            pendingFileURL = url
        }
        selectedSection = .player
    }

    func syncPlayingState() {
        guard let bridge else { return }
        isPlaying = bridge.isPlaying()
    }

    private func afterMovieLoaded() {
        let shouldAutoplay = UserDefaults.standard.object(forKey: "autoplay") as? Bool ?? true
        if shouldAutoplay {
            bridge?.setPlaying(true)
            syncPlayingState()
        }
        detectContentType()
        updateIOSRenderLoopAvailability()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.adoptStageSize()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.adoptStageSize()
            self?.isLoading = false
            self?.loadTimeoutTask?.cancel()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.captureThumbnail()
        }
        scheduleControlBarHide()
    }

    private func detectContentType() {
        let info = bridge?.getPlaybackInfo()
        let totalFrames = info?.totalFrames ?? 0
        if totalFrames > 1 {
            swfContentType = .animation
        } else {
            swfContentType = .interactive
        }
        Logger.appState.info("content type: \(self.swfContentType.rawValue) (totalFrames=\(totalFrames))")
    }

    func showControlBarTemporarily() {
        showControlBar = true
        scheduleControlBarHide()
    }

    func keepControlBarVisible() {
        showControlBar = true
        hideControlBarTask?.cancel()
    }

    private func scheduleControlBarHide() {
        hideControlBarTask?.cancel()
        guard isPlaying else { return }
        let task = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.showControlBar = false
            }
        }
        hideControlBarTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }

    func controlBarOnPause() {
        hideControlBarTask?.cancel()
        showControlBar = true
    }

    func adoptStageSize() {
        guard let bridge else { return }
        let (sw, sh) = bridge.stageSize()
        guard sw > 0, sh > 0 else { return }
        stageWidth = sw
        stageHeight = sh
        updateIOSOrientations()
    }

    private func updateIOSOrientations() {
        #if os(iOS)
        let supportsLandscapeFullscreen = isStageMaximized && stageWidth >= stageHeight
        IOSOrientationController.update(to: supportsLandscapeFullscreen ? .allButUpsideDown : .portrait)
        #endif
    }

    func togglePlayPause() {
        isPlaying.toggle()
        bridge?.setPlaying(isPlaying)
        if isPlaying {
            showControlBarTemporarily()
        } else {
            controlBarOnPause()
        }
    }

    func pausePlayback() {
        guard isPlaying else { return }
        isPlaying = false
        bridge?.setPlaying(false)
        controlBarOnPause()
    }

    func pausePlaybackForNavigation() {
        guard isPlaying else { return }
        pausedForNavigation = true
        pausePlayback()
    }

    func resumePlaybackForNavigation() {
        guard pausedForNavigation, currentFileURL != nil else { return }
        pausedForNavigation = false
        isPlaying = true
        bridge?.setPlaying(true)
        showControlBarTemporarily()
    }

    func setPlayerSurfaceVisible(_ visible: Bool) {
        #if os(iOS)
        playerSurfaceVisible = visible
        updateIOSRenderLoopAvailability()
        #endif
    }

    func handleSceneActiveStateChanged(_ active: Bool) {
        #if os(iOS)
        sceneIsActive = active
        if active {
            updateIOSRenderLoopAvailability()
            let shouldResumePlayback = pausedForSystemInterruption && currentFileURL != nil && playerSurfaceVisible
            pausedForSystemInterruption = false
            if shouldResumePlayback {
                isPlaying = true
                bridge?.setPlaying(true)
                showControlBarTemporarily()
            }
        } else {
            if isPlaying {
                pausedForSystemInterruption = true
                isPlaying = false
                bridge?.setPlaying(false)
                controlBarOnPause()
            }
            updateIOSRenderLoopAvailability()
        }
        #endif
    }

    private func updateIOSRenderLoopAvailability() {
        #if os(iOS)
        let shouldRender = sceneIsActive && playerSurfaceVisible && currentFileURL != nil && bridge != nil
        bridge?.setRenderLoopActive(shouldRender)
        if shouldRender {
            startTimelinePolling()
        } else {
            stopTimelinePolling()
        }
        #endif
    }

    var isPlayerVisible: Bool {
        currentFileURL != nil && selectedSection == .player
    }

    func closeFile() {
        pausePlayback()
        stopTimelinePolling()
        currentFileURL = nil
        updateIOSRenderLoopAvailability()
        selectedSection = .library
        hideControlBarTask?.cancel()
        showControlBar = true
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        bridge?.setVolume(newVolume)
    }

    func toggleMute() {
        isMuted.toggle()
        bridge?.setVolume(isMuted ? 0.0 : volume)
    }

    func stepForward() {
        bridge?.tick(1.0 / 60.0)
    }

    func toggleFullscreen() {
        isFullscreen.toggle()
        bridge?.setFullscreen(isFullscreen)
        #if os(macOS)
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
        #endif
    }

    func toggleStageMaximized() {
        #if os(macOS)
        guard !isStageMaximized else { return }
        isStageMaximized = true
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
        #else
        isStageMaximized.toggle()
        updateIOSOrientations()
        #endif
    }

    func exitStageMaximized() {
        guard isStageMaximized else { return }
        isStageMaximized = false
        #if os(macOS)
        NSApp.keyWindow?.toggleFullScreen(nil)
        #else
        updateIOSOrientations()
        #endif
    }

    func toggleSidebar() {
        sidebarCollapsed.toggle()
    }

    func showFilePicker() {
        #if os(iOS)
        let service = IOSFilePickerService()
        filePickerService = service
        service.pickSWFFile { [weak self] url in
            self?.filePickerService = nil
            if let url {
                DispatchQueue.main.async { self?.openFile(url) }
            }
        }
        #endif
    }

    func showFolderPicker() {
        #if os(iOS)
        let service = IOSFilePickerService()
        filePickerService = service
        service.pickFolder { [weak self] url in
            self?.filePickerService = nil
            if let url {
                DispatchQueue.main.async { self?.browseDirectory(url) }
            }
        }
        #endif
    }

    func removeFromRecentlyOpened(_ file: RecentFile) {
        recentFiles.removeAll { $0.id == file.id }
    }

    func clearRecentlyOpened() {
        recentFiles.removeAll()
    }

    func captureThumbnail() {
        #if os(macOS)
        guard let frameView = findPlayerFrameView() else { return }
        let window = frameView.window
        guard let window, window.windowNumber > 0 else { return }

        let windowRect = frameView.convert(frameView.bounds, to: nil)
        let screenRect = window.convertToScreen(windowRect)

        guard let cgImage = CGWindowListCreateImage(
            screenRect, .optionIncludingWindow,
            CGWindowID(window.windowNumber), .nominalResolution
        ) else { return }

        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return }

        let maxSize: CGFloat = 320
        let scale = min(maxSize / CGFloat(w), maxSize / CGFloat(h), 1.0)
        let scaledSize = NSSize(width: CGFloat(w) * scale, height: CGFloat(h) * scale)
        let scaledImage = NSImage(cgImage: cgImage, size: scaledSize)

        guard let tiff = scaledImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }

        if let idx = recentFiles.firstIndex(where: { $0.url == currentFileURL }) {
            recentFiles[idx].thumbnailData = png
        }
        if let item = LibraryService.shared.items.first(where: { $0.url == currentFileURL }) {
            LibraryService.shared.update(item.id) { $0.thumbnailData = png }
        }
        #endif
    }

    #if os(macOS)
    private func findPlayerFrameView() -> NSView? {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first,
              let view = window.contentView else { return nil }
        return findMTKView(in: view)
    }

    private func findMTKView(in view: NSView) -> NSView? {
        if view is MTKView { return view }
        for subview in view.subviews {
            if let found = findMTKView(in: subview) { return found }
        }
        return nil
    }
    #endif

    func saveScreenshot() {
        #if os(macOS)
        guard let metalView = findPlayerFrameView() as? MTKView,
              let drawable = metalView.currentDrawable else {
            errorMessage = LocalizationManager.shared.localized("error.screenshotFailed")
            return
        }

        let texture = drawable.texture
        let width = Int(texture.width)
        let height = Int(texture.height)
        guard width > 0, height > 0, !texture.isFramebufferOnly else {
            errorMessage = LocalizationManager.shared.localized("error.screenshotFailed")
            return
        }
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        texture.getBytes(&pixelData, bytesPerRow: bytesPerRow,
                         from: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0)

        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let b = pixelData[i]
            pixelData[i] = pixelData[i + 2]
            pixelData[i + 2] = b
        }

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData),
              let cgImage = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "screenshot.png"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url,
               let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
        }
        #else
        errorMessage = LocalizationManager.shared.localized("error.screenshotFailed")
        #endif
    }

    func startTimelinePolling() {
        timelinePollTimer?.invalidate()
        timelinePollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollPlaybackInfo()
            }
        }
    }

    func stopTimelinePolling() {
        timelinePollTimer?.invalidate()
        timelinePollTimer = nil
    }

    private func pollPlaybackInfo() {
        guard let info = bridge?.getPlaybackInfo() else { return }
        currentFrame = info.currentFrame
        totalFrames = info.totalFrames
        frameRate = info.frameRate
        if totalFrames > 0 {
            let pos = Double(currentFrame)
            if abs(pos - seekPosition) > 0.5 { seekPosition = pos }
        }
        if isLooping && totalFrames > 0 && currentFrame >= totalFrames {
            bridge?.rewind()
        }
    }

    func seekToFrame(_ frame: UInt32) { bridge?.seekFrame(frame) }
    func seekToEnd() { bridge?.seekFrame(totalFrames) }
    func stepBackward() { bridge?.stepBack(1) }
    func rewind() { bridge?.rewind() }
    func toggleLoop() {
        isLooping.toggle()
        bridge?.setLooping(isLooping)
    }
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        bridge?.setSpeed(speed)
    }

    func browseDirectory(_ url: URL) {
        #if os(iOS)
        if securityScopedURL != url {
            securityScopedURL?.stopAccessingSecurityScopedResource()
            securityScopedURL = url.startAccessingSecurityScopedResource() ? url : nil
        }
        defer {
            if securityScopedURL == url {
                securityScopedURL?.stopAccessingSecurityScopedResource()
                securityScopedURL = nil
            }
        }
        #endif
        guard let swfFiles = try? ImportService.shared.scanForSWFFiles(in: url) else { return }

        for fileURL in swfFiles {
            let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let recent = RecentFile(
                id: UUID(),
                url: fileURL,
                name: fileURL.lastPathComponent,
                lastOpened: resourceValues?.contentModificationDate ?? Date(),
                fileSize: Int64(resourceValues?.fileSize ?? 0)
            )
            if !recentFiles.contains(where: { $0.url == fileURL }) {
                recentFiles.append(recent)
            }
            if !LibraryService.shared.contains(fileURL) {
                LibraryService.shared.add(LibraryItem(
                    url: fileURL,
                    fileSize: Int64(resourceValues?.fileSize ?? 0),
                    lastOpened: resourceValues?.contentModificationDate ?? Date()
                ))
            }
        }
        updateLibraryStats()
    }

    func updateLibraryStats() {
        let allItems = LibraryService.shared.items
        let totalSize = allItems.reduce(0) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        librarySize = formatter.string(fromByteCount: totalSize)
        swfCount = allItems.count
    }

    func toggleFavorite(for url: URL) {
        if bookmarkManager.bookmarks.contains(where: { $0.url == url }) {
            if let bookmark = bookmarkManager.bookmarks.first(where: { $0.url == url }) {
                bookmarkManager.remove(bookmark)
            }
        } else {
            bookmarkManager.add(url: url, frame: currentFrame)
        }
        bookmarks = bookmarkManager.bookmarks.map { $0.url }
        if let item = LibraryService.shared.items.first(where: { $0.url == url }) {
            LibraryService.shared.update(item.id) { $0.isFavorite.toggle() }
        }
    }

    var isFavorite: Bool {
        guard let url = currentFileURL else { return false }
        return bookmarkManager.bookmarks.contains(where: { $0.url == url })
    }

}
