// RufflePlayerView — Metal-backed view that renders SWF content.

import SwiftUI
import AppKit
import MetalKit
import OSLog

fileprivate extension Logger {
    static let playerView = Logger(subsystem: "app.ruffnova.native", category: "playerView")
}

/// SwiftUI wrapper for the Metal player view.
struct RufflePlayerView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeNSView(context: Context) -> RuffleMetalView {
        let view = RuffleMetalView()
        view.appState = appState
        view.onMouseEvent = { [weak appState] event in
            appState?.bridge?.sendMouseEvent(
                x: event.x,
                y: event.y,
                eventType: event.type,
                scrollDelta: event.scrollDelta
            )
        }
        view.onReady = { [weak appState] metalLayer, width, height, scaleFactor in
            DispatchQueue.main.async {
                appState?.initializeBridge(
                    metalLayer: metalLayer,
                    width: width,
                    height: height,
                    scaleFactor: scaleFactor
                )
            }
        }
        return view
    }

    func updateNSView(_ nsView: RuffleMetalView, context: Context) {
        nsView.tryInitializeBridge()
        nsView.updateViewport()
    }
}

/// The actual Metal view that displays SWF content.
final class RuffleMetalView: MTKView {
    struct MouseEvent {
        let x: Float
        let y: Float
        let type: Int32
        let scrollDelta: Float
    }

    var onMouseEvent: ((MouseEvent) -> Void)?
    var onReady: ((CAMetalLayer, UInt32, UInt32, Float) -> Void)?
    var appState: AppState?
    private var bridgeInitialized = false
    private var trackingArea: NSTrackingArea?

    var metalLayer: CAMetalLayer? {
        layer as? CAMetalLayer
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
        // Metal configuration
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        framebufferOnly = false
        isPaused = true
        enableSetNeedsDisplay = true

        // Enable Retina support
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        wantsLayer = true
    }

    /// Attempt to initialize the bridge once the view has a window and non-zero bounds.
    /// Called from multiple lifecycle points so it triggers as soon as possible.
    func tryInitializeBridge() {
        guard !bridgeInitialized,
              let metalLayer = self.metalLayer,
              let window = self.window,
              bounds.width > 0,
              bounds.height > 0
        else { return }
        bridgeInitialized = true
        let scaleFactor = Float(window.backingScaleFactor)
        let w = UInt32(bounds.width * CGFloat(scaleFactor))
        let h = UInt32(bounds.height * CGFloat(scaleFactor))
        onReady?(metalLayer, max(w, 1), max(h, 1), scaleFactor)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            bridgeInitialized = false
        } else {
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
        let scaleFactor = Float(window.backingScaleFactor)
        let width = UInt32(bounds.width * CGFloat(scaleFactor))
        let height = UInt32(bounds.height * CGFloat(scaleFactor))

        // Notify the app state about the new viewport
        NotificationCenter.default.post(
            name: .viewportChanged,
            object: nil,
            userInfo: [
                "width": width,
                "height": height,
                "scaleFactor": scaleFactor,
            ]
        )
    }

    // MARK: - Mouse Events

    override func mouseMoved(with event: NSEvent) {
        let scale = Float(window?.backingScaleFactor ?? 1.0)
        let location = mouseLocation(from: event, scale: scale)
        onMouseEvent?(MouseEvent(
            x: Float(location.x),
            y: Float(location.y),
            type: 0, // move
            scrollDelta: 0
        ))
    }

    override func mouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let scale = Float(window?.backingScaleFactor ?? 1.0)
        let location = mouseLocation(from: event, scale: scale)
        #if DEBUG
        let selfRef = self
        Logger.playerView.debug("mouseDown x=\(Int(location.x)) y=\(Int(location.y)) flipped=\(selfRef.isFlipped) size=\(Int(selfRef.bounds.width * CGFloat(scale)))x\(Int(selfRef.bounds.height * CGFloat(scale)))")
        #endif
        onMouseEvent?(MouseEvent(
            x: Float(location.x),
            y: Float(location.y),
            type: 1, // left down
            scrollDelta: 0
        ))
    }

    override func mouseUp(with event: NSEvent) {
        let scale = Float(window?.backingScaleFactor ?? 1.0)
        let location = mouseLocation(from: event, scale: scale)
        #if DEBUG
        Logger.playerView.debug("mouseUp x=\(Int(location.x)) y=\(Int(location.y)) flipped=\(self.isFlipped)")
        #endif
        onMouseEvent?(MouseEvent(
            x: Float(location.x),
            y: Float(location.y),
            type: 2, // left up
            scrollDelta: 0
        ))
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let scale = Float(window?.backingScaleFactor ?? 1.0)
        let location = mouseLocation(from: event, scale: scale)
        onMouseEvent?(MouseEvent(
            x: Float(location.x),
            y: Float(location.y),
            type: 3, // right down
            scrollDelta: 0
        ))
    }

    override func rightMouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        let scale = Float(window?.backingScaleFactor ?? 1.0)
        let location = mouseLocation(from: event, scale: scale)
        onMouseEvent?(MouseEvent(
            x: Float(location.x),
            y: Float(location.y),
            type: 4, // right up
            scrollDelta: 0
        ))
    }

    // MARK: - Context Menu (Phase 4)

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        let playItem = NSMenuItem(title: appState?.isPlaying == true ? "Pause" : "Play",
                                  action: #selector(contextMenuPlayPause), keyEquivalent: "")
        playItem.target = self
        menu.addItem(playItem)

        menu.addItem(.separator())

        let rewindItem = NSMenuItem(title: "Rewind", action: #selector(contextMenuRewind), keyEquivalent: "")
        rewindItem.target = self
        menu.addItem(rewindItem)

        let stepItem = NSMenuItem(title: "Step Forward", action: #selector(contextMenuStepForward), keyEquivalent: "")
        stepItem.target = self
        menu.addItem(stepItem)

        menu.addItem(.separator())

        let qualityMenu = NSMenu()
        for q in [("Low", 0), ("Medium", 1), ("High", 2), ("Best", 3)] {
            let item = NSMenuItem(title: q.0, action: #selector(contextMenuSetQuality(_:)), keyEquivalent: "")
            item.tag = q.1
            item.target = self
            qualityMenu.addItem(item)
        }
        let qualityItem = NSMenuItem(title: "Quality", action: nil, keyEquivalent: "")
        qualityItem.submenu = qualityMenu
        menu.addItem(qualityItem)

        menu.addItem(.separator())

        let screenshotItem = NSMenuItem(title: "Save Screenshot", action: #selector(contextMenuScreenshot), keyEquivalent: "")
        screenshotItem.keyEquivalentModifierMask = [.command, .shift]
        screenshotItem.keyEquivalent = "s"
        screenshotItem.target = self
        menu.addItem(screenshotItem)

        return menu
    }

    @objc private func contextMenuPlayPause() { appState?.togglePlayPause() }
    @objc private func contextMenuRewind() { appState?.rewind() }
    @objc private func contextMenuStepForward() { appState?.stepForward() }
    @objc private func contextMenuSetQuality(_ sender: NSMenuItem) {
        let q = RuffleQuality(rawValue: Int32(sender.tag)) ?? .high
        appState?.quality = q
    }
    @objc private func contextMenuScreenshot() {
        appState?.saveScreenshot()
    }

    override func scrollWheel(with event: NSEvent) {
        let scale = Float(window?.backingScaleFactor ?? 1.0)
        let location = mouseLocation(from: event, scale: scale)
        onMouseEvent?(MouseEvent(
            x: Float(location.x),
            y: Float(location.y),
            type: 5, // scroll
            scrollDelta: Float(event.scrollingDeltaY)
        ))
    }

    private func mouseLocation(from event: NSEvent, scale: Float) -> CGPoint {
        let location = convert(event.locationInWindow, from: nil)
        let y = isFlipped ? location.y : bounds.height - location.y
        return CGPoint(
            x: location.x * CGFloat(scale),
            y: y * CGFloat(scale)
        )
    }

    // MARK: - Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Forward to the bridge
        let (keyCode, charCode) = mapKeyCode(event)
        NotificationCenter.default.post(
            name: .keyEvent,
            object: nil,
            userInfo: [
                "keyCode": keyCode,
                "charCode": charCode,
                "isDown": true,
                "modifiers": event.modifierFlags.deviceIndependentModifierFlagsMask.rawValue,
            ]
        )
    }

    override func keyUp(with event: NSEvent) {
        let (keyCode, charCode) = mapKeyCode(event)
        NotificationCenter.default.post(
            name: .keyEvent,
            object: nil,
            userInfo: [
                "keyCode": keyCode,
                "charCode": charCode,
                "isDown": false,
                "modifiers": event.modifierFlags.deviceIndependentModifierFlagsMask.rawValue,
            ]
        )
    }

    private func mapKeyCode(_ event: NSEvent) -> (UInt32, UInt32) {
        // Map macOS key codes to USB HID codes (simplified)
        let keyCode = UInt32(event.keyCode)
        let charCode = event.characters?.first.map { UInt32($0.asciiValue ?? 0) } ?? 0
        return (keyCode, charCode)
    }

    // MARK: - Drag and Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.types?.contains(.fileURL) == true {
            return .copy
        }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
              let url = urls.first,
              url.pathExtension.lowercased() == "swf" else {
            return false
        }
        NotificationCenter.default.post(name: .openSWFFile, object: nil, userInfo: ["url": url])
        return true
    }
}

private extension NSEvent.ModifierFlags {
    var deviceIndependentModifierFlagsMask: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: rawValue & 0xFFFF0000)
    }
}
