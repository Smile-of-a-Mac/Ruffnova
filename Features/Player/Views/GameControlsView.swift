import SwiftUI

struct GameControlsView: View {
    let controls: [TouchControlInstance]
    var safeAreaInsets: EdgeInsets = EdgeInsets()
    let send: (UUID, GameAction, Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = CGSize(
                width: max(0, geometry.size.width - safeAreaInsets.leading - safeAreaInsets.trailing),
                height: max(0, geometry.size.height - safeAreaInsets.top - safeAreaInsets.bottom)
            )

            ZStack {
                ForEach(controls.filter(\.isEnabled).sorted { $0.zIndex < $1.zIndex }) { control in
                    controlView(for: control, canvasSize: canvasSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func controlView(for control: TouchControlInstance, canvasSize: CGSize) -> some View {
        let clampedControl = TouchLayoutMetrics.clamped(control, in: canvasSize)
        let frame = TouchLayoutMetrics.frame(for: clampedControl, in: canvasSize)
        let position = CGPoint(
            x: safeAreaInsets.leading + frame.midX,
            y: safeAreaInsets.top + frame.midY
        )

        switch control.kind {
        case .button:
            if let action = control.actions.first {
                TouchControlView(control: clampedControl, action: action, send: send)
                    .frame(width: frame.width, height: frame.height)
                    .position(position)
            }
        case .directionalPad:
            TouchDirectionalPadView(control: clampedControl, send: send)
                .frame(width: frame.width, height: frame.height)
                .position(position)
        case .unknown:
            EmptyView()
        }
    }
}
