import Foundation
import GameController

@MainActor
final class GameControllerInputService {
    private let send: (UUID, ControllerElement, Bool) -> Void
    private var observers = [NSObjectProtocol]()
    private var controllerIDs = [ObjectIdentifier: UUID]()
    private var captureHandler: ((ControllerElement) -> Void)?

    init(send: @escaping (UUID, ControllerElement, Bool) -> Void) {
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

    func captureNextInput(_ handler: @escaping (ControllerElement) -> Void) {
        captureHandler = handler
    }

    func cancelCapture() {
        captureHandler = nil
    }

    private func connect(_ controller: GCController) {
        let identifier = ObjectIdentifier(controller)
        guard controllerIDs[identifier] == nil else { return }
        let controllerID = UUID()
        controllerIDs[identifier] = controllerID

        if let input = controller.extendedGamepad {
            bind(input.dpad.up,    element: .dpadUp,    controllerID: controllerID)
            bind(input.dpad.down,  element: .dpadDown,  controllerID: controllerID)
            bind(input.dpad.left,  element: .dpadLeft,  controllerID: controllerID)
            bind(input.dpad.right, element: .dpadRight, controllerID: controllerID)
            bind(input.buttonA,    element: .a,         controllerID: controllerID)
            bind(input.buttonB,    element: .b,         controllerID: controllerID)
            bind(input.buttonX,    element: .x,         controllerID: controllerID)
            bind(input.buttonY,    element: .y,         controllerID: controllerID)
            bind(input.buttonMenu, element: .menu,      controllerID: controllerID)
            bind(input.leftShoulder, element: .leftShoulder, controllerID: controllerID)
            bind(input.rightShoulder, element: .rightShoulder, controllerID: controllerID)
            bind(input.leftTrigger, element: .leftTrigger, controllerID: controllerID)
            bind(input.rightTrigger, element: .rightTrigger, controllerID: controllerID)
            if let buttonOptions = input.buttonOptions {
                bind(buttonOptions, element: .options, controllerID: controllerID)
            }
            if let thumbstickButton = input.leftThumbstickButton {
                bind(thumbstickButton, element: .leftThumbstickButton, controllerID: controllerID)
            }
            if let thumbstickButton = input.rightThumbstickButton {
                bind(thumbstickButton, element: .rightThumbstickButton, controllerID: controllerID)
            }
        } else if let input = controller.microGamepad {
            bind(input.dpad.up,    element: .dpadUp,    controllerID: controllerID)
            bind(input.dpad.down,  element: .dpadDown,  controllerID: controllerID)
            bind(input.dpad.left,  element: .dpadLeft,  controllerID: controllerID)
            bind(input.dpad.right, element: .dpadRight, controllerID: controllerID)
            bind(input.buttonA, element: .a, controllerID: controllerID)
            bind(input.buttonX, element: .x, controllerID: controllerID)
        }
    }

    private func disconnect(_ controller: GCController) {
        guard let controllerID = controllerIDs.removeValue(forKey: ObjectIdentifier(controller)) else { return }
        ControllerElement.allCases.forEach { send(controllerID, $0, false) }
    }

    private func bind(_ input: GCControllerButtonInput, element: ControllerElement, controllerID: UUID) {
        input.valueChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in
                guard let self else { return }
                if pressed, let captureHandler = self.captureHandler {
                    self.captureHandler = nil
                    captureHandler(element)
                    return
                }
                guard self.captureHandler == nil else { return }
                self.send(controllerID, element, pressed)
            }
        }
    }
}
