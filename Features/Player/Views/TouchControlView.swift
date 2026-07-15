import SwiftUI

struct TouchControlView: View {
    @EnvironmentObject private var locManager: LocalizationManager

    let control: TouchControlInstance
    let action: GameAction
    let send: (UUID, GameAction, Bool) -> Void

    var body: some View {
        Image(systemName: symbolName)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
            .nativeLiquidGlass(in: Circle())
            .opacity(control.opacity)
            .gesture(pressGesture)
            .accessibilityLabel(locManager.localized("input.action.\(action.rawValue)"))
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in send(control.id, action, true) }
            .onEnded { _ in send(control.id, action, false) }
    }

    private var symbolName: String {
        switch action {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        case .confirm: return "checkmark"
        case .cancel: return "xmark"
        case .primary: return "a.circle"
        case .secondary: return "b.circle"
        }
    }
}
