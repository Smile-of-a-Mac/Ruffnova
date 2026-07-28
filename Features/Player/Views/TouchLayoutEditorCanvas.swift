import SwiftUI

struct TouchLayoutEditorCanvas: View {
    static let defaultCanvasSize = CGSize(width: 320, height: 520)

    @ObservedObject var editor: TouchLayoutEditorViewModel
    @EnvironmentObject private var locManager: LocalizationManager
    @State private var testedControlID: UUID?

    var body: some View {
        GeometryReader { geometry in
            let size = constrainedCanvasSize(in: geometry.size)
            let overlapIDs = editor.overlappingControlIDs(canvasSize: size)

            ZStack {
                RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
                    .fill(.black.opacity(0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
                            .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
                    }

                ForEach(editor.controls.sorted { $0.zIndex < $1.zIndex }) { control in
                    editorControl(control, canvasSize: size, isOverlapping: overlapIDs.contains(control.id))
                }

                if !overlapIDs.isEmpty {
                    Label(locManager.localized("touchLayout.editor.overlapWarning"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(NativeSpacing.sm)
                        .background(.thinMaterial, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(NativeSpacing.sm)
                }
            }
            .frame(width: size.width, height: size.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(editor.orientation == .portrait ? 320 / 520 : 520 / 320, contentMode: .fit)
    }

    private func editorControl(
        _ control: TouchControlInstance,
        canvasSize: CGSize,
        isOverlapping: Bool
    ) -> some View {
        let displayControl = TouchLayoutMetrics.clamped(control, in: canvasSize)
        let frame = TouchLayoutMetrics.frame(for: displayControl, in: canvasSize)
        let isSelected = editor.selectedControlID == control.id

        return TouchLayoutEditorControl(
            control: displayControl,
            isSelected: isSelected,
            isOverlapping: isOverlapping,
            isTesting: editor.isTesting,
            isTested: testedControlID == control.id
        ) {
            editor.selectedControlID = control.id
            testedControlID = control.id
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .gesture(editGesture(for: control, canvasSize: canvasSize))
        .accessibilityLabel(accessibilityLabel(for: control))
    }

    private func editGesture(for control: TouchControlInstance, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !editor.isTesting else { return }
                editor.selectedControlID = control.id
                editor.move(
                    controlID: control.id,
                    to: NormalizedPoint(
                        x: Double(value.location.x / canvasSize.width),
                        y: Double(value.location.y / canvasSize.height)
                    ),
                    canvasSize: canvasSize
                )
            }
    }

    private func constrainedCanvasSize(in available: CGSize) -> CGSize {
        let targetAspect: CGFloat = editor.orientation == .portrait ? 320 / 520 : 520 / 320
        let width = min(available.width, available.height * targetAspect)
        return CGSize(width: max(width, 1), height: max(width / targetAspect, 1))
    }

    private func accessibilityLabel(for control: TouchControlInstance) -> String {
        control.actions.map { locManager.localized("input.action.\($0.rawValue)") }.joined(separator: ", ")
    }
}

private struct TouchLayoutEditorControl: View {
    let control: TouchControlInstance
    let isSelected: Bool
    let isOverlapping: Bool
    let isTesting: Bool
    let isTested: Bool
    let select: () -> Void

    var body: some View {
        Group {
            switch control.kind {
            case .button:
                Image(systemName: symbol(for: control.actions.first))
                    .font(.headline.weight(.semibold))
            case .directionalPad:
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.headline.weight(.semibold))
            case .unknown:
                Image(systemName: "questionmark")
            }
        }
        .foregroundStyle(isTested ? Color.accentColor : .primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Circle())
        .background(.thinMaterial, in: Circle())
        .overlay {
            Circle().strokeBorder(borderColor, lineWidth: isSelected ? 3 : 1)
        }
        .opacity(control.isEnabled ? control.opacity : 0.35)
        .onTapGesture(perform: select)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var borderColor: Color {
        if isOverlapping { return .yellow }
        if isSelected || isTesting { return .accentColor }
        return .white.opacity(0.35)
    }

    private func symbol(for action: GameAction?) -> String {
        switch action {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        case .confirm: return "checkmark"
        case .cancel: return "xmark"
        case .primary: return "a.circle"
        case .secondary: return "b.circle"
        case nil: return "questionmark"
        }
    }
}
