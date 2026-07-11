import SwiftUI

struct GameControlsView: View {
    let profile: InputProfile
    let send: (GameAction, Bool) -> Void

    private let layoutWidth: CGFloat = 408

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(spacing: 4) {
                controlButton(.up, systemName: "chevron.up")
                HStack(spacing: 4) {
                    controlButton(.left, systemName: "chevron.left")
                    controlButton(.down, systemName: "chevron.down")
                    controlButton(.right, systemName: "chevron.right")
                }
            }

            HStack(spacing: 12) {
                controlButton(.cancel, systemName: "xmark")
                controlButton(.confirm, systemName: "circle")
            }

            HStack(spacing: 12) {
                controlButton(.secondary, systemName: "b.circle")
                controlButton(.primary, systemName: "a.circle")
            }
        }
        .padding(10)
        .frame(width: layoutWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func controlButton(_ action: GameAction, systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary.opacity(0.9))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .background(Color.primary.opacity(0.12), in: Circle())
            .accessibilityLabel(Text(action.rawValue.capitalized))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in send(action, true) }
                    .onEnded { _ in send(action, false) }
            )
    }
}
