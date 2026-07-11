// RufflePlayerView — Multi-platform Metal view for SWF rendering.
// Contains platform-specific implementations for macOS and iOS.

import SwiftUI
import MetalKit
import OSLog

fileprivate extension Logger {
    static let playerView = Logger(subsystem: "app.ruffnova.native", category: "playerView")
}

// MARK: - Shared Definitions

struct RuffleMetalMouseEvent {
    let x: Float
    let y: Float
    let type: Int32
    let scrollDelta: Float
}

enum RuffleMetalConfig {
    static func configure(_ view: MTKView) {
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.framebufferOnly = false
        view.isPaused = true
        view.enableSetNeedsDisplay = true
    }
}

enum RuffleSurfaceInitialization {
    static func isReady(
        hasWindow: Bool,
        width: CGFloat,
        height: CGFloat,
        drawableWidth: CGFloat,
        drawableHeight: CGFloat
    ) -> Bool {
        hasWindow && width > 0 && height > 0 && drawableWidth > 0 && drawableHeight > 0
    }
}

// MARK: - Platform-adaptive SwiftUI wrapper

struct RufflePlayerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        #if os(macOS)
        RufflePlayerViewMacOS()
            .environmentObject(appState)
        #elseif os(iOS)
        RufflePlayerViewIOS()
            .environmentObject(appState)
        #endif
    }
}

// MARK: - macOS Implementation

#if os(macOS)
import AppKit

struct RufflePlayerViewMacOS: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeNSView(context: Context) -> RuffleMetalViewMacOS {
        let view = RuffleMetalViewMacOS()
        view.appState = appState
        view.onMouseEvent = { [weak appState] event in
            appState?.bridge?.sendMouseEvent(
                x: event.x, y: event.y,
                eventType: event.type, scrollDelta: event.scrollDelta
            )
        }
        view.onReady = { [weak appState] metalLayer, width, height, scaleFactor in
            appState?.initializeBridge(
                metalLayer: metalLayer, width: width,
                height: height, scaleFactor: scaleFactor
            ) ?? false
        }
        return view
    }

    func updateNSView(_ nsView: RuffleMetalViewMacOS, context: Context) {
        nsView.tryInitializeBridge()
        nsView.updateViewport()
    }
}

final class RuffleMetalViewMacOS: MTKView {
    var onMouseEvent: ((RuffleMetalMouseEvent) -> Void)?
    var onReady: ((CAMetalLayer, UInt32, UInt32, Float) -> Bool)?
    var appState: AppState?
    private var bridgeInitialized = false
    private var initializationRetryScheduled = false
    private var trackingArea: NSTrackingArea?
    private var focusObserver: NSObjectProtocol?

    var metalLayer: CAMetalLayer? { layer as? CAMetalLayer }

    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        configure()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        RuffleMetalConfig.configure(self)
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        wantsLayer = true
        focusObserver = NotificationCenter.default.addObserver(
            forName: .focusPlayerStage,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    deinit {
        if let focusObserver {
            NotificationCenter.default.removeObserver(focusObserver)
        }
    }

    func tryInitializeBridge() {
        guard !bridgeInitialized,
              let window = self.window,
              bounds.width > 0,
              bounds.height > 0
        else { return }
        let scaleFactor = CGFloat(window.backingScaleFactor)
        layer?.contentsScale = scaleFactor
        drawableSize = CGSize(width: bounds.width * scaleFactor, height: bounds.height * scaleFactor)
        guard let metalLayer = self.metalLayer,
              RuffleSurfaceInitialization.isReady(
                hasWindow: true,
                width: bounds.width,
                height: bounds.height,
                drawableWidth: drawableSize.width,
                drawableHeight: drawableSize.height
              )
        else { return }
        metalLayer.device = device
        metalLayer.pixelFormat = colorPixelFormat
        metalLayer.framebufferOnly = framebufferOnly
        let scale = Float(scaleFactor)
        let w = UInt32(bounds.width * scaleFactor)
        let h = UInt32(bounds.height * scaleFactor)
        let created = onReady?(metalLayer, max(w, 1), max(h, 1), scale) ?? false
        if RufflePlayerLifecycle.shouldCommitSurfaceInitialization(rendererCreated: created) {
            bridgeInitialized = true
            initializationRetryScheduled = false
        } else {
            scheduleInitializationRetry()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self, userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            bridgeInitialized = false
            initializationRetryScheduled = false
            appState?.setStageInputFocused(false)
        } else {
            layer?.contentsScale = window?.backingScaleFactor ?? 1.0
            tryInitializeBridge()
            updateViewport()
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        tryInitializeBridge()
        updateViewport()
    }

    func updateViewport() {
        guard let window = window else { return }
        guard !window.isMiniaturized, bounds.width >= 16, bounds.height >= 16 else { return }
        let scaleFactor = Float(window.backingScaleFactor)
        let width = UInt32(bounds.width * CGFloat(scaleFactor))
        let height = UInt32(bounds.height * CGFloat(scaleFactor))
        guard width >= 16, height >= 16 else { return }
        NotificationCenter.default.post(
            name: .viewportChanged, object: nil,
            userInfo: ["width": width, "height": height, "scaleFactor": scaleFactor]
        )
    }

    private func scheduleInitializationRetry() {
        guard !initializationRetryScheduled else { return }
        initializationRetryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.initializationRetryScheduled = false
            self.tryInitializeBridge()
        }
    }

    // MARK: Mouse Events

    override func mouseMoved(with event: NSEvent) {
        appState?.handlePlayerPointerActivity()
        let (x, y) = mouseCoords(event)
        onMouseEvent?(RuffleMetalMouseEvent(x: x, y: y, type: 0, scrollDelta: 0))
    }

    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount >= 2 {
            appState?.handleStageDoubleClick()
        }
        let (x, y) = mouseCoords(event)
        onMouseEvent?(RuffleMetalMouseEvent(x: x, y: y, type: 1, scrollDelta: 0))
    }

    override func mouseUp(with event: NSEvent) {
        let (x, y) = mouseCoords(event)
        onMouseEvent?(RuffleMetalMouseEvent(x: x, y: y, type: 2, scrollDelta: 0))
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let (x, y) = mouseCoords(event)
        onMouseEvent?(RuffleMetalMouseEvent(x: x, y: y, type: 3, scrollDelta: 0))
    }

    override func rightMouseDragged(with event: NSEvent) { mouseMoved(with: event) }

    override func rightMouseUp(with event: NSEvent) {
        let (x, y) = mouseCoords(event)
        onMouseEvent?(RuffleMetalMouseEvent(x: x, y: y, type: 4, scrollDelta: 0))
    }

    override func scrollWheel(with event: NSEvent) {
        let (x, y) = mouseCoords(event)
        onMouseEvent?(RuffleMetalMouseEvent(x: x, y: y, type: 5, scrollDelta: Float(event.scrollingDeltaY)))
    }

    private func mouseCoords(_ event: NSEvent) -> (Float, Float) {
        let scale = Float(window?.backingScaleFactor ?? 1.0)
        let loc = convert(event.locationInWindow, from: nil)
        let y = isFlipped ? loc.y : bounds.height - loc.y
        return (Float(loc.x * CGFloat(scale)), Float(y * CGFloat(scale)))
    }

    // MARK: Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let loc = LocalizationManager.shared
        let menu = NSMenu()
        let playItem = NSMenuItem(
            title: appState?.isPlaying == true ? loc.localized("menu.pause") : loc.localized("menu.play"),
            action: #selector(contextMenuPlayPause), keyEquivalent: ""
        )
        playItem.target = self
        menu.addItem(playItem)
        menu.addItem(.separator())
        let rewindItem = NSMenuItem(title: loc.localized("menu.rewind"), action: #selector(contextMenuRewind), keyEquivalent: "")
        rewindItem.target = self
        menu.addItem(rewindItem)
        let stepItem = NSMenuItem(title: loc.localized("menu.stepForward"), action: #selector(contextMenuStepForward), keyEquivalent: "")
        stepItem.target = self
        menu.addItem(stepItem)
        menu.addItem(.separator())
        let qualityMenu = NSMenu()
        let qualityItems = [
            (loc.localized("menu.quality.low"), 0),
            (loc.localized("menu.quality.medium"), 1),
            (loc.localized("menu.quality.high"), 2),
            (loc.localized("menu.quality.best"), 3),
        ]
        for q in qualityItems {
            let item = NSMenuItem(title: q.0, action: #selector(contextMenuSetQuality(_:)), keyEquivalent: "")
            item.tag = q.1; item.target = self
            qualityMenu.addItem(item)
        }
        let qualityItem = NSMenuItem(title: loc.localized("menu.quality"), action: nil, keyEquivalent: "")
        qualityItem.submenu = qualityMenu
        menu.addItem(qualityItem)
        menu.addItem(.separator())
        let ssItem = NSMenuItem(title: loc.localized("menu.saveScreenshot"), action: #selector(contextMenuScreenshot), keyEquivalent: "")
        ssItem.keyEquivalentModifierMask = [.command, .shift]
        ssItem.keyEquivalent = "s"; ssItem.target = self
        menu.addItem(ssItem)
        return menu
    }

    @objc private func contextMenuPlayPause() { appState?.togglePlayPause() }
    @objc private func contextMenuRewind() { appState?.rewind() }
    @objc private func contextMenuStepForward() { appState?.stepForward() }
    @objc private func contextMenuSetQuality(_ sender: NSMenuItem) {
        appState?.quality = RuffleQuality(rawValue: Int32(sender.tag)) ?? .high
    }
    @objc private func contextMenuScreenshot() { appState?.saveScreenshot() }

    // MARK: Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { appState?.setStageInputFocused(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { appState?.setStageInputFocused(false) }
        return accepted
    }

    override func keyDown(with event: NSEvent) {
        guard shouldForwardToPlayer(event) else {
            super.keyDown(with: event)
            return
        }
        let (kc, cc) = keyMap(event)
        NotificationCenter.default.post(
            name: .keyEvent, object: nil,
            userInfo: ["keyCode": kc, "charCode": cc, "isDown": true,
                       "modifiers": event.modifierFlags.deviceIndependentModifierFlagsMask.rawValue]
        )
    }

    override func keyUp(with event: NSEvent) {
        guard shouldForwardToPlayer(event) else { return }
        let (kc, cc) = keyMap(event)
        NotificationCenter.default.post(
            name: .keyEvent, object: nil,
            userInfo: ["keyCode": kc, "charCode": cc, "isDown": false,
                       "modifiers": event.modifierFlags.deviceIndependentModifierFlagsMask.rawValue]
        )
    }

    override func cancelOperation(_ sender: Any?) {
        appState?.handlePlayerEscape()
    }

    private func shouldForwardToPlayer(_ event: NSEvent) -> Bool {
        !event.modifierFlags.deviceIndependentModifierFlagsMask.contains(.command)
    }

    private func keyMap(_ event: NSEvent) -> (UInt32, UInt32) {
        let kc = HIDKeyMapper.macVirtualKeyToHID(event.keyCode) ?? 0
        let cc = event.characters?.first.map { UInt32($0.asciiValue ?? 0) } ?? 0
        return (kc, cc)
    }

    // MARK: Drag and Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.types?.contains(.fileURL) == true ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
              let url = urls.first, url.pathExtension.lowercased() == "swf" else { return false }
        NotificationCenter.default.post(name: .openSWFFile, object: nil, userInfo: ["url": url])
        return true
    }
}

private extension NSEvent.ModifierFlags {
    var deviceIndependentModifierFlagsMask: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: rawValue & 0xFFFF0000)
    }
}
#endif

// MARK: - iOS Implementation

#if os(iOS)
import UIKit

struct RufflePlayerViewIOS: UIViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeUIView(context: Context) -> RuffleMetalViewIOS {
        let view = RuffleMetalViewIOS()
        view.appState = appState
        view.onMouseEvent = { [weak appState] event in
            appState?.bridge?.sendMouseEvent(x: event.x, y: event.y, eventType: event.type, scrollDelta: event.scrollDelta)
        }
        view.onReady = { [weak appState] metalLayer, width, height, scaleFactor in
            appState?.initializeBridge(
                metalLayer: metalLayer,
                width: width,
                height: height,
                scaleFactor: scaleFactor
            ) ?? false
        }
        return view
    }

    func updateUIView(_ uiView: RuffleMetalViewIOS, context: Context) {
        uiView.tryInitializeBridge()
        uiView.updateViewport()
    }
}

final class RuffleMetalViewIOS: MTKView {
    var onMouseEvent: ((RuffleMetalMouseEvent) -> Void)?
    var onReady: ((CAMetalLayer, UInt32, UInt32, Float) -> Bool)?
    var appState: AppState?
    private var bridgeInitialized = false
    private var initializationRetryScheduled = false
    private var focusObserver: NSObjectProtocol?

    var metalLayer: CAMetalLayer? { layer as? CAMetalLayer }

    private var displayScale: CGFloat {
        window?.windowScene?.screen.scale ?? traitCollection.displayScale
    }

    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        configure()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        RuffleMetalConfig.configure(self)
        layer.contentsScale = displayScale
        isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        addGestureRecognizer(longPress)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
        focusObserver = NotificationCenter.default.addObserver(
            forName: .focusPlayerStage,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            _ = self?.becomeFirstResponder()
        }
    }

    deinit {
        if let focusObserver {
            NotificationCenter.default.removeObserver(focusObserver)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            bridgeInitialized = false
            initializationRetryScheduled = false
            appState?.setStageInputFocused(false)
            return
        }
        layer.contentsScale = displayScale
        tryInitializeBridge()
        updateViewport()
    }

    func tryInitializeBridge() {
        guard !bridgeInitialized,
              window != nil,
              bounds.width > 0,
              bounds.height > 0
        else { return }
        let scaleFactor = displayScale
        layer.contentsScale = scaleFactor
        drawableSize = CGSize(width: bounds.width * scaleFactor, height: bounds.height * scaleFactor)
        guard let metalLayer = self.metalLayer,
              RuffleSurfaceInitialization.isReady(
                hasWindow: true,
                width: bounds.width,
                height: bounds.height,
                drawableWidth: drawableSize.width,
                drawableHeight: drawableSize.height
              )
        else { return }
        metalLayer.device = device
        metalLayer.pixelFormat = colorPixelFormat
        metalLayer.framebufferOnly = framebufferOnly
        let scale = Float(scaleFactor)
        let w = UInt32(bounds.width * scaleFactor)
        let h = UInt32(bounds.height * scaleFactor)
        let created = onReady?(metalLayer, max(w, 1), max(h, 1), scale) ?? false
        if RufflePlayerLifecycle.shouldCommitSurfaceInitialization(rendererCreated: created) {
            bridgeInitialized = true
            initializationRetryScheduled = false
        } else {
            scheduleInitializationRetry()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        tryInitializeBridge()
        updateViewport()
    }

    private func scheduleInitializationRetry() {
        guard !initializationRetryScheduled else { return }
        initializationRetryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.initializationRetryScheduled = false
            self.tryInitializeBridge()
        }
    }

    func updateViewport() {
        let scaleFactor = Float(displayScale)
        let width = UInt32(bounds.width * CGFloat(scaleFactor))
        let height = UInt32(bounds.height * CGFloat(scaleFactor))
        NotificationCenter.default.post(
            name: .viewportChanged, object: nil,
            userInfo: ["width": width, "height": height, "scaleFactor": scaleFactor]
        )
    }

    private func scaledLocation(from gesture: UIGestureRecognizer) -> CGPoint {
        let loc = gesture.location(in: self)
        let scale = displayScale
        return CGPoint(x: loc.x * scale, y: loc.y * scale)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        _ = becomeFirstResponder()
        appState?.handlePlayerPointerActivity()
        let p = scaledLocation(from: gesture)
        onMouseEvent?(RuffleMetalMouseEvent(x: Float(p.x), y: Float(p.y), type: 1, scrollDelta: 0))
        onMouseEvent?(RuffleMetalMouseEvent(x: Float(p.x), y: Float(p.y), type: 2, scrollDelta: 0))
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        appState?.handleStageDoubleClick()
        handleTap(gesture)
        let p = scaledLocation(from: gesture)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.onMouseEvent?(RuffleMetalMouseEvent(x: Float(p.x), y: Float(p.y), type: 1, scrollDelta: 0))
            self?.onMouseEvent?(RuffleMetalMouseEvent(x: Float(p.x), y: Float(p.y), type: 2, scrollDelta: 0))
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let p = scaledLocation(from: gesture)
        onMouseEvent?(RuffleMetalMouseEvent(x: Float(p.x), y: Float(p.y), type: 3, scrollDelta: 0))
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        appState?.handlePlayerPointerActivity()
        let p = scaledLocation(from: gesture)
        switch gesture.state {
        case .began, .changed:
            onMouseEvent?(RuffleMetalMouseEvent(x: Float(p.x), y: Float(p.y), type: 0, scrollDelta: 0))
        default: break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed else { return }
        let p = scaledLocation(from: gesture)
        let scrollDelta = Float((gesture.scale - 1.0) * 100)
        onMouseEvent?(RuffleMetalMouseEvent(x: Float(p.x), y: Float(p.y), type: 5, scrollDelta: scrollDelta))
        gesture.scale = 1.0
    }

    override var canBecomeFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { appState?.setStageInputFocused(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { appState?.setStageInputFocused(false) }
        return accepted
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }
            let (kc, cc) = keyMap(key)
            NotificationCenter.default.post(
                name: .keyEvent, object: nil,
                userInfo: ["keyCode": kc, "charCode": cc, "isDown": true,
                           "modifiers": modifierFlags(from: key)]
            )
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }
            let (kc, cc) = keyMap(key)
            NotificationCenter.default.post(
                name: .keyEvent, object: nil,
                userInfo: ["keyCode": kc, "charCode": cc, "isDown": false,
                           "modifiers": modifierFlags(from: key)]
            )
        }
    }

    private func keyMap(_ key: UIKey) -> (UInt32, UInt32) {
        let kc = HIDKeyMapper.hidUsage(UInt16(key.keyCode.rawValue)) ?? 0
        let cc = key.characters.first.map { UInt32($0.asciiValue ?? 0) } ?? 0
        return (kc, cc)
    }

    private func modifierFlags(from key: UIKey) -> UInt {
        UInt(key.modifierFlags.rawValue)
    }
}
#endif
