import SwiftUI

struct TouchLayoutEditorView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID
    @StateObject private var editor: TouchLayoutEditorViewModel
    @State private var selectedPreset: InputPreset = .classic

    init(itemID: UUID, layoutSet: TouchLayoutSet) {
        self.itemID = itemID
        _editor = StateObject(wrappedValue: TouchLayoutEditorViewModel(layoutSet: layoutSet))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: NativeSpacing.md) {
                orientationPicker
                TouchLayoutEditorCanvas(editor: editor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                editorControls
            }
            .padding(NativeSpacing.md)
            .navigationTitle(locManager.localized("touchLayout.editor.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locManager.localized("collection.cancel")) {
                        appState.releasePlayerInput()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(locManager.localized("input.editor.save")) {
                        var profile = appState.currentInputProfile()
                        profile.touchLayouts = editor.layoutSet
                        appState.updateInputProfile(profile, for: itemID)
                        dismiss()
                    }
                }
            }
            .onAppear { appState.releasePlayerInput() }
            .onDisappear { appState.releasePlayerInput() }
        }
    }

    private var orientationPicker: some View {
        Picker(locManager.localized("touchLayout.editor.orientation"), selection: Binding(
            get: { editor.orientation },
            set: { orientation in
                appState.releasePlayerInput()
                editor.selectOrientation(orientation)
            }
        )) {
            Text(locManager.localized("touchLayout.editor.portrait")).tag(TouchLayoutOrientation.portrait)
            Text(locManager.localized("touchLayout.editor.landscape")).tag(TouchLayoutOrientation.landscape)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(locManager.localized("touchLayout.editor.orientation"))
    }

    private var editorControls: some View {
        VStack(spacing: NativeSpacing.sm) {
            HStack(spacing: NativeSpacing.sm) {
                Menu {
                    ForEach(InputPreset.allCases) { preset in
                        Button(locManager.localized("touchLayout.preset.\(preset.rawValue)")) {
                            selectedPreset = preset
                            editor.apply(preset)
                        }
                    }
                } label: {
                    Label(locManager.localized("touchLayout.editor.presets"), systemImage: "rectangle.3.group")
                }

                Menu {
                    ForEach(GameAction.allCases) { action in
                        Button(locManager.localized("input.action.\(action.rawValue)")) {
                            editor.addButton(action: action, canvasSize: TouchLayoutEditorCanvas.defaultCanvasSize)
                        }
                    }
                    Button(locManager.localized("touchLayout.editor.addDirectionalPad")) {
                        editor.addDirectionalPad(canvasSize: TouchLayoutEditorCanvas.defaultCanvasSize)
                    }
                } label: {
                    Label(locManager.localized("touchLayout.editor.add"), systemImage: "plus")
                }

                Toggle(isOn: $editor.isTesting) {
                    Image(systemName: "hand.tap")
                }
                .toggleStyle(.button)
                .accessibilityLabel(locManager.localized("touchLayout.editor.testMode"))

                Spacer()

                Button {
                    editor.restoreDefaultForCurrentOrientation()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel(locManager.localized("touchLayout.editor.restoreOrientation"))

                Button(role: .destructive) {
                    editor.restoreAllDefaults()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel(locManager.localized("touchLayout.editor.restoreAll"))
            }
            .buttonStyle(.bordered)

            if let selected = editor.selectedControl {
                selectedControlInspector(selected)
            }
        }
    }

    private func selectedControlInspector(_ control: TouchControlInstance) -> some View {
        VStack(spacing: NativeSpacing.sm) {
            HStack(spacing: NativeSpacing.sm) {
                Toggle(locManager.localized("touchLayout.editor.enabled"), isOn: Binding(
                    get: { control.isEnabled },
                    set: { editor.setEnabled($0, for: control.id) }
                ))

                Spacer()

                Button {
                    editor.duplicateSelected(canvasSize: TouchLayoutEditorCanvas.defaultCanvasSize)
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .accessibilityLabel(locManager.localized("touchLayout.editor.duplicate"))

                Button(role: .destructive) {
                    editor.deleteSelected()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(locManager.localized("touchLayout.editor.delete"))
            }

            HStack(spacing: NativeSpacing.sm) {
                Text(locManager.localized("touchLayout.editor.opacity"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { control.opacity },
                        set: { editor.setOpacity($0, for: control.id) }
                    ),
                    in: 0.2...1
                )
            }

            HStack(spacing: NativeSpacing.sm) {
                Text(locManager.localized("touchLayout.editor.size"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { max(control.size.width, control.size.height) },
                        set: { value in
                            editor.resize(
                                controlID: control.id,
                                to: NormalizedSize(width: value, height: value),
                                canvasSize: TouchLayoutEditorCanvas.defaultCanvasSize
                            )
                        }
                    ),
                    in: 0.1...0.42
                )
            }
        }
        .padding(NativeSpacing.sm)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: NativeRadius.sm, style: .continuous))
    }
}
