import Foundation

enum InputSource: Hashable {
    case keyboard
    case virtual(GameAction)
    case controller(UUID, GameAction)
}

@MainActor
final class InputRouter {
    private var activeSources = [UInt32: Set<InputSource>]()

    func route(
        keyCode: UInt32,
        charCode: UInt32,
        isDown: Bool,
        modifiers: UInt32,
        source: InputSource = .keyboard,
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
