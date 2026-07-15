import XCTest
@testable import Ruffnova

@MainActor
final class InputProfileEditorViewModelTests: XCTestCase {
    func testKeyboardRecordingReplacesConflictingBinding() {
        let editor = InputProfileEditorViewModel(profile: InputProfile())

        editor.beginKeyboardRecording(for: .secondary)
        editor.recordKeyboard(hidUsage: 0x04, modifiers: 0)

        XCTAssertEqual(editor.pendingKeyboardConflict?.existingAction, .primary)
        XCTAssertNotEqual(editor.keyboardBinding(for: .secondary)?.trigger.hidUsage, 0x04)

        editor.confirmKeyboardConflictReplacement()

        XCTAssertEqual(editor.keyboardBinding(for: .secondary)?.trigger.hidUsage, 0x04)
        XCTAssertNil(editor.keyboardBinding(for: .primary))
        XCTAssertNil(editor.recordingAction)
        XCTAssertEqual(editor.conflictMessage, GameAction.primary.rawValue)
    }

    func testResetActionRestoresItsKeyboardBindingWithoutChangingOtherActions() {
        var profile = InputProfile()
        profile.keyboardBindings.removeAll { $0.action == .primary }
        profile.keyboardBindings.append(KeyboardBinding(trigger: KeyboardTrigger(hidUsage: 0x3A), action: .primary))
        let editor = InputProfileEditorViewModel(profile: profile)

        editor.resetBindings(for: .primary)

        XCTAssertEqual(editor.keyboardBinding(for: .primary)?.trigger.hidUsage, 0x04)
        XCTAssertEqual(editor.keyboardBinding(for: .secondary)?.trigger.hidUsage, 0x16)
    }

    func testClearingDefaultControllerBindingDisablesItsDefaultElement() {
        let editor = InputProfileEditorViewModel(profile: InputProfile())
        let resolver = InputProfileResolver()

        editor.clearControllerBinding(for: .secondary)

        XCTAssertNil(editor.effectiveControllerBinding(for: .secondary))
        XCTAssertNil(resolver.resolveController(element: .b, controllerID: UUID(), profile: editor.draft))
    }

    func testControllerLearningReplacesPreviousActionAndElement() {
        let editor = InputProfileEditorViewModel(profile: InputProfile())

        editor.beginControllerLearning(for: .secondary)
        editor.learnController(element: .a)

        XCTAssertEqual(editor.controllerBinding(for: .secondary)?.element, .a)
        XCTAssertNil(editor.learningControllerAction)

        editor.beginControllerLearning(for: .primary)
        editor.learnController(element: .a)

        XCTAssertEqual(editor.controllerBinding(for: .primary)?.element, .a)
        XCTAssertNil(editor.controllerBinding(for: .secondary))
    }

    func testCancelCapturePreservesDraft() {
        let editor = InputProfileEditorViewModel(profile: InputProfile())
        let original = editor.draft

        editor.beginKeyboardRecording(for: .primary)
        editor.cancelCapture()

        XCTAssertNil(editor.recordingAction)
        XCTAssertNil(editor.learningControllerAction)
        XCTAssertEqual(editor.draft, original)
    }

    func testRestoreDefaultsResetsCustomBindings() {
        var profile = InputProfile()
        profile.keyboardBindings = []
        profile.controllerBindings = [ControllerBinding(element: .leftShoulder, action: .primary)]
        let editor = InputProfileEditorViewModel(profile: profile)

        editor.restoreDefaults()

        XCTAssertFalse(editor.draft.keyboardBindings.isEmpty)
        XCTAssertTrue(editor.draft.controllerBindings.isEmpty)
        XCTAssertEqual(editor.draft.version, 2)
    }
}
