import Foundation
import GameController

@MainActor
final class GameControllerInputService {
    private let send: (UUID, GameAction, Bool) -> Void
    private var observers = [NSObjectProtocol]()
    private var controllerIDs = [ObjectIdentifier: UUID]()

    init(send: @escaping (UUID, GameAction, Bool) -> Void) {
        self.send = send
        observers = [
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let controller = notification.object as? GCController else { return }
                Task { @MainActor in self?.connect(controller) }
            },
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidDisconnect,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let controller = notification.object as? GCController else { return }
                Task { @MainActor in self?.disconnect(controller) }
            },
        ]
        GCController.controllers().forEach(connect)
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func connect(_ controller: GCController) {
        let identifier = ObjectIdentifier(controller)
        guard controllerIDs[identifier] == nil else { return }
        let controllerID = UUID()
        controllerIDs[identifier] = controllerID

        if let input = controller.extendedGamepad {
            bind(input.dpad.up, action: .up, controllerID: controllerID)
            bind(input.dpad.down, action: .down, controllerID: controllerID)
            bind(input.dpad.left, action: .left, controllerID: controllerID)
            bind(input.dpad.right, action: .right, controllerID: controllerID)
            bind(input.buttonA, action: .primary, controllerID: controllerID)
            bind(input.buttonB, action: .secondary, controllerID: controllerID)
            bind(input.buttonMenu, action: .confirm, controllerID: controllerID)
            if let buttonOptions = input.buttonOptions {
                bind(buttonOptions, action: .cancel, controllerID: controllerID)
            }
        } else if let input = controller.microGamepad {
            bind(input.dpad.up, action: .up, controllerID: controllerID)
            bind(input.dpad.down, action: .down, controllerID: controllerID)
            bind(input.dpad.left, action: .left, controllerID: controllerID)
            bind(input.dpad.right, action: .right, controllerID: controllerID)
            bind(input.buttonA, action: .primary, controllerID: controllerID)
            bind(input.buttonX, action: .secondary, controllerID: controllerID)
        }
    }

    private func disconnect(_ controller: GCController) {
        guard let controllerID = controllerIDs.removeValue(forKey: ObjectIdentifier(controller)) else { return }
        GameAction.allCases.forEach { send(controllerID, $0, false) }
    }

    private func bind(_ input: GCControllerButtonInput, action: GameAction, controllerID: UUID) {
        input.valueChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in self?.send(controllerID, action, pressed) }
        }
    }
}
