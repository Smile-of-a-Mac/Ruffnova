import SwiftUI

struct SWFInfoPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @State private var metadata: (swfVersion: UInt8, playerVersion: UInt8, isAS3: Bool, frameRate: Float, movieWidth: UInt32, movieHeight: UInt32, totalFrames: UInt32)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(locManager.localized("swfInfo.title"))
                .font(.headline)

            Divider()

            if let meta = metadata {
                InfoRow(locManager.localized("swfInfo.file"), appState.currentFileURL?.lastPathComponent ?? "-")
                InfoRow(locManager.localized("swfInfo.dimensions"), "\(meta.movieWidth) \u{00d7} \(meta.movieHeight)")
                if meta.frameRate > 0 {
                    InfoRow(locManager.localized("swfInfo.frameRate"), String(format: "%.1f fps", meta.frameRate))
                }
                if meta.totalFrames > 0 {
                    InfoRow(locManager.localized("swfInfo.totalFrames"), "\(meta.totalFrames)")
                }
                if meta.swfVersion > 0 {
                    InfoRow(locManager.localized("swfInfo.swfVersion"), "\(meta.swfVersion)")
                    InfoRow(locManager.localized("swfInfo.actionScript"), meta.isAS3 ? "3.0 (AVM2)" : "1.0/2.0 (AVM1)")
                } else {
                    InfoRow(locManager.localized("swfInfo.swfVersion"), locManager.localized("swfInfo.unavailable"))
                }
                if meta.playerVersion > 0 {
                    InfoRow(locManager.localized("swfInfo.playerVersion"), "\(meta.playerVersion)")
                }
            } else {
                Text(locManager.localized("swfInfo.noSwf")).foregroundStyle(.secondary)
            }
        }
        .padding(NativeSpacing.xl)
        .frame(width: 280)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: .swfLoaded)) { _ in refresh() }
    }

    private func refresh() {
        metadata = appState.bridge?.getMetadata()
    }

    private func InfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).fontWeight(.medium)
            Spacer()
        }
        .font(.system(size: 12))
    }
}
