import Foundation

@MainActor
final class InputProfileEditorViewModel: ObservableObject {
    struct PendingKeyboardConflict: Identifiable, Equatable {
        let action: GameAction
        let trigger: KeyboardTrigger
        let existingAction: GameAction

        var id: String { "\(action.rawValue)-\(trigger.hidUsage)-\(trigger.requiredModifiers)" }
    }

    @Published private(set) var draft: InputProfile
    @Published private(set) var recordingAction: GameAction?
    @Published private(set) var learningControllerAction: GameAction?
    @Published private(set) var conflictMessage: String?
    @Published private(set) var pendingKeyboardConflict: PendingKeyboardConflict?

    private let resolver = InputProfileResolver()

    init(profile: InputProfile) {
        self.draft = profile
    }

    var hasConflicts: Bool {
        !resolver.conflictingKeyboardBindings(in: draft).isEmpty
    }

    func beginKeyboardRecording(for action: GameAction) {
        recordingAction = action
        learningControllerAction = nil
        conflictMessage = nil
        pendingKeyboardConflict = nil
    }

    func beginControllerLearning(for action: GameAction) {
        learningControllerAction = action
        recordingAction = nil
        conflictMessage = nil
        pendingKeyboardConflict = nil
    }

    func cancelCapture() {
        recordingAction = nil
        learningControllerAction = nil
        pendingKeyboardConflict = nil
    }

    func recordKeyboard(hidUsage: UInt32, modifiers: UInt32) {
        guard let action = recordingAction else { return }
        recordingAction = nil
        let trigger = KeyboardTrigger(hidUsage: hidUsage, requiredModifiers: modifiers)
        if let conflicting = draft.keyboardBindings.first(where: {
            $0.isEnabled && $0.trigger == trigger && $0.action != action
        }) {
            pendingKeyboardConflict = PendingKeyboardConflict(
                action: action,
                trigger: trigger,
                existingAction: conflicting.action
            )
            return
        }
        replaceKeyboardBinding(for: action, trigger: trigger)
    }

    func confirmKeyboardConflictReplacement() {
        guard let conflict = pendingKeyboardConflict else { return }
        draft.keyboardBindings.removeAll {
            $0.action == conflict.action || ($0.isEnabled && $0.trigger == conflict.trigger)
        }
        draft.keyboardBindings.append(KeyboardBinding(trigger: conflict.trigger, action: conflict.action))
        conflictMessage = conflict.existingAction.rawValue
        pendingKeyboardConflict = nil
    }

    func cancelKeyboardConflictReplacement() {
        pendingKeyboardConflict = nil
    }

    func learnController(element: ControllerElement) {
        guard let action = learningControllerAction, element != .unknown else { return }
        learningControllerAction = nil
        draft.controllerBindings.removeAll { $0.element == element || $0.action == action }
        draft.controllerBindings.append(ControllerBinding(element: element, action: action))
    }

    func clearKeyboardBinding(for action: GameAction) {
        draft.keyboardBindings.removeAll { $0.action == action }
        conflictMessage = nil
    }

    func clearControllerBinding(for action: GameAction) {
        draft.controllerBindings.removeAll { $0.action == action }
        guard let defaultBinding = InputProfileResolver.defaultControllerBindings.first(where: { $0.action == action }),
              !draft.controllerBindings.contains(where: { $0.element == defaultBinding.element }) else { return }
        draft.controllerBindings.append(
            ControllerBinding(element: defaultBinding.element, action: action, isEnabled: false)
        )
    }

    func resetBindings(for action: GameAction) {
        let defaultProfile = InputProfile()
        guard let defaultBinding = defaultProfile.keyboardBindings.first(where: { $0.action == action }) else { return }
        draft.keyboardBindings.removeAll {
            $0.action == action || ($0.isEnabled && $0.trigger == defaultBinding.trigger)
        }
        draft.keyboardBindings.append(defaultBinding)
        draft.controllerBindings.removeAll { $0.action == action }
        conflictMessage = nil
        pendingKeyboardConflict = nil
    }

    func restoreDefaults() {
        draft = InputProfile()
        cancelCapture()
        conflictMessage = nil
        pendingKeyboardConflict = nil
    }

    func keyboardBinding(for action: GameAction) -> KeyboardBinding? {
        draft.keyboardBindings.first { $0.action == action && $0.isEnabled }
    }

    func controllerBinding(for action: GameAction) -> ControllerBinding? {
        draft.controllerBindings.first { $0.action == action }
    }

    func effectiveControllerBinding(for action: GameAction) -> ControllerBinding? {
        if let customBinding = draft.controllerBindings.first(where: { $0.action == action }) {
            return customBinding.isEnabled ? customBinding : nil
        }
        guard let defaultBinding = InputProfileResolver.defaultControllerBindings.first(where: { $0.action == action }) else {
            return nil
        }
        if let customBinding = draft.controllerBindings.first(where: { $0.element == defaultBinding.element }) {
            return customBinding.isEnabled && customBinding.action == action ? customBinding : nil
        }
        return defaultBinding
    }

    func output(for action: GameAction) -> GameKeyOutput? {
        draft.actionOutputs[action]
    }

    func hasConflict(for action: GameAction) -> Bool {
        resolver.conflictingKeyboardBindings(in: draft).contains {
            $0.0.action == action || $0.1.action == action
        }
    }

    private func replaceKeyboardBinding(for action: GameAction, trigger: KeyboardTrigger) {
        draft.keyboardBindings.removeAll { $0.action == action }
        draft.keyboardBindings.append(KeyboardBinding(trigger: trigger, action: action))
    }
}
