import Foundation

/// Identifies which physical or virtual input produced a key event.
/// Fine-grained identity ensures that two different sources pressing the same
/// output key are tracked independently — the router only releases the key when
/// the last source lets go.
enum InputSource: Hashable {
    /// A physical keyboard key, identified by its USB HID usage code and active modifiers.
    case keyboard(physicalHID: UInt32, modifiers: UInt32)
    /// A touch control instance on screen, identified by its stable UUID and the action it represents.
    case virtual(controlInstanceID: UUID, action: GameAction)
    /// A specific element on a connected game controller.
    case controller(controllerID: UUID, element: ControllerElement)
    var isKeyboard: Bool {
        if case .keyboard = self { return true }
        return false
    }
}

@MainActor
final class InputRouter {
    private var activeSources = [UInt32: Set<InputSource>]()

    func route(
        keyCode: UInt32,
        charCode: UInt32,
        isDown: Bool,
        modifiers: UInt32,
        source: InputSource,
        isInteractive: Bool,
        isStageFocused: Bool,
        send: (UInt32, UInt32, Bool, UInt32) -> Void
    ) {
        guard isInteractive, isStageFocused else { return }

        guard keyCode != 0 else { return }

        if isDown {
            var sources = activeSources[keyCode, default: []]
            guard sources.insert(source).inserted else { return }
            activeSources[keyCode] = sources
            guard sources.count == 1 else { return }
        } else {
            guard var sources = activeSources[keyCode], sources.remove(source) != nil else { return }
            if sources.isEmpty {
                activeSources.removeValue(forKey: keyCode)
            } else {
                activeSources[keyCode] = sources
                return
            }
        }
        send(keyCode, charCode, isDown, modifiers)
    }

    func releaseAll(send: (UInt32, UInt32, Bool, UInt32) -> Void) {
        for keyCode in activeSources.keys {
            send(keyCode, 0, false, 0)
        }
        activeSources.removeAll()
    }
}
