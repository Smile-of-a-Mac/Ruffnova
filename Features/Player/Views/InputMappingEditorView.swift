import SwiftUI

struct InputMappingEditorView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID
    @StateObject private var editor: InputProfileEditorViewModel
    @State private var showPlatformKeyCapture = false

    init(itemID: UUID, profile: InputProfile) {
        self.itemID = itemID
        _editor = StateObject(wrappedValue: InputProfileEditorViewModel(profile: profile))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(locManager.localized("input.editor.explanation"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(locManager.localized("input.editor.actions")) {
                    ForEach(GameAction.allCases) { action in
                        actionRow(action)
                    }
                }

                Section {
                    Button(locManager.localized("input.editor.restoreDefaults"), role: .destructive) {
                        editor.restoreDefaults()
                        appState.endInputBindingCapture()
                    }
                }
            }
            .navigationTitle(locManager.localized("input.editor.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locManager.localized("collection.cancel")) {
                        appState.endInputBindingCapture()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(locManager.localized("input.editor.save")) {
                        appState.updateInputProfile(editor.draft, for: itemID)
                        appState.endInputBindingCapture()
                        dismiss()
                    }
                    .disabled(editor.hasConflicts)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyEvent)) { notification in
                guard editor.recordingAction != nil,
                      let userInfo = notification.userInfo,
                      let keyCode = userInfo["keyCode"] as? UInt32,
                      let isDown = userInfo["isDown"] as? Bool,
                      let modifiers = userInfo["modifiers"] as? UInt,
                      isDown else { return }
                editor.recordKeyboard(hidUsage: keyCode, modifiers: UInt32(modifiers))
                appState.endInputBindingCapture()
                showPlatformKeyCapture = false
            }
            .onDisappear { appState.endInputBindingCapture() }
            .alert(
                locManager.localized("input.editor.conflictTitle"),
                isPresented: Binding(
                    get: { editor.pendingKeyboardConflict != nil },
                    set: { isPresented in
                        if !isPresented { editor.cancelKeyboardConflictReplacement() }
                    }
                )
            ) {
                Button(locManager.localized("input.editor.replace"), role: .destructive) {
                    editor.confirmKeyboardConflictReplacement()
                }
                Button(locManager.localized("collection.cancel"), role: .cancel) {
                    editor.cancelKeyboardConflictReplacement()
                }
            } message: {
                if let conflict = editor.pendingKeyboardConflict {
                    Text(
                        String(
                            format: locManager.localized("input.editor.conflictMessage"),
                            locManager.localized("input.action.\(conflict.existingAction.rawValue)"),
                            locManager.localized("input.action.\(conflict.action.rawValue)")
                        )
                    )
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showPlatformKeyCapture) {
                PlatformKeyCaptureView { hidUsage, modifiers in
                    editor.recordKeyboard(hidUsage: hidUsage, modifiers: modifiers)
                    appState.endInputBindingCapture()
                    showPlatformKeyCapture = false
                }
                .environmentObject(locManager)
            }
            #endif
        }
    }

    @ViewBuilder
    private func actionRow(_ action: GameAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(locManager.localized("input.action.\(action.rawValue)"))
                .font(.headline)

            if let output = editor.output(for: action) {
                Label(
                    "\(locManager.localized("input.editor.output")) HID 0x\(String(output.keyCode, radix: 16, uppercase: true))",
                    systemImage: "arrow.right.to.line"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if editor.hasConflict(for: action) || editor.pendingKeyboardConflict?.action == action {
                Label(locManager.localized("input.editor.conflict"), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Label(
                    keyboardTitle(for: action),
                    systemImage: "keyboard"
                )
                .font(.caption)
                Spacer()
                Button(editor.recordingAction == action
                       ? locManager.localized("input.editor.pressKey")
                       : locManager.localized("input.editor.recordKey")) {
                    editor.beginKeyboardRecording(for: action)
                    appState.beginInputBindingCapture()
                    #if os(iOS)
                    showPlatformKeyCapture = true
                    #endif
                }
                .buttonStyle(.bordered)
                .accessibilityValue(
                    editor.recordingAction == action
                        ? locManager.localized("input.editor.pressKey")
                        : ""
                )

                if editor.keyboardBinding(for: action) != nil {
                    Button(role: .destructive) {
                        editor.clearKeyboardBinding(for: action)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel(locManager.localized("input.editor.clearKey"))
                }
            }

            HStack {
                Label(
                    controllerTitle(for: action),
                    systemImage: "gamecontroller"
                )
                .font(.caption)
                Spacer()
                Button(editor.learningControllerAction == action
                       ? locManager.localized("input.editor.pressController")
                       : locManager.localized("input.editor.learnController")) {
                    editor.beginControllerLearning(for: action)
                    appState.captureNextControllerElement { element in
                        editor.learnController(element: element)
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityValue(
                    editor.learningControllerAction == action
                        ? locManager.localized("input.editor.pressController")
                        : ""
                )

                if editor.controllerBinding(for: action) != nil {
                    Button(role: .destructive) {
                        editor.clearControllerBinding(for: action)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel(locManager.localized("input.editor.clearController"))
                }

                Button {
                    editor.resetBindings(for: action)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel(locManager.localized("input.editor.resetAction"))
            }
        }
        .padding(.vertical, 3)
    }

    private func keyboardTitle(for action: GameAction) -> String {
        guard let binding = editor.keyboardBinding(for: action) else {
            return locManager.localized("input.editor.unassigned")
        }
        return "HID 0x\(String(binding.trigger.hidUsage, radix: 16, uppercase: true))"
    }

    private func controllerTitle(for action: GameAction) -> String {
        guard let binding = editor.effectiveControllerBinding(for: action) else {
            return locManager.localized("input.editor.unassigned")
        }
        return binding.element.rawValue
    }
}
