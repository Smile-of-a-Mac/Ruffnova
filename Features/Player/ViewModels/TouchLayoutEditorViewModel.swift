import Foundation

@MainActor
final class TouchLayoutEditorViewModel: ObservableObject {
    @Published private(set) var layoutSet: TouchLayoutSet
    @Published var orientation: TouchLayoutOrientation = .portrait
    @Published var selectedControlID: UUID?
    @Published var isTesting = false

    init(layoutSet: TouchLayoutSet) {
        self.layoutSet = layoutSet.isEmpty ? InputPreset.classic.layoutSet : layoutSet
    }

    var controls: [TouchControlInstance] {
        layoutSet.controls(for: orientation)
    }

    func selectOrientation(_ orientation: TouchLayoutOrientation) {
        self.orientation = orientation
        selectedControlID = nil
    }

    func move(controlID: UUID, to center: NormalizedPoint, canvasSize: CGSize) {
        update(controlID: controlID, canvasSize: canvasSize) { control in
            control.center = center
        }
    }

    func resize(controlID: UUID, to size: NormalizedSize, canvasSize: CGSize) {
        update(controlID: controlID, canvasSize: canvasSize) { control in
            control.size = size
        }
    }

    func setOpacity(_ opacity: Double, for controlID: UUID) {
        update(controlID: controlID) { control in
            control.opacity = min(max(opacity, 0.2), 1)
        }
    }

    func setEnabled(_ isEnabled: Bool, for controlID: UUID) {
        update(controlID: controlID) { $0.isEnabled = isEnabled }
    }

    func addButton(action: GameAction, canvasSize: CGSize) {
        let control = TouchControlInstance(
            kind: .button,
            actions: [action],
            center: NormalizedPoint(x: 0.5, y: 0.5),
            size: NormalizedSize(width: 0.14, height: 0.14),
            zIndex: nextZIndex
        )
        append(TouchLayoutMetrics.clamped(control, in: canvasSize))
        selectedControlID = control.id
    }

    func addDirectionalPad(canvasSize: CGSize) {
        let control = TouchControlInstance(
            kind: .directionalPad,
            actions: [.up, .down, .left, .right],
            center: NormalizedPoint(x: 0.5, y: 0.5),
            size: NormalizedSize(width: 0.24, height: 0.24),
            zIndex: nextZIndex
        )
        append(TouchLayoutMetrics.clamped(control, in: canvasSize))
        selectedControlID = control.id
    }

    func duplicateSelected(canvasSize: CGSize) {
        guard let selectedControl else { return }
        var copy = selectedControl
        copy.id = UUID()
        copy.center = NormalizedPoint(x: copy.center.x + 0.06, y: copy.center.y + 0.06)
        copy.zIndex = nextZIndex
        append(TouchLayoutMetrics.clamped(copy, in: canvasSize))
        selectedControlID = copy.id
    }

    func deleteSelected() {
        guard let selectedControlID else { return }
        var controls = self.controls
        controls.removeAll { $0.id == selectedControlID }
        layoutSet.setControls(controls, for: orientation)
        self.selectedControlID = nil
    }

    func apply(_ preset: InputPreset) {
        layoutSet = preset.layoutSet
        selectedControlID = nil
    }

    func restoreDefaultForCurrentOrientation() {
        layoutSet.setControls(InputPreset.classic.controls(for: orientation), for: orientation)
        selectedControlID = nil
    }

    func restoreAllDefaults() {
        layoutSet = InputPreset.classic.layoutSet
        selectedControlID = nil
    }

    func overlappingControlIDs(canvasSize: CGSize) -> Set<UUID> {
        TouchLayoutMetrics.overlappingControlIDs(in: controls, canvasSize: canvasSize)
    }

    var selectedControl: TouchControlInstance? {
        guard let selectedControlID else { return nil }
        return controls.first { $0.id == selectedControlID }
    }

    private var nextZIndex: Int {
        (controls.map(\.zIndex).max() ?? -1) + 1
    }

    private func append(_ control: TouchControlInstance) {
        var controls = self.controls
        controls.append(control)
        layoutSet.setControls(controls, for: orientation)
    }

    private func update(
        controlID: UUID,
        canvasSize: CGSize? = nil,
        changes: (inout TouchControlInstance) -> Void
    ) {
        var controls = self.controls
        guard let index = controls.firstIndex(where: { $0.id == controlID }) else { return }
        changes(&controls[index])
        if let canvasSize {
            controls[index] = TouchLayoutMetrics.clamped(controls[index], in: canvasSize)
        }
        layoutSet.setControls(controls, for: orientation)
    }
}
