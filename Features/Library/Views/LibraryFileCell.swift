import SwiftUI

struct LibraryFileCell: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    let file: RecentFile

    @State private var isHovered = false

    var body: some View {
        Button { appState.openFile(file.url) } label: {
            VStack(alignment: .leading, spacing: NativeSpacing.md) {
                thumbnailPreview
                fileInfo
            }
            .padding(NativeSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(isHovered ? 1.025 : 1.0)
            .brightness(isHovered ? 0.06 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.glassSpring) {
                isHovered = hovering
            }
        }
        .help(file.name)
        .accessibilityLabel(file.name)
        .accessibilityValue(file.lastOpened.formatted())
        .contextMenu {
            Button(locManager.localized("menu.open")) { appState.openFile(file.url) }
            #if os(macOS)
            Divider()
            Button(locManager.localized("menu.showInFinder")) {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
            #endif
            Divider()
            Button(locManager.localized("library.removeFromRecent")) {
                appState.removeFromRecentlyOpened(file)
            }
        }
    }

    private var thumbnailPreview: some View {
        ZStack {
            if let data = file.thumbnailData, let cgImage = thumbnailCGImage(from: data) {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(4 / 3, contentMode: .fill)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
                    .fill(GlassMaterial.light)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay {
                        RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
                            .strokeBorder(.quaternary.opacity(0.55), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)

                Image(systemName: "play.rectangle")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
    }

    private func thumbnailCGImage(from data: Data) -> CGImage? {
        #if os(macOS)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return cgImage
        #else
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return cgImage
        #endif
    }

    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(file.name)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: NativeSpacing.xs) {
                Text(file.lastOpened, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if file.fileSize > 0 {
                    Text("\u{00B7}")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
