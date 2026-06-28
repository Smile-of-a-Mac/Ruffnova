import SwiftUI

struct DebugOverlayView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: locManager.localized("debug.fps"),
                       appState.frameRate,
                       appState.currentFrame))
            Text(locManager.localized("debug.render.placeholder"))
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.green)
        .padding(10)
        .background(GlassMaterial.ultraLight, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(locManager.localized("debug.overlay.label"))
    }
}
