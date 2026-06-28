// RuffleBridge — Swift wrapper for the Ruffle C FFI layer.
// Falls back to a mock renderer when the Rust FFI library is not available.

import Foundation
import Metal
import QuartzCore
import OSLog
#if RUST_FFI_AVAILABLE
import CRuffleFFI
#endif

extension Logger {
    static let ruffle = Logger(subsystem: "app.ruffnova.native", category: "bridge")
    static let appState = Logger(subsystem: "app.ruffnova.native", category: "appstate")
    static let player = Logger(subsystem: "app.ruffnova.native", category: "player")
}

/// Quality levels matching the C enum.
enum RuffleQuality: Int32 {
    case low = 0
    case medium = 1
    case high = 2
    case best = 3
    case high8x8 = 4
    case high8x8Linear = 5
    case high16x16 = 6
    case high16x16Linear = 7
}

/// Bridge between Swift and the Ruffle Rust core.
/// When RUST_FFI_AVAILABLE is not defined, uses a mock backend
/// so the entire SwiftUI UI can be tested independently.
@MainActor
final class RuffleBridge {
    private var playerPointer: OpaquePointer?
    private var rendererPointer: OpaquePointer?
    private let metalLayer: CAMetalLayer
    private var displayTimer: Timer?
    private var lastFrameTime: UInt64 = 0
    private var renderedFrames: UInt64 = 0
    private var fpsFrames: UInt64 = 0
    private var fpsLastTime: UInt64 = 0
    private var currentFPS: Double = 0
    private let timeBase: mach_timebase_info_data_t

    /// Called on each rendered frame with (fps, frameCount).
    var onFrameUpdate: ((Double, UInt64) -> Void)?

    // MARK: - Speed state (applied to dt in renderFrame)
    private var playbackSpeed: Float = 1.0

    // Mock state
    private var mockIsPlaying: Bool = false
    private var mockVolume: Float = 1.0

    init?(metalLayer: CAMetalLayer, width: UInt32, height: UInt32, scaleFactor: Float,
          quality: Int32 = RuffleQuality.high.rawValue,
          autoplay: Bool = true,
          maxExecutionSecs: Float = 15.0) {
        self.metalLayer = metalLayer
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        self.timeBase = info

        #if RUST_FFI_AVAILABLE
        rendererPointer = ruffle_renderer_create(
            Unmanaged.passUnretained(metalLayer).toOpaque(),
            width, height, scaleFactor
        )
        guard rendererPointer != nil else {
            Logger.ruffle.error("Failed to create renderer")
            return nil
        }
        let config = RuffleConfig(
            width: width, height: height, scale_factor: scaleFactor,
            quality: quality, autoplay: autoplay, max_execution_secs: maxExecutionSecs
        )
        playerPointer = ruffle_player_create_with_renderer(config, rendererPointer)
        guard playerPointer != nil else {
            Logger.ruffle.error("Failed to create player")
            ruffle_renderer_free(rendererPointer)
            rendererPointer = nil
            return nil
        }
        #else
        Logger.ruffle.info("Running in mock mode — Rust FFI not linked")
        #endif

        setupDisplayTimer()
    }

    deinit {
        displayTimer?.invalidate()
        #if RUST_FFI_AVAILABLE
        if let p = playerPointer { ruffle_player_free(p) }
        if let r = rendererPointer { ruffle_renderer_free(r) }
        #endif
    }

    // MARK: - Display Link

    private func setupDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.renderFrame()
            }
        }
        if let timer = displayTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func renderFrame() {
        #if RUST_FFI_AVAILABLE
        guard let player = playerPointer else { return }
        let now = mach_absolute_time()
        if lastFrameTime == 0 { lastFrameTime = now }
        let elapsed = now - lastFrameTime
        let nanos = elapsed * UInt64(timeBase.numer) / UInt64(timeBase.denom)
        let dt = Float(nanos) / 1_000_000_000.0 * playbackSpeed
        lastFrameTime = now
        let tickResult = ruffle_player_tick(player, dt)
        let renderResult = ruffle_player_render(player)
        renderedFrames += 1
        fpsFrames += 1
        if fpsLastTime == 0 { fpsLastTime = now }
        let fpsElapsed = now - fpsLastTime
        let fpsNanos = fpsElapsed * UInt64(timeBase.numer) / UInt64(timeBase.denom)
        if Double(fpsNanos) >= 1_000_000_000.0 {
            currentFPS = Double(fpsFrames) / (Double(fpsNanos) / 1_000_000_000.0)
            fpsFrames = 0
            fpsLastTime = now
        }
        if renderedFrames == 1 || renderedFrames % 120 == 0 {
            Logger.ruffle.debug("frame=\(self.renderedFrames) dt=\(String(format: "%.4f", dt)) playing=\(ruffle_player_is_playing(player)) tick=\(tickResult) render=\(renderResult)")
        }
        onFrameUpdate?(currentFPS, renderedFrames)
        #endif
    }

    // MARK: - Public API

    func loadURL(_ url: URL) {
        #if RUST_FFI_AVAILABLE
        guard let player = playerPointer else { return }
        let result = url.absoluteString.withCString { ruffle_player_load_url(player, $0) }
        if result != RUFFLE_RESULT_OK {
            Logger.ruffle.error("loadURL failed: \(result) \(url.absoluteString)")
        } else {
            Logger.ruffle.debug("loadURL ok url=\(url.absoluteString)")
        }
        #else
        print("[Mock] Load: \(url.lastPathComponent)")
        #endif
    }

    func loadData(_ data: Data, url: URL? = nil) {
        #if RUST_FFI_AVAILABLE
        guard let player = playerPointer else { return }
        data.withUnsafeBytes { buf in
            guard let ptr = buf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let result: RuffleResult
            if let url {
                result = url.absoluteString.withCString { urlString in
                    ruffle_player_load_data_with_url(player, ptr, UInt32(buf.count), urlString)
                }
            } else {
                result = ruffle_player_load_data(player, ptr, UInt32(buf.count))
            }
            if result != RUFFLE_RESULT_OK {
                Logger.ruffle.error("loadData failed: \(result) bytes=\(buf.count)")
            } else {
                Logger.ruffle.debug("loadData ok bytes=\(buf.count) url=\(url?.absoluteString ?? "<embedded>")")
            }
        }
        #endif
    }

    func setPlaying(_ v: Bool) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        ruffle_player_set_playing(p, v)
        #else
        mockIsPlaying = v
        #endif
    }

    func isPlaying() -> Bool {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return false }
        return ruffle_player_is_playing(p)
        #else
        return mockIsPlaying
        #endif
    }

    func setVolume(_ v: Float) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        ruffle_player_set_volume(p, v)
        #else
        mockVolume = v
        #endif
    }

    func getVolume() -> Float {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return 0 }
        return ruffle_player_get_volume(p)
        #else
        return mockVolume
        #endif
    }

    // MARK: - Playback Info (Phase 1)

    func getPlaybackInfo() -> (currentFrame: UInt32, totalFrames: UInt32, frameRate: Float, isPlaying: Bool)? {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return nil }
        var info = RufflePlaybackInfo()
        let result = ruffle_player_get_playback_info(p, &info)
        guard result == RUFFLE_RESULT_OK else { return nil }
        return (info.current_frame, info.total_frames, info.frame_rate, info.is_playing)
        #else
        return (1, 100, 30.0, mockIsPlaying)
        #endif
    }

    // MARK: - Seek (Phase 1)

    func seekFrame(_ frame: UInt32) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        _ = ruffle_player_seek_frame(p, frame)
        #endif
    }

    func seekTime(_ seconds: Float) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        _ = ruffle_player_seek_time(p, seconds)
        #endif
    }

    func stepBack(_ frames: UInt32 = 1) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        _ = ruffle_player_step_back(p, frames)
        #endif
    }

    func rewind() {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        _ = ruffle_player_rewind(p)
        #endif
    }

    // MARK: - Scale & Letterbox (Phase 1)

    func setScaleMode(_ mode: RuffleScaleMode) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        _ = ruffle_player_set_scale_mode(p, mode)
        #endif
    }

    func setLetterboxMode(_ mode: RuffleLetterbox) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        _ = ruffle_player_set_letterbox_mode(p, mode)
        #endif
    }

    // MARK: - Speed (Phase 1)

    func setSpeed(_ speed: Float) {
        playbackSpeed = max(0.1, min(speed, 10.0))
        #if RUST_FFI_AVAILABLE
        _ = ruffle_player_set_speed(playerPointer, speed)
        #endif
    }

    func getSpeed() -> Float { playbackSpeed }

    // MARK: - Looping (Phase 1)

    private var loopFlag: Bool = false

    func setLooping(_ looping: Bool) {
        loopFlag = looping
        #if RUST_FFI_AVAILABLE
        if let p = playerPointer { _ = ruffle_player_set_looping(p, looping) }
        #endif
    }

    func isLooping() -> Bool { loopFlag }

    func setFullscreen(_ v: Bool) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        ruffle_player_set_fullscreen(p, v)
        #endif
    }

    func setViewport(width: UInt32, height: UInt32, scaleFactor: Float) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer, let r = rendererPointer else { return }
        ruffle_player_set_viewport(p, width, height, scaleFactor)
        ruffle_renderer_resize(r, width, height, scaleFactor)
        #endif
    }

    /// Update the Metal layer used for rendering, keeping the player and its state intact.
    /// Called when the NSView/MTKView is recreated (e.g. after navigating away and back).
    /// Uses `ruffle_player_recreate_surface` which accesses the render backend through the
    /// Player (the RuffleRenderer wrapper is empty after player creation).
    func updateSurface(metalLayer: CAMetalLayer, width: UInt32, height: UInt32) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        let result = ruffle_player_recreate_surface(
            p,
            Unmanaged.passUnretained(metalLayer).toOpaque(),
            width, height
        )
        if result != RUFFLE_RESULT_OK {
            Logger.ruffle.error("updateSurface failed: \(result)")
        }
        #endif
    }

    func tick(_ dt: Float) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        ruffle_player_tick(p, dt)
        #endif
    }

    func stageSize() -> (UInt32, UInt32) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return (0,0) }
        return (ruffle_player_stage_width(p), ruffle_player_stage_height(p))
        #else
        return (550, 400)
        #endif
    }

    func sendKeyEvent(keyCode: UInt32, charCode: UInt32, isDown: Bool, modifiers: UInt32) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        let ev = RuffleKeyEvent(key_code: keyCode, char_code: charCode, is_down: isDown, modifiers: modifiers)
        ruffle_player_key_event(p, ev)
        #endif
    }

    func getMetadata() -> (swfVersion: UInt8, playerVersion: UInt8, isAS3: Bool, frameRate: Float, movieWidth: UInt32, movieHeight: UInt32, totalFrames: UInt32)? {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return nil }
        let w = ruffle_player_stage_width(p)
        let h = ruffle_player_stage_height(p)
        // Use available playback info for dynamic fields
        var info = RufflePlaybackInfo()
        let result = ruffle_player_get_playback_info(p, &info)
        let fps = result == RUFFLE_RESULT_OK ? info.frame_rate : 0
        let total = result == RUFFLE_RESULT_OK ? info.total_frames : 0
        // SWF version, player version, and AS version are not yet exposed via FFI
        return (
            swfVersion: 0,
            playerVersion: 0,
            isAS3: false,
            frameRate: fps,
            movieWidth: w,
            movieHeight: h,
            totalFrames: total
        )
        #else
        return nil
        #endif
    }

    func sendMouseEvent(x: Float, y: Float, eventType: Int32, scrollDelta: Float = 0) {
        #if RUST_FFI_AVAILABLE
        guard let p = playerPointer else { return }
        let ev = RuffleMouseEvent(x: x, y: y, event_type: eventType, scroll_delta: scrollDelta)
        let result = ruffle_player_mouse_event(p, ev)
        #if DEBUG
        if eventType == 1 || eventType == 2 {
            Logger.ruffle.debug("mouse type=\(eventType) x=\(Int(x)) y=\(Int(y)) result=\(result)")
        }
        #endif
        #endif
    }

    func getMetalLayer() -> CAMetalLayer { metalLayer }
}
