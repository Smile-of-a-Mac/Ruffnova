import SwiftUI
import Combine
import QuartzCore
import MetalKit
import UniformTypeIdentifiers
import OSLog
import ImageIO
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
import AVFAudio
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

enum ThumbnailCapturePolicy {
    static let coverAspectRatio: CGFloat = 4.0 / 3.0
    static let coverMaxPixelSize: CGFloat = 640

    static func shouldAttempt(thumbnailIdentifier: String?) -> Bool {
        guard let thumbnailIdentifier else { return true }
        return thumbnailIdentifier.isEmpty
    }

    static func centeredCoverCrop(imageSize: CGSize, aspectRatio: CGFloat) -> CGRect {
        let width = imageSize.width
        let height = imageSize.height
        guard width > 0, height > 0, aspectRatio > 0 else { return .null }

        let sourceAspectRatio = width / height
        if sourceAspectRatio > aspectRatio {
            let cropWidth = height * aspectRatio
            return CGRect(x: (width - cropWidth) / 2, y: 0, width: cropWidth, height: height)
        }

        let cropHeight = width / aspectRatio
        return CGRect(x: 0, y: (height - cropHeight) / 2, width: width, height: cropHeight)
    }
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
    #if os(iOS)
    @Published private(set) var systemVolume: Float = AVAudioSession.sharedInstance().outputVolume
    #endif

    @Published var swfContentType: SwfContentType = .animation

    @Published var showControlBar: Bool = true
    @Published var showVirtualControls: Bool = true
    @Published var playerMode: PlayerMode = .normal
    private let playerViewModel = PlayerViewModel()
    private enum StageMaximizedExitIntent {
        case keepCurrentMode
        case enterNormalMode
    }

    @Published var currentFileURL: URL?
    @Published var recentFiles: [RecentFile] = [] {
        didSet { LibraryPersistence.shared.saveRecentFiles(recentFiles) }
    }
    @Published var bookmarks: [URL] = []
    let bookmarkManager = BookmarkManager.shared

    var favoriteEntries: [Bookmark] { bookmarkManager.bookmarks }

    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var searchFocusRequest: Int = 0

    lazy var searchViewModel = SearchViewModel(
        searchService: SearchService.shared,
        libraryService: LibraryService.shared,
        appState: self
    )

    @Published var librarySize: String = "--"
    @Published var swfCount: Int = 0

    @Published var selectedSection: Section = .library
    @Published var selectedCollectionID: UUID?
    @Published var showToolbar: Bool = true
    @Published var toolbarRefreshToken: Int = 0
    @Published var showDebugUI: Bool = false
    @Published private(set) var playerLoadState: PlayerLoadState = .idle
    @Published var errorMessage: String?
    @Published var sidebarCollapsed: Bool = false
    @Published var showSWFInfoPanel: Bool = false {
        didSet {
            guard showSWFInfoPanel else { return }
            showTraceConsole = false
            showDiagnostics = false
        }
    }
    @Published var showTraceConsole: Bool = false {
        didSet {
            guard showTraceConsole else { return }
            showSWFInfoPanel = false
            showDiagnostics = false
        }
    }
    @Published var showDiagnostics: Bool = false {
        didSet {
            guard showDiagnostics else { return }
            showSWFInfoPanel = false
            showTraceConsole = false
        }
    }
    @Published var playerIssues: [PlayerIssue] = []
    @Published private(set) var policyDiagnostics: [RufflePolicyDiagnostic] = []
    @Published var pendingPermissionRequest: PermissionRequestContext?
    private let playerInputCoordinator = PlayerInputCoordinator()
    private let inputRouter = InputRouter()
    private var stageInputFocused = false
    private lazy var controllerInputService = GameControllerInputService { [weak self] controllerID, action, isDown in
        self?.sendControllerGameAction(action, controllerID: controllerID, isDown: isDown)
    }
    private var isRestoringPlaybackPreferences = false
    private var pendingStageMaximizedExitIntent: StageMaximizedExitIntent?

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
    private var pendingPermissionRetryURL: URL?
    #if os(iOS)
    private var filePickerService: IOSFilePickerService?
    private var securityScopedURL: URL?
    #endif
    private var timelinePollTimer: Timer?
    private var loadTimeoutTask: Task<Void, Never>?
    private var loadStatePollingTask: Task<Void, Never>?
    private var loadCoordinator = PlayerLoadCoordinator()
    private var activeLoadRequestID: UUID?
    private var pendingStorageLibraryID: UUID?
    private var cancellables = Set<AnyCancellable>()
    #if os(iOS)
    private var pausedForSystemInterruption = false
    private var sceneIsActive = true
    private var playerSurfaceVisible = false
    private var systemVolumeObservation: NSKeyValueObservation?
    private weak var systemVolumeSlider: UISlider?
    #endif

    var libraryItems: [LibraryItem] {
        LibraryService.shared.items
    }

    var isLoading: Bool {
        if case .loading = playerLoadState {
            return true
        }
        return false
    }

    init() {
        playerViewModel.onControlBarVisibilityChanged = { [weak self] isVisible in
            self?.showControlBar = isVisible
        }
        setupNotifications()
        _ = controllerInputService
        setupFullscreenObserver()
        #if os(iOS)
        setupSystemVolumeObservation()
        #endif
        restoreSettings()
        setupPersistence()
        let migrationReport = LibraryService.shared.migrateIfNeeded()
        if migrationReport.requiresUserAction {
            playerIssues = [.libraryMigrationFailed]
        }
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
        playerMode = settings.defaultPlayerMode
    }

    private func setupPersistence() {
        let s = SettingsPersistence.shared
        $quality.sink { [weak self] value in
            guard let self, !self.isRestoringPlaybackPreferences else { return }
            s.quality = value.rawValue
            self.bridge?.setQuality(value)
            self.persistPlaybackPreferences()
        }.store(in: &cancellables)
        $volume.sink { [weak self] value in
            guard let self, !self.isRestoringPlaybackPreferences else { return }
            s.volume = value
            self.persistPlaybackPreferences()
        }.store(in: &cancellables)
        $isMuted.sink { [weak self] value in
            guard let self, !self.isRestoringPlaybackPreferences else { return }
            s.isMuted = value
            self.persistPlaybackPreferences()
        }.store(in: &cancellables)
        $isLooping.sink { [weak self] value in
            guard let self, !self.isRestoringPlaybackPreferences else { return }
            s.isLooping = value
            self.bridge?.setLooping(value)
            self.persistPlaybackPreferences()
        }.store(in: &cancellables)
        $playbackSpeed.sink { [weak self] value in
            guard let self, !self.isRestoringPlaybackPreferences else { return }
            s.speed = value
            self.persistPlaybackPreferences()
        }.store(in: &cancellables)
        $showDebugUI.sink { s.showDebugUI = $0 }.store(in: &cancellables)
        $showToolbar.sink { s.showToolbar = $0 }.store(in: &cancellables)
        $maxExecutionDuration.sink { [weak self] value in
            s.maxExecutionDuration = value
            self?.bridge?.setMaxExecutionDuration(Float(value))
        }.store(in: &cancellables)
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
            selector: #selector(handleFullscreenEnter),
            name: NSWindow.didEnterFullScreenNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFullscreenExit),
            name: NSWindow.didExitFullScreenNotification,
            object: nil
        )
        #endif
    }

    @objc private func handleFullscreenEnter() {
        isFullscreen = true
        bridge?.setFullscreen(true)
    }

    @objc private func handleFullscreenExit() {
        isFullscreen = false
        bridge?.setFullscreen(false)
        guard isStageMaximized else { return }
        let intent = pendingStageMaximizedExitIntent ?? defaultStageMaximizedExitIntent(restoreWorkspaceChrome: true)
        pendingStageMaximizedExitIntent = nil
        finishStageMaximizedExit(intent: intent)
    }

    @objc private func handleOpenSWF(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        openFile(url)
    }

    @discardableResult
    func initializeBridge(metalLayer: CAMetalLayer, width: UInt32, height: UInt32, scaleFactor: Float) -> Bool {
        if let bridge {
            bridge.updateSurface(metalLayer: metalLayer, width: width, height: height)
            bridge.setViewport(width: width, height: height, scaleFactor: scaleFactor)
            updateIOSRenderLoopAvailability()
            return true
        }
        let runtimeProfile = resolvedRuntimeProfile(for: currentFileURL)
        let accessPolicies = resolvedEngineAccessPolicies(for: currentFileURL)
        bridge = RuffleBridge(
            metalLayer: metalLayer, width: width, height: height, scaleFactor: scaleFactor,
            quality: runtimeProfile.quality.rawValue,
            autoplay: runtimeProfile.autoplay,
            maxExecutionSecs: Float(runtimeProfile.maxExecutionDuration),
            networkAccess: accessPolicies.network,
            filesystemAccess: accessPolicies.filesystem,
            storageRoot: pendingStorageLibraryID == nil ? nil : SharedObjectStoragePaths().rootURL,
            storageLibraryID: pendingStorageLibraryID
        )
        bridge?.onFrameUpdate = { [weak self] fps, frame in
            DispatchQueue.main.async {
                self?.debugFrameRate = fps
                self?.debugCurrentFrame = frame
            }
        }
        bridge?.onPolicyDiagnostic = { [weak self] diagnostic in
            self?.recordEnginePolicyDiagnostic(diagnostic)
        }
        bridge?.setVolume(isMuted ? 0.0 : volume)
        bridge?.setQuality(quality)
        bridge?.setLooping(isLooping)
        bridge?.setSpeed(playbackSpeed)
        bridge?.setAutoplay(runtimeProfile.autoplay)
        bridge?.setMaxExecutionDuration(Float(runtimeProfile.maxExecutionDuration))
        applyLetterbox(runtimeProfile.letterbox)
        updateIOSRenderLoopAvailability()

        guard bridge != nil else {
            presentPlayerIssue(.renderInitFailure)
            return false
        }

        if let url = pendingFileURL {
            if let libraryID = pendingStorageLibraryID {
                bridge?.configureSharedObjectStorage(root: SharedObjectStoragePaths().rootURL, libraryID: libraryID)
            }
            guard bridge?.loadURL(url) == true else {
                pendingFileURL = nil
                failPlayerLoad(activeLoadRequestID, issue: .ruffleLoadFailure)
                return false
            }
            pendingFileURL = nil
            if let requestID = activeLoadRequestID {
                startLoadStatePolling(for: requestID)
            }
        }
        return true
    }

    func openFile(_ url: URL) {
        if currentFileURL != url {
            PermissionPolicyService.shared.clearSessionAllowances(for: currentFileURL)
        }
        #if os(iOS)
        if securityScopedURL != url {
            securityScopedURL?.stopAccessingSecurityScopedResource()
            securityScopedURL = url.startAccessingSecurityScopedResource() ? url : nil
        }
        #endif
        let requestID = beginPlayerLoad()
        errorMessage = nil
        playerIssues = []
        policyDiagnostics = []
        showDiagnostics = false
        currentFileURL = url
        loadTimeoutTask?.cancel()

        if let issue = fileAccessIssue(for: url) {
            selectedSection = .player
            failPlayerLoad(requestID, issue: issue)
            return
        }

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

        let libraryItem: LibraryItem
        if LibraryService.shared.contains(url) {
            LibraryService.shared.update(LibraryService.shared.item(for: url)!.id) {
                $0.lastOpened = Date()
            }
            libraryItem = LibraryService.shared.item(for: url)!
        } else {
            let item = LibraryItem(
                url: url,
                fileSize: Int64(resourceValues?.fileSize ?? 0),
                lastOpened: Date()
            )
            LibraryService.shared.add(item)
            libraryItem = LibraryService.shared.item(for: url)!
        }
        pendingStorageLibraryID = libraryItem.id
        // Reuse the cached classification while the new player loads. Unknown files
        // stay in the non-interactive state until the engine confirms their content.
        swfContentType = libraryItem.contentType == .interactive ? .interactive : .animation

        restorePlaybackPreferences(for: url)

        loadTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            self?.failPlayerLoad(requestID, issue: .scriptTimeout, fallbackMessageKey: "error.loadTimeout")
        }

        if let bridge {
            bridge.configureSharedObjectStorage(root: SharedObjectStoragePaths().rootURL, libraryID: libraryItem.id)
            let accessPolicies = resolvedEngineAccessPolicies(for: url)
            bridge.setAccessPolicies(network: accessPolicies.network, filesystem: accessPolicies.filesystem)
            guard bridge.loadURL(url) else {
                failPlayerLoad(requestID, issue: .ruffleLoadFailure)
                return
            }
            startLoadStatePolling(for: requestID)
        } else {
            pendingFileURL = url
        }
        selectedSection = .player
    }

    func syncPlayingState() {
        guard let bridge else { return }
        isPlaying = bridge.isPlaying()
    }

    private func afterMovieLoaded(for requestID: UUID) {
        guard completePlayerLoad(requestID, with: .ready) else { return }
        restoreLastPlaybackFrame()
        if Self.shouldAutoplayAfterMovieLoads(resolvedRuntimeProfile(for: currentFileURL)) {
            bridge?.setPlaying(true)
            syncPlayingState()
        }
        detectContentType()
        enterGameModeIfNeeded()
        updateIOSRenderLoopAvailability()
        #if os(macOS)
        startTimelinePolling()
        #endif
        adoptStageSize()
        persistCurrentMetadata()
        NotificationCenter.default.post(name: .swfLoaded, object: nil)
        scheduleThumbnailCapture(for: currentFileURL)
        scheduleControlBarHide()
    }

    nonisolated static func shouldAutoplayAfterMovieLoads(_ runtimeProfile: RuntimeDefaults) -> Bool {
        runtimeProfile.autoplay
    }

    private func beginPlayerLoad() -> UUID {
        loadTimeoutTask?.cancel()
        loadStatePollingTask?.cancel()
        let requestID = loadCoordinator.begin()
        activeLoadRequestID = requestID
        playerLoadState = loadCoordinator.state
        return requestID
    }

    private func completePlayerLoad(_ requestID: UUID, with state: PlayerLoadState) -> Bool {
        guard loadCoordinator.complete(requestID, with: state) else { return false }
        playerLoadState = loadCoordinator.state
        activeLoadRequestID = nil
        loadTimeoutTask?.cancel()
        loadStatePollingTask?.cancel()
        return true
    }

    private func failPlayerLoad(_ requestID: UUID?, issue: PlayerIssue, fallbackMessageKey: String? = nil) {
        guard let requestID,
              completePlayerLoad(requestID, with: .failed(issue == .scriptTimeout ? .timedOut : .engineLoadFailed))
        else { return }
        presentPlayerIssue(issue, fallbackMessageKey: fallbackMessageKey)
    }

    private func startLoadStatePolling(for requestID: UUID) {
        loadStatePollingTask?.cancel()
        loadStatePollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled,
                      let self,
                      self.activeLoadRequestID == requestID
                else { return }

                switch self.bridge?.loadState() {
                case .ready:
                    self.afterMovieLoaded(for: requestID)
                    return
                case .failed:
                    self.failPlayerLoad(requestID, issue: .ruffleLoadFailure)
                    return
                case .idle, .loading, .none:
                    continue
                }
            }
        }
    }

    private func scheduleThumbnailCapture(for url: URL?) {
        guard let url else { return }
        let delays: [TimeInterval] = [0.45, 0.9, 1.6, 2.8]

        for (index, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.currentFileURL == url else { return }
                let isFinalAttempt = index == delays.indices.last
                _ = self.captureThumbnail(markFailure: isFinalAttempt)
            }
        }
    }

    private func restoreLastPlaybackFrame() {
        guard let url = currentFileURL,
              let item = LibraryService.shared.item(for: url),
              let frame = item.playbackPreferences?.lastPlaybackFrame ?? item.lastPlaybackFrame,
              frame > 0
        else { return }

        bridge?.seekFrame(frame)
        currentFrame = frame
        seekPosition = Double(frame)
    }

    private func detectContentType() {
        let info = bridge?.getPlaybackInfo()
        let totalFrames = info?.totalFrames ?? 0
        if totalFrames > 1 {
            swfContentType = .animation
        } else {
            swfContentType = .interactive
        }
        if let url = currentFileURL, let item = LibraryService.shared.item(for: url) {
            LibraryService.shared.update(item.id) {
                $0.contentType = swfContentType == .animation ? .animation : .interactive
            }
        }
        Logger.appState.info("content type: \(self.swfContentType.rawValue) (totalFrames=\(totalFrames))")
    }

    private func enterGameModeIfNeeded() {
        guard swfContentType == .interactive else { return }
        if playerMode == .normal {
            setPlayerMode(.game)
        } else {
            applyPlayerModeLayout()
        }
        requestPlayerFocus()
        handlePlayerPointerActivity()
    }

    func showControlBarTemporarily() {
        playerViewModel.showControlBarTemporarily(isPlaying: isPlaying)
        showControlBar = playerViewModel.showControlBar
    }

    func handlePlayerPointerActivity() {
        playerInputCoordinator.pointerMoved(isPlaying: isPlaying, mode: playerMode) { [weak self] visible in
            self?.showControlBar = visible
        }
    }

    private func fileAccessIssue(for url: URL) -> PlayerIssue? {
        guard url.isFileURL else { return nil }
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else {
            return .fileMissing
        }
        guard FileManager.default.isReadableFile(atPath: path) else {
            return .fileInaccessible
        }
        return nil
    }

    func presentPlayerIssue(_ issue: PlayerIssue, fallbackMessageKey: String? = nil) {
        loadTimeoutTask?.cancel()
        loadStatePollingTask?.cancel()
        playerIssues = [issue]
        errorMessage = fallbackMessageKey.map { LocalizationManager.shared.localized($0) }
            ?? issue.displayMessage(localize: LocalizationManager.shared.localized)
        if let url = currentFileURL {
            markLibraryItem(for: url, issue: issue)
        }
    }

    private func markLibraryItem(for url: URL, issue: PlayerIssue) {
        guard let item = LibraryService.shared.item(for: url) else { return }
        LibraryService.shared.update(item.id) {
            switch issue {
            case .fileMissing:
                $0.availabilityStatus = .missing
            case .fileDamaged, .ruffleLoadFailure, .unsupportedAPI, .scriptTimeout, .networkBlocked, .filesystemBlocked:
                $0.compatibilityStatus = .unsupported
            default:
                break
            }
        }
    }

    func makeCompatibilityReport() -> CompatibilityReport {
        let metadata = currentMetadataForDiagnostics()
        let engineVersion = metadata.flatMap { $0.playerVersion > 0 ? String($0.playerVersion) : nil }
        let traceMessages = TraceConsole.shared.messages.map(\.text) + policyDiagnostics.map {
            "Policy \($0.kind.rawValue): \($0.target)"
        }
        return DiagnosticsService.shared.makeReport(
            fileURL: currentFileURL,
            fileSize: currentFileSizeForDiagnostics(),
            metadata: metadata,
            currentFrame: currentFrame,
            issues: playerIssues,
            permissionPolicy: permissionPolicySummary(),
            traceMessages: traceMessages,
            engineVersion: engineVersion
        )
    }

    func requestPermission(scope: PermissionScope, requestedResource: String? = nil) -> Bool {
        let fileURL = currentFileURL
        switch PermissionPolicyService.shared.evaluation(for: fileURL, scope: scope) {
        case .allowed:
            return true
        case .denied:
            recordBlockedPermission(scope)
            return false
        case .requiresPrompt:
            pendingPermissionRequest = PermissionRequestContext(
                fileURL: fileURL,
                scope: scope,
                requestedResource: requestedResource
            )
            return false
        }
    }

    private func resolvedEngineAccessPolicies(for fileURL: URL?) -> (network: UInt32, filesystem: UInt32) {
        let policies = PermissionPolicyService.shared
        let network = policies.evaluation(for: fileURL, scope: .network) == .allowed ? UInt32(1) : UInt32(0)
        let filesystem = policies.evaluation(for: fileURL, scope: .filesystem) == .allowed ? UInt32(1) : UInt32(0)
        return (network, filesystem)
    }

    private func recordEnginePolicyDiagnostic(_ diagnostic: RufflePolicyDiagnostic) {
        policyDiagnostics.append(diagnostic)
        if policyDiagnostics.count > 50 {
            policyDiagnostics.removeFirst(policyDiagnostics.count - 50)
        }

        switch diagnostic.kind {
        case .filesystemDenied:
            handleEnginePermissionDenial(scope: .filesystem, target: diagnostic.target, issue: .filesystemBlocked)
        case .networkDenied, .navigationDenied, .socketDenied:
            handleEnginePermissionDenial(scope: .network, target: diagnostic.target, issue: .networkBlocked)
        case .networkUnsupported, .unsupportedScheme:
            break
        }
    }

    private func handleEnginePermissionDenial(scope: PermissionScope, target: String, issue: PlayerIssue) {
        presentPlayerIssue(issue)

        switch PermissionPolicyService.shared.evaluation(for: currentFileURL, scope: scope) {
        case .requiresPrompt:
            if pendingPermissionRequest?.scope != scope || pendingPermissionRequest?.fileURL != currentFileURL {
                _ = requestPermission(scope: scope, requestedResource: target)
            }
        case .allowed:
            schedulePermissionRetry()
        case .denied:
            break
        }
    }

    func resolvePendingPermission(with decision: PermissionDecision) {
        guard let request = pendingPermissionRequest else { return }
        pendingPermissionRequest = nil
        let result = PermissionPolicyService.shared.apply(decision, for: request.fileURL, scope: request.scope)
        if result == .allowed {
            schedulePermissionRetry()
        } else if result == .denied {
            recordBlockedPermission(request.scope)
        }
    }

    private func schedulePermissionRetry() {
        guard let url = currentFileURL, pendingPermissionRetryURL == nil else { return }
        pendingPermissionRetryURL = url
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingPermissionRetryURL == url else { return }
            self.pendingPermissionRetryURL = nil
            guard self.currentFileURL == url else { return }
            self.openFile(url)
        }
    }

    private func recordBlockedPermission(_ scope: PermissionScope) {
        switch scope {
        case .network:
            presentPlayerIssue(.networkBlocked)
        case .filesystem:
            presentPlayerIssue(.filesystemBlocked)
        }
    }

    private func permissionPolicySummary() -> String {
        PermissionPolicyService.shared.policySummary(for: currentFileURL)
            .map { localizedPermissionPolicyLine($0) }
            .joined(separator: "; ")
    }

    private func localizedPermissionPolicyLine(_ rawLine: String) -> String {
        let parts = rawLine.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return rawLine }
        return "\(localizedPermissionScope(parts[0])): \(localizedPermissionDecision(parts[1]))"
    }

    private func localizedPermissionScope(_ rawValue: String) -> String {
        switch PermissionScope(rawValue: rawValue) {
        case .network:
            return LocalizationManager.shared.localized("permission.scope.network")
        case .filesystem:
            return LocalizationManager.shared.localized("permission.scope.filesystem")
        case nil:
            return rawValue
        }
    }

    private func localizedPermissionDecision(_ rawValue: String) -> String {
        if let globalDefault = PermissionGlobalDefault(rawValue: rawValue) {
            switch globalDefault {
            case .alwaysAsk:
                return LocalizationManager.shared.localized("permission.global.alwaysAsk")
            case .allow:
                return LocalizationManager.shared.localized("permission.global.allow")
            case .deny:
                return LocalizationManager.shared.localized("permission.global.deny")
            }
        }

        switch PermissionDecision(rawValue: rawValue) {
        case .allowForFile:
            return LocalizationManager.shared.localized("permission.decision.allowForFile")
        case .denyForFile:
            return LocalizationManager.shared.localized("permission.decision.denyForFile")
        case .allowOnce:
            return LocalizationManager.shared.localized("permission.decision.allowOnce")
        case .alwaysAsk:
            return LocalizationManager.shared.localized("permission.decision.alwaysAsk")
        case .useGlobalDefault:
            return LocalizationManager.shared.localized("permission.decision.useGlobalDefault")
        case nil:
            return rawValue
        }
    }

    private func currentMetadataForDiagnostics() -> SWFMetadata? {
        if let url = currentFileURL,
           let itemMetadata = LibraryService.shared.item(for: url)?.metadata {
            return itemMetadata
        }

        guard let bridgeMetadata = bridge?.getMetadata() else { return nil }
        return SWFMetadata(
            stageWidth: bridgeMetadata.movieWidth,
            stageHeight: bridgeMetadata.movieHeight,
            frameRate: bridgeMetadata.frameRate,
            totalFrames: bridgeMetadata.totalFrames,
            swfVersion: bridgeMetadata.swfVersion,
            playerVersion: bridgeMetadata.playerVersion,
            isActionScript3: bridgeMetadata.isAS3
        )
    }

    private func currentFileSizeForDiagnostics() -> Int64 {
        guard let url = currentFileURL else { return 0 }
        if let item = LibraryService.shared.item(for: url), item.fileSize > 0 {
            return item.fileSize
        }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    func handlePlayerEscape() {
        playerInputCoordinator.handleEscape(
            isStageMaximized: isStageMaximized,
            mode: playerMode,
            exitStage: { [weak self] in self?.exitStageMaximized() },
            setMode: { [weak self] mode in self?.setPlayerMode(mode) }
        )
    }

    func handleStageDoubleClick() {
        playerInputCoordinator.handleStageDoubleClick(mode: playerMode) { [weak self] in
            guard let self else { return }
            if self.isStageMaximized {
                self.exitStageMaximized()
            } else {
                self.toggleStageMaximized()
            }
        }
    }

    func keepControlBarVisible() {
        preparePlayerChromeForStableLayout()
    }

    private func preparePlayerChromeForStableLayout() {
        playerInputCoordinator.cancelOverlayHide()
        playerViewModel.keepControlBarVisible()
        showControlBar = playerViewModel.showControlBar
    }

    private func prepareNormalPlayerLayout() {
        preparePlayerChromeForStableLayout()
        sidebarCollapsed = false
    }

    private func scheduleControlBarHide() {
        playerViewModel.showControlBarTemporarily(isPlaying: isPlaying)
        showControlBar = playerViewModel.showControlBar
    }

    func controlBarOnPause() {
        playerViewModel.controlBarOnPause()
        showControlBar = playerViewModel.showControlBar
        playerInputCoordinator.playbackPaused { [weak self] visible in
            self?.showControlBar = visible
        }
    }

    func adoptStageSize() {
        guard let bridge else { return }
        let (sw, sh) = bridge.stageSize()
        guard sw > 0, sh > 0 else { return }
        stageWidth = sw
        stageHeight = sh
        updateIOSOrientations()
    }

    private func persistCurrentMetadata() {
        guard let url = currentFileURL,
              let item = LibraryService.shared.item(for: url),
              let bridgeMetadata = bridge?.getMetadata()
        else { return }

        let metadata = SWFMetadata(
            stageWidth: bridgeMetadata.movieWidth,
            stageHeight: bridgeMetadata.movieHeight,
            frameRate: bridgeMetadata.frameRate,
            totalFrames: bridgeMetadata.totalFrames,
            swfVersion: bridgeMetadata.swfVersion,
            playerVersion: bridgeMetadata.playerVersion,
            isActionScript3: bridgeMetadata.isAS3
        )

        LibraryService.shared.update(item.id) {
            $0.metadata = metadata
            $0.lastPlaybackFrame = currentFrame
        }
    }

    private func restorePlaybackPreferences(for url: URL) {
        guard let item = LibraryService.shared.item(for: url) else { return }
        let settings = SettingsPersistence.shared
        let runtimeProfile = resolvedRuntimeProfile(for: url)
        let preferences = item.playbackPreferences ?? PlaybackPreferences(
            volume: settings.volume,
            isMuted: settings.isMuted,
            qualityRawValue: settings.quality,
            letterbox: settings.letterbox,
            isLooping: settings.isLooping,
            speed: settings.speed,
            lastPlaybackFrame: item.lastPlaybackFrame,
            preferredMode: settings.defaultPlayerMode
        )

        isRestoringPlaybackPreferences = true
        volume = preferences.volume
        isMuted = preferences.isMuted
        quality = runtimeProfile.quality
        isLooping = runtimeProfile.isLooping
        playbackSpeed = runtimeProfile.playbackSpeed
        maxExecutionDuration = runtimeProfile.maxExecutionDuration
        showVirtualControls = item.showsVirtualControls ?? true
        playerMode = preferences.preferredMode
        isRestoringPlaybackPreferences = false

        bridge?.setVolume(isMuted ? 0.0 : volume)
        bridge?.setQuality(quality)
        bridge?.setLooping(isLooping)
        bridge?.setSpeed(playbackSpeed)
        bridge?.setAutoplay(runtimeProfile.autoplay)
        bridge?.setMaxExecutionDuration(Float(runtimeProfile.maxExecutionDuration))
        applyLetterbox(runtimeProfile.letterbox)
        applyPlayerModeLayout()
    }

    private func resolvedRuntimeProfile(for url: URL?) -> RuntimeDefaults {
        let settings = SettingsPersistence.shared
        let defaults = RuntimeDefaults(
            quality: RuffleQuality(rawValue: settings.quality) ?? .high,
            letterbox: settings.letterbox,
            playbackSpeed: settings.speed,
            isLooping: settings.isLooping,
            autoplay: settings.autoplay,
            maxExecutionDuration: settings.maxExecutionDuration
        )
        guard let url else { return defaults }
        return LibraryService.shared.effectiveRuntimeProfile(for: url, defaults: defaults)
    }

    func applyRuntimeProfile(for itemID: UUID) {
        guard let item = LibraryService.shared.item(with: itemID), item.url == currentFileURL else { return }
        restorePlaybackPreferences(for: item.url)
    }

    private func persistPlaybackPreferences() {
        guard !isRestoringPlaybackPreferences,
              let url = currentFileURL,
              let item = LibraryService.shared.item(for: url)
        else { return }

        let preferences = PlaybackPreferences(
            volume: volume,
            isMuted: isMuted,
            qualityRawValue: quality.rawValue,
            letterbox: SettingsPersistence.shared.letterbox,
            isLooping: isLooping,
            speed: playbackSpeed,
            lastPlaybackFrame: currentFrame,
            preferredMode: playerMode
        )

        LibraryService.shared.update(item.id) {
            $0.playbackPreferences = preferences
            $0.lastPlaybackFrame = currentFrame
        }
    }

    private func applyLetterbox(_ value: String) {
        #if RUST_FFI_AVAILABLE
        switch value {
        case "on":
            bridge?.setLetterboxMode(RuffleLetterbox_On)
        case "off":
            bridge?.setLetterboxMode(RuffleLetterbox_Off)
        default:
            bridge?.setLetterboxMode(RuffleLetterbox_Fullscreen)
        }
        #endif
    }

    func setPlayerMode(_ mode: PlayerMode) {
        if mode == .normal {
            enterNormalPlayerMode()
        } else {
            playerMode = mode
            applyPlayerModeLayout()
        }
        persistPlaybackPreferences()
    }

    private func applyPlayerModeLayout() {
        switch playerMode {
        case .normal:
            enterNormalPlayerMode()
        case .cinema:
            sidebarCollapsed = true
            preparePlayerChromeForStableLayout()
        case .game:
            sidebarCollapsed = true
            preparePlayerChromeForStableLayout()
            if !isStageMaximized {
                toggleStageMaximized()
            }
        }
    }

    private func enterNormalPlayerMode() {
        if isStageMaximized {
            requestStageMaximizedExit(intent: .enterNormalMode)
            return
        }
        applyNormalPlayerLayout()
    }

    private func applyNormalPlayerLayout() {
        prepareNormalPlayerLayout()
        playerMode = .normal
    }

    func requestPlayerFocus() {
        NotificationCenter.default.post(name: .focusPlayerStage, object: nil)
    }

    private func updateIOSOrientations() {
        #if os(iOS)
        guard isStageMaximized else {
            IOSOrientationController.update(to: .portrait)
            return
        }

        IOSOrientationController.update(to: stageHeight > stageWidth ? .portrait : .landscape)
        #endif
    }

    #if os(iOS)
    private func setupSystemVolumeObservation() {
        let audioSession = AVAudioSession.sharedInstance()
        systemVolumeObservation = audioSession.observe(\AVAudioSession.outputVolume, options: [.initial, .new]) { [weak self] session, _ in
            let value = session.outputVolume
            Task { @MainActor [weak self] in
                guard let self, abs(self.systemVolume - value) > 0.001 else { return }
                systemVolume = value
                volume = value
                bridge?.setVolume(isMuted ? 0 : value)
                persistPlaybackPreferences()
            }
        }
    }

    func attachSystemVolumeSlider(_ slider: UISlider?) {
        systemVolumeSlider = slider
        slider?.setValue(systemVolume, animated: false)
    }

    func setSystemVolume(_ newVolume: Float) {
        let value = min(max(newVolume, 0), 1)
        systemVolumeSlider?.setValue(value, animated: false)
        systemVolume = value
        setVolume(value)
    }
    #endif

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
        persistPlaybackPreferences()
        controlBarOnPause()
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

    func removeLibraryItem(_ itemID: UUID) {
        guard let item = LibraryService.shared.item(with: itemID) else { return }

        if LibraryRemovalPolicy.shouldClosePlayer(currentFileURL: currentFileURL, removing: item) {
            closeFile()
        }
        LibraryService.shared.remove(itemID)
    }

    func closeFile() {
        inputRouter.releaseAll { [weak self] keyCode, charCode, isDown, modifiers in
            self?.bridge?.sendKeyEvent(keyCode: keyCode, charCode: charCode, isDown: isDown, modifiers: modifiers)
        }
        if let requestID = activeLoadRequestID {
            _ = loadCoordinator.cancel(requestID)
            playerLoadState = loadCoordinator.state
            activeLoadRequestID = nil
        }
        loadTimeoutTask?.cancel()
        loadStatePollingTask?.cancel()
        persistPlaybackPreferences()
        pausePlayback()
        stopTimelinePolling()
        enterNormalPlayerMode()
        currentFileURL = nil
        updateIOSRenderLoopAvailability()
        selectedSection = .library
    }

    func routePlayerKeyEvent(
        keyCode: UInt32,
        charCode: UInt32,
        isDown: Bool,
        modifiers: UInt32,
        source: InputSource = .keyboard
    ) {
        inputRouter.route(
            keyCode: keyCode,
            charCode: charCode,
            isDown: isDown,
            modifiers: modifiers,
            source: source,
            isInteractive: swfContentType == .interactive,
            isStageFocused: selectedSection == .player && currentFileURL != nil
                && (source != .keyboard || stageInputFocused)
        ) { [weak self] keyCode, charCode, isDown, modifiers in
            self?.bridge?.sendKeyEvent(keyCode: keyCode, charCode: charCode, isDown: isDown, modifiers: modifiers)
        }
    }

    func currentInputProfile() -> InputProfile {
        guard let url = currentFileURL,
              let item = LibraryService.shared.item(for: url) else {
            return InputProfile()
        }
        return item.inputProfile ?? InputProfile()
    }

    func updateInputProfile(_ profile: InputProfile) {
        guard let url = currentFileURL,
              let item = LibraryService.shared.item(for: url) else { return }
        LibraryService.shared.update(item.id) { $0.inputProfile = profile }
    }

    func sendVirtualGameAction(_ action: GameAction, isDown: Bool) {
        let profile = currentInputProfile()
        guard let keyCode = profile.mapping[action] else { return }
        routePlayerKeyEvent(keyCode: keyCode, charCode: 0, isDown: isDown, modifiers: 0, source: .virtual(action))
    }

    func toggleVirtualControls() {
        showVirtualControls.toggle()
        guard let url = currentFileURL,
              let item = LibraryService.shared.item(for: url)
        else { return }
        LibraryService.shared.update(item.id) { $0.showsVirtualControls = showVirtualControls }
    }

    func sendControllerGameAction(_ action: GameAction, controllerID: UUID, isDown: Bool) {
        let profile = currentInputProfile()
        guard let keyCode = profile.mapping[action] else { return }
        routePlayerKeyEvent(
            keyCode: keyCode,
            charCode: 0,
            isDown: isDown,
            modifiers: 0,
            source: .controller(controllerID, action)
        )
    }

    func releasePlayerInput() {
        inputRouter.releaseAll { [weak self] keyCode, charCode, isDown, modifiers in
            self?.bridge?.sendKeyEvent(keyCode: keyCode, charCode: charCode, isDown: isDown, modifiers: modifiers)
        }
    }

    func setStageInputFocused(_ focused: Bool) {
        guard stageInputFocused != focused else { return }
        stageInputFocused = focused
        if !focused {
            releasePlayerInput()
        }
    }

    func retryCurrentFile() {
        guard let url = currentFileURL else { return }
        openFile(url)
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        bridge?.setVolume(newVolume)
        persistPlaybackPreferences()
    }

    func toggleMute() {
        isMuted.toggle()
        bridge?.setVolume(isMuted ? 0.0 : volume)
        persistPlaybackPreferences()
    }

    func stepForward() {
        bridge?.tick(1.0 / 60.0)
    }

    func toggleFullscreen() {
        #if os(macOS)
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
        #else
        isFullscreen.toggle()
        bridge?.setFullscreen(isFullscreen)
        #endif
    }

    func toggleStageMaximized() {
        #if os(macOS)
        guard !isStageMaximized else { return }
        isStageMaximized = true
        setWindowToolbarVisible(false)
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
        #else
        isStageMaximized.toggle()
        updateIOSOrientations()
        #endif
    }

    func exitStageMaximized(restoreWorkspaceChrome: Bool = true) {
        guard isStageMaximized else { return }
        requestStageMaximizedExit(intent: defaultStageMaximizedExitIntent(restoreWorkspaceChrome: restoreWorkspaceChrome))
    }

    private func requestStageMaximizedExit(intent: StageMaximizedExitIntent) {
        guard isStageMaximized else { return }
        #if os(macOS)
        pendingStageMaximizedExitIntent = intent
        NSApp.keyWindow?.toggleFullScreen(nil)
        #else
        finishStageMaximizedExit(intent: intent)
        #endif
    }

    private func defaultStageMaximizedExitIntent(restoreWorkspaceChrome: Bool) -> StageMaximizedExitIntent {
        restoreWorkspaceChrome && playerMode == .game ? .enterNormalMode : .keepCurrentMode
    }

    private func finishStageMaximizedExit(intent: StageMaximizedExitIntent) {
        switch intent {
        case .enterNormalMode:
            applyNormalPlayerLayout()
            persistPlaybackPreferences()
        case .keepCurrentMode:
            preparePlayerChromeForStableLayout()
        }
        isStageMaximized = false
        toolbarRefreshToken += 1
        setWindowToolbarVisible(true)
        updateIOSOrientations()
    }

    private func setWindowToolbarVisible(_ visible: Bool) {
        #if os(macOS)
        (NSApp.keyWindow ?? NSApp.mainWindow)?.toolbar?.isVisible = visible
        DispatchQueue.main.async {
            (NSApp.keyWindow ?? NSApp.mainWindow)?.toolbar?.isVisible = visible
        }
        #endif
    }

    func toggleSidebar() {
        sidebarCollapsed.toggle()
    }

    func updateSearchText(_ text: String) {
        searchText = text
        searchViewModel.updateSearchText(text)
        isSearching = searchViewModel.isSearching
    }

    func clearSearch() {
        searchText = ""
        searchViewModel.clearSearch()
        isSearching = false
    }

    func requestSearchFocus() {
        if isStageMaximized {
            exitStageMaximized(restoreWorkspaceChrome: false)
        }
        selectedSection = .library
        sidebarCollapsed = false
        searchFocusRequest += 1
    }

    func selectSection(_ section: Section) {
        selectedCollectionID = nil
        selectedSection = section
    }

    func selectCollection(_ id: UUID) {
        selectedCollectionID = id
        selectedSection = .library
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

    func locateLibraryItem(_ itemID: UUID) {
        #if os(iOS)
        let service = IOSFilePickerService()
        filePickerService = service
        service.pickSWFFile { [weak self] url in
            self?.filePickerService = nil
            guard let url else { return }
            DispatchQueue.main.async {
                LibraryService.shared.locateFile(for: itemID, newURL: url)
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

    @discardableResult
    func captureThumbnail(markFailure: Bool = true) -> Bool {
        #if os(macOS) || os(iOS)
        guard let url = currentFileURL,
              let item = LibraryService.shared.item(for: url),
              shouldAttemptThumbnail(for: item)
        else { return false }

        guard let cgImage = currentStageImage()
        else {
            if markFailure { markThumbnailFailure(for: item.id) }
            return false
        }

        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else {
            if markFailure { markThumbnailFailure(for: item.id) }
            return false
        }

        guard let png = pngThumbnailData(from: cgImage, maxPixelSize: ThumbnailCapturePolicy.coverMaxPixelSize) else {
            if markFailure { markThumbnailFailure(for: item.id) }
            return false
        }

        if let idx = recentFiles.firstIndex(where: { $0.url == currentFileURL }) {
            recentFiles[idx].thumbnailData = png
        }

        guard let identifier = ThumbnailService.shared.store(png, for: item.id) else {
            if markFailure { markThumbnailFailure(for: item.id) }
            return false
        }

        LibraryService.shared.update(item.id) {
            $0.thumbnailIdentifier = identifier
            $0.thumbnailData = nil
            $0.thumbnailGenerationFailedAt = nil
        }
        return true
        #else
        return false
        #endif
    }

    private func shouldAttemptThumbnail(for item: LibraryItem) -> Bool {
        ThumbnailCapturePolicy.shouldAttempt(thumbnailIdentifier: item.thumbnailIdentifier)
    }

    private func markThumbnailFailure(for id: UUID) {
        LibraryService.shared.update(id) {
            $0.thumbnailGenerationFailedAt = Date()
        }
    }

    #if os(macOS) || os(iOS)
    private func currentDrawableImage(from metalView: MTKView) -> CGImage? {
        guard let texture = metalView.currentDrawable?.texture else { return nil }
        return image(from: texture)
    }

    private func currentStageImage() -> CGImage? {
        guard let metalView = findPlayerMetalView() else { return nil }
        if let image = currentDrawableImage(from: metalView) {
            return image
        }
        return snapshotImage(of: metalView)
    }

    private func image(from texture: MTLTexture) -> CGImage? {
        let width = Int(texture.width)
        let height = Int(texture.height)
        guard width > 0, height > 0, !texture.isFramebufferOnly else { return nil }

        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        for index in stride(from: 0, to: pixelData.count, by: 4) {
            let blue = pixelData[index]
            pixelData[index] = pixelData[index + 2]
            pixelData[index + 2] = blue
        }

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private func pngThumbnailData(from image: CGImage, maxPixelSize: CGFloat) -> Data? {
        guard let coverImage = centerCroppedImage(image, aspectRatio: ThumbnailCapturePolicy.coverAspectRatio),
              let scaled = scaledImage(coverImage, maxPixelSize: maxPixelSize)
        else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, scaled, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func centerCroppedImage(_ image: CGImage, aspectRatio: CGFloat) -> CGImage? {
        let cropRect = ThumbnailCapturePolicy.centeredCoverCrop(
            imageSize: CGSize(width: image.width, height: image.height),
            aspectRatio: aspectRatio
        )
        guard !cropRect.isNull, cropRect.width > 0, cropRect.height > 0 else { return nil }

        return image.cropping(to: cropRect.integral)
    }

    private func scaledImage(_ image: CGImage, maxPixelSize: CGFloat) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let scale = min(maxPixelSize / CGFloat(width), maxPixelSize / CGFloat(height), 1.0)
        let scaledWidth = max(1, Int(CGFloat(width) * scale))
        let scaledHeight = max(1, Int(CGFloat(height) * scale))
        guard scaledWidth != width || scaledHeight != height else { return image }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: scaledWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        return context.makeImage()
    }

    private func findPlayerMetalView() -> MTKView? {
        #if os(macOS)
        findPlayerFrameView() as? MTKView
        #else
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .compactMap { findMTKView(in: $0) }
            .first
        #endif
    }

    #if os(macOS)
    private func snapshotImage(of view: MTKView) -> CGImage? {
        guard let window = view.window,
              let contentView = window.contentView,
              let windowImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                CGWindowID(window.windowNumber),
                [.boundsIgnoreFraming, .bestResolution]
              )
        else { return nil }

        let scale = CGFloat(windowImage.width) / max(window.frame.width, 1)
        let frameInWindow = view.convert(view.bounds, to: nil)
        let contentHeight = contentView.bounds.height
        let contentHeightPixels = contentHeight * scale
        let topInsetPixels = max(0, CGFloat(windowImage.height) - contentHeightPixels)

        let cropRect = CGRect(
            x: frameInWindow.minX * scale,
            y: topInsetPixels + (contentHeight - frameInWindow.maxY) * scale,
            width: frameInWindow.width * scale,
            height: frameInWindow.height * scale
        ).integral.intersection(CGRect(x: 0, y: 0, width: windowImage.width, height: windowImage.height))

        guard cropRect.width > 0, cropRect.height > 0 else { return nil }
        return windowImage.cropping(to: cropRect)
    }
    #endif

    #if os(iOS)
    private func snapshotImage(of view: MTKView) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = view.window?.screen.scale ?? UIScreen.main.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
        let image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        return image.cgImage
    }
    #endif
    #endif

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

    #if os(iOS)
    private func findMTKView(in view: UIView) -> MTKView? {
        if let metalView = view as? MTKView { return metalView }
        for subview in view.subviews {
            if let found = findMTKView(in: subview) { return found }
        }
        return nil
    }
    #endif

    func saveScreenshot() {
        #if os(macOS)
        guard let cgImage = currentStageImage() else {
            errorMessage = LocalizationManager.shared.localized("error.screenshotFailed")
            return
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = screenshotFileName()
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

    func copyScreenshot() {
        #if os(macOS)
        guard let cgImage = currentStageImage() else {
            errorMessage = LocalizationManager.shared.localized("error.screenshotFailed")
            return
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        #else
        errorMessage = LocalizationManager.shared.localized("error.screenshotFailed")
        #endif
    }

    #if os(macOS)
    private func screenshotFileName() -> String {
        let baseName = currentFileURL?.deletingPathExtension().lastPathComponent ?? "ruffnova"
        let safeName = baseName.replacingOccurrences(of: ":", with: "-")
        return "\(safeName)-screenshot.png"
    }
    #endif

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
        bridge?.drainPolicyDiagnostics()
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

    func seekToFrame(_ frame: UInt32) {
        bridge?.seekFrame(frame)
        currentFrame = frame
        persistPlaybackPreferences()
    }
    func seekToEnd() { bridge?.seekFrame(totalFrames) }
    func stepBackward() { bridge?.stepBack(1) }
    func rewind() { bridge?.rewind() }
    func toggleLoop() {
        isLooping.toggle()
        bridge?.setLooping(isLooping)
        persistPlaybackPreferences()
    }
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        bridge?.setSpeed(speed)
        persistPlaybackPreferences()
    }

    func setLetterbox(_ value: String) {
        SettingsPersistence.shared.letterbox = value
        applyLetterbox(value)
        persistPlaybackPreferences()
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

        _ = LibraryService.shared.importFiles(swfFiles)
        updateLibraryStats()
    }

    func openImportedContent(_ content: ImportedContent) {
        switch content {
        case .swf(let url):
            openFile(url)
        case .directory(let url):
            browseDirectory(url)
        case .zip(let url):
            do {
                let resolved = try ImportService.shared.resolveImport(for: url)
                openImportedContent(resolved)
            } catch {
                presentImportError(error)
            }
        }
    }

    func presentImportError(_ error: Error) {
        if let importError = error as? ImportError {
            errorMessage = LocalizationManager.shared.localized(importError.messageKey)
        } else {
            errorMessage = error.localizedDescription
        }
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
        let shouldFavorite = !bookmarkManager.contains(url)
        if shouldFavorite {
            bookmarkManager.add(url: url, frame: currentFrame)
        } else {
            bookmarkManager.remove(url: url)
        }
        bookmarks = bookmarkManager.bookmarks.map { $0.url }
        if let item = LibraryService.shared.item(for: url) {
            LibraryService.shared.update(item.id) { $0.isFavorite = shouldFavorite }
        }
    }

    var isFavorite: Bool {
        guard let url = currentFileURL else { return false }
        return bookmarkManager.contains(url)
    }

}
