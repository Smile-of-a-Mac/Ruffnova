import Foundation

/// Pure, stateless resolver that maps physical and virtual input events to the
/// output key codes and `InputSource` identities used by `InputRouter`.
///
/// All methods are free of side-effects and safe to call from any context.
struct InputProfileResolver {

    // MARK: - Default bindings

    /// Default controller element → GameAction bindings applied when a profile
    /// carries no custom controller bindings.
    static let defaultControllerBindings: [ControllerBinding] = [
        ControllerBinding(element: .dpadUp,    action: .up),
        ControllerBinding(element: .dpadDown,  action: .down),
        ControllerBinding(element: .dpadLeft,  action: .left),
        ControllerBinding(element: .dpadRight, action: .right),
        ControllerBinding(element: .a,         action: .primary),
        ControllerBinding(element: .b,         action: .secondary),
        ControllerBinding(element: .menu,      action: .confirm),
        ControllerBinding(element: .options,   action: .cancel),
    ]

    /// Stable, deterministic virtual control instance IDs used when a touch
    /// action is dispatched without an explicit `TouchControlInstance` ID.
    /// Each action maps to a fixed UUID so the `InputRouter` tracks presses
    /// consistently across calls.
    static func stableVirtualControlID(for action: GameAction) -> UUID {
        switch action {
        case .up:        return UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        case .down:      return UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        case .left:      return UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        case .right:     return UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        case .confirm:   return UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
        case .cancel:    return UUID(uuidString: "10000000-0000-0000-0000-000000000006")!
        case .primary:   return UUID(uuidString: "10000000-0000-0000-0000-000000000007")!
        case .secondary: return UUID(uuidString: "10000000-0000-0000-0000-000000000008")!
        }
    }

    // MARK: - Keyboard

    /// Resolves a physical keyboard event against the profile's `keyboardBindings`.
    ///
    /// - If the physical HID code matches an enabled binding, returns the action's
    ///   configured output key code.
    /// - Otherwise passes the physical HID code through unchanged so unmapped keys
    ///   still reach the SWF (e.g. text input, number keys, custom shortcuts).
    func resolveKeyboard(
        physicalHID: UInt32,
        charCode: UInt32,
        modifiers: UInt32,
        profile: InputProfile
    ) -> (keyCode: UInt32, charCode: UInt32, modifiers: UInt32, source: InputSource) {
        let source = InputSource.keyboard(physicalHID: physicalHID, modifiers: modifiers)
        if let binding = profile.keyboardBindings.first(where: {
            $0.isEnabled &&
            $0.trigger.hidUsage == physicalHID &&
            ($0.trigger.requiredModifiers == 0 ||
             $0.trigger.requiredModifiers & modifiers == $0.trigger.requiredModifiers)
        }), let output = profile.actionOutputs[binding.action] {
            return (output.keyCode, output.charCode, output.modifiers, source)
        }
        // Passthrough: key is not in the profile, forward as-is.
        return (physicalHID, charCode, modifiers, source)
    }

    // MARK: - Controller

    /// Resolves a controller element event.
    ///
    /// Uses the profile's `controllerBindings` if non-empty, otherwise falls back
    /// to `defaultControllerBindings` so controllers work out-of-the-box.
    /// Returns `nil` when the element has no mapping (e.g. shoulder buttons before
    /// the user configures them).
    func resolveController(
        element: ControllerElement,
        controllerID: UUID,
        profile: InputProfile
    ) -> (keyCode: UInt32, charCode: UInt32, modifiers: UInt32, source: InputSource)? {
        let source = InputSource.controller(controllerID: controllerID, element: element)
        if let customBinding = profile.controllerBindings.first(where: { $0.element == element }) {
            guard customBinding.isEnabled,
                  let output = profile.actionOutputs[customBinding.action] else { return nil }
            return (output.keyCode, output.charCode, output.modifiers, source)
        }
        guard let binding = Self.defaultControllerBindings.first(where: { $0.element == element }),
              let output = profile.actionOutputs[binding.action] else { return nil }
        return (output.keyCode, output.charCode, output.modifiers, source)
    }

    // MARK: - Touch / Virtual

    /// Resolves an on-screen touch control action.
    ///
    /// The `instanceID` uniquely identifies the `TouchControlInstance` so that two
    /// buttons mapped to the same action are tracked as independent sources in the
    /// `InputRouter`.  Use `stableVirtualControlID(for:)` when an explicit instance
    /// is not yet available (e.g. the legacy `sendVirtualGameAction` path).
    func resolveTouchControl(
        instanceID: UUID,
        action: GameAction,
        profile: InputProfile
    ) -> (keyCode: UInt32, charCode: UInt32, modifiers: UInt32, source: InputSource)? {
        let source = InputSource.virtual(controlInstanceID: instanceID, action: action)
        guard let output = profile.actionOutputs[action] else { return nil }
        return (output.keyCode, output.charCode, output.modifiers, source)
    }

    // MARK: - Validation

    /// Returns pairs of enabled `KeyboardBinding`s that share the same trigger,
    /// which would produce ambiguous resolution at runtime.
    func conflictingKeyboardBindings(in profile: InputProfile) -> [(KeyboardBinding, KeyboardBinding)] {
        var conflicts: [(KeyboardBinding, KeyboardBinding)] = []
        let enabled = profile.keyboardBindings.filter { $0.isEnabled }
        for i in enabled.indices {
            for j in (i + 1)..<enabled.count where enabled[i].trigger == enabled[j].trigger {
                conflicts.append((enabled[i], enabled[j]))
            }
        }
        return conflicts
    }
}
