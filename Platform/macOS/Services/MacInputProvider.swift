// MacInputProvider — macOS input using NSEvent bridge calls.

#if os(macOS)
import Foundation

@MainActor
final class MacInputProvider: InputProvider {
    private let bridge: RuffleBridge

    init(bridge: RuffleBridge) {
        self.bridge = bridge
    }

    func sendMouseMove(x: Float, y: Float) {
        bridge.sendMouseEvent(x: x, y: y, eventType: 0, scrollDelta: 0)
    }

    func sendMouseDown(x: Float, y: Float, button: MouseButton) {
        let eventType: Int32
        switch button {
        case .left: eventType = 1
        case .right: eventType = 3
        case .middle: eventType = 1
        }
        bridge.sendMouseEvent(x: x, y: y, eventType: eventType, scrollDelta: 0)
    }

    func sendMouseUp(x: Float, y: Float, button: MouseButton) {
        let eventType: Int32
        switch button {
        case .left: eventType = 2
        case .right: eventType = 4
        case .middle: eventType = 2
        }
        bridge.sendMouseEvent(x: x, y: y, eventType: eventType, scrollDelta: 0)
    }

    func sendScroll(x: Float, y: Float, deltaX: Float, deltaY: Float) {
        bridge.sendMouseEvent(x: x, y: y, eventType: 5, scrollDelta: deltaY)
    }

    func sendKeyDown(keyCode: UInt32, charCode: UInt32, modifiers: UInt32) {
        bridge.sendKeyEvent(keyCode: keyCode, charCode: charCode, isDown: true, modifiers: modifiers)
    }

    func sendKeyUp(keyCode: UInt32, charCode: UInt32, modifiers: UInt32) {
        bridge.sendKeyEvent(keyCode: keyCode, charCode: charCode, isDown: false, modifiers: modifiers)
    }

    func sendTap(x: Float, y: Float) {
        bridge.sendMouseEvent(x: x, y: y, eventType: 1, scrollDelta: 0)
        bridge.sendMouseEvent(x: x, y: y, eventType: 2, scrollDelta: 0)
    }

    func sendDoubleTap(x: Float, y: Float) {
        sendTap(x: x, y: y)
        sendTap(x: x, y: y)
    }

    func sendLongPress(x: Float, y: Float) {
        bridge.sendMouseEvent(x: x, y: y, eventType: 3, scrollDelta: 0)
    }
}
#endif
