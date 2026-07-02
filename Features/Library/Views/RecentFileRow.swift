import SwiftUI

struct RecentFileRow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var libraryService = LibraryService.shared
    let file: LibraryItem

    var body: some View {
        Button { appState.openFile(file.url) } label: {
            HStack(spacing: NativeSpacing.md) {
                Image(systemName: "play.rectangle")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, height: 36)
                    .modifier(LiquidGlassModifier(shape: Circle(), material: GlassMaterial.ultraLight))
                VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                    Text(file.name)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(file.lastOpened, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if file.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, NativeSpacing.sm)
            .padding(.horizontal, NativeSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(file.name)
        .contextMenu {
            Button(locManager.localized("library.removeFromRecent")) {
                libraryService.remove(file.id)
            }
        }
    }
}
