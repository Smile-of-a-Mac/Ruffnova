import SwiftUI

struct DebugOverlayView: View {
    @EnvironmentObject private var playback: PlaybackMetrics
    @EnvironmentObject private var locManager: LocalizationManager

    var body: some View {
        VStack(alignment: .trailing, spacing: NativeSpacing.xs) {
            Text(String(format: locManager.localized("debug.fps"),
                       playback.frameRate,
                       playback.currentFrame))
            Text(locManager.localized("debug.render.placeholder"))
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.green)
        .padding(NativeSpacing.sm)
        .background(
            GlassMaterial.ultraLight,
            in: RoundedRectangle(cornerRadius: NativeRadius.sm, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(locManager.localized("debug.overlay.label"))
    }
}

#Preview("Debug Overlay") {
    let appState = AppState()
    DebugOverlayView()
        .environmentObject(appState.playback)
        .environmentObject(LocalizationManager.shared)
        .padding()
}
