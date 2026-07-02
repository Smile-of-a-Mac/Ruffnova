import SwiftUI
import UniformTypeIdentifiers

struct LibraryFileCell: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    let file: LibraryItem

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
            if file.availabilityStatus == .missing {
                Button(locManager.localized("library.locateFile")) {
                    locateFile()
                }
                Button(locManager.localized("library.remove")) {
                    LibraryService.shared.remove(file.id)
                }
                Divider()
            } else {
                Button(locManager.localized("menu.open")) { appState.openFile(file.url) }
                #if os(macOS)
                Divider()
                Button(locManager.localized("menu.showInFinder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                }
                #endif
            }
            Divider()
            if file.isFavorite {
                Button(locManager.localized("favorites.remove")) {
                    appState.toggleFavorite(for: file.url)
                }
            } else {
                Button(locManager.localized("favorites.add")) {
                    appState.toggleFavorite(for: file.url)
                }
            }
            Divider()
            Button(locManager.localized("library.remove")) {
                LibraryService.shared.remove(file.id)
            }
        }
    }

    private func locateFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "swf")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.message = locManager.localized("library.locateFile.message")
        if panel.runModal() == .OK, let url = panel.url {
            LibraryService.shared.locateFile(for: file.id, newURL: url)
        }
        #endif
    }

    private var thumbnailPreview: some View {
        ZStack {
            if file.availabilityStatus == .missing {
                missingThumbnail
            } else if let data = file.thumbnailData, let cgImage = thumbnailCGImage(from: data) {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(4 / 3, contentMode: .fill)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous))
            } else {
                placeholderThumbnail
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
    }

    private var missingThumbnail: some View {
        RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
            .fill(GlassMaterial.heavy)
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
                    .strokeBorder(.red.opacity(0.3), lineWidth: 0.5)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.tertiary)
            }
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
            .fill(GlassMaterial.light)
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
                    .strokeBorder(.quaternary.opacity(0.55), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
            .overlay {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
            }
    }

    private func thumbnailCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return cgImage
    }

    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: NativeSpacing.xs) {
                Text(file.name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if file.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
                if file.availabilityStatus == .missing {
                    Text(locManager.localized("library.missing"))
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

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
