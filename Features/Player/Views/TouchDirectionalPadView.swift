import SwiftUI

struct TouchDirectionalPadView: View {
    @EnvironmentObject private var locManager: LocalizationManager

    let control: TouchControlInstance
    let send: (UUID, GameAction, Bool) -> Void

    private let columns = [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            Color.clear
            direction(.up, symbol: "chevron.up")
            Color.clear
            direction(.left, symbol: "chevron.left")
            Color.clear
            direction(.right, symbol: "chevron.right")
            Color.clear
            direction(.down, symbol: "chevron.down")
            Color.clear
        }
        .nativeLiquidGlass(in: Circle())
        .opacity(control.opacity)
        .accessibilityElement(children: .contain)
    }

    private func direction(_ action: GameAction, symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in send(control.id, action, true) }
                    .onEnded { _ in send(control.id, action, false) }
            )
            .accessibilityLabel(locManager.localized("input.action.\(action.rawValue)"))
    }
}
