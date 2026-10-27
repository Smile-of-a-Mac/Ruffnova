import SwiftUI

struct GameControlsView: View {
    let controls: [TouchControlInstance]
    let orientation: TouchLayoutOrientation
    var safeAreaInsets: EdgeInsets = EdgeInsets()
    let send: (UUID, GameAction, Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            let screenSize = CGSize(
                width: max(0, geometry.size.width - safeAreaInsets.leading - safeAreaInsets.trailing),
                height: max(0, geometry.size.height - safeAreaInsets.top - safeAreaInsets.bottom)
            )
            let referenceSize = TouchLayoutMetrics.referenceCanvas(for: orientation)
            let canvasSize = scaledCanvasSize(screenSize: screenSize, referenceSize: referenceSize)
            let canvasOffset = CGPoint(
                x: safeAreaInsets.leading + (screenSize.width - canvasSize.width) / 2,
                y: safeAreaInsets.top + (screenSize.height - canvasSize.height) / 2
            )

            ZStack {
                ForEach(controls.filter(\.isEnabled).sorted { $0.zIndex < $1.zIndex }) { control in
                    controlView(for: control, canvasSize: canvasSize, canvasOffset: canvasOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    // Scale reference canvas to fit screen while maintaining aspect ratio
    private func scaledCanvasSize(screenSize: CGSize, referenceSize: CGSize) -> CGSize {
        guard screenSize.width > 0, screenSize.height > 0 else { return .zero }
        let screenAspect = screenSize.width / screenSize.height
        let referenceAspect = referenceSize.width / referenceSize.height

        if screenAspect > referenceAspect {
            // Screen is wider — fit to height
            let scale = screenSize.height / referenceSize.height
            return CGSize(width: referenceSize.width * scale, height: screenSize.height)
        } else {
            // Screen is narrower or equal — fit to width
            let scale = screenSize.width / referenceSize.width
            return CGSize(width: screenSize.width, height: referenceSize.height * scale)
        }
    }

    @ViewBuilder
    private func controlView(for control: TouchControlInstance, canvasSize: CGSize, canvasOffset: CGPoint) -> some View {
        let clampedControl = TouchLayoutMetrics.clamped(control, in: canvasSize)
        let frame = TouchLayoutMetrics.frame(for: clampedControl, in: canvasSize)
        let position = CGPoint(
            x: canvasOffset.x + frame.midX,
            y: canvasOffset.y + frame.midY
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
