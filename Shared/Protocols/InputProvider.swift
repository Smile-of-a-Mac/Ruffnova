// InputProvider — Platform-independent input abstraction.
// macOS uses mouse/keyboard events, iOS uses touch/gesture recognizers.

import Foundation

enum MouseButton {
    case left
    case right
    case middle
}

@MainActor
protocol InputProvider {
    func sendMouseMove(x: Float, y: Float)
    func sendMouseDown(x: Float, y: Float, button: MouseButton)
    func sendMouseUp(x: Float, y: Float, button: MouseButton)
    func sendScroll(x: Float, y: Float, deltaX: Float, deltaY: Float)
    func sendKeyDown(keyCode: UInt32, charCode: UInt32, modifiers: UInt32)
    func sendKeyUp(keyCode: UInt32, charCode: UInt32, modifiers: UInt32)
    func sendTap(x: Float, y: Float)
    func sendDoubleTap(x: Float, y: Float)
    func sendLongPress(x: Float, y: Float)
}
