import SwiftUI
import UniformTypeIdentifiers

struct LibraryFileCell: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var libraryService = LibraryService.shared
    @ObservedObject private var collectionService = CollectionService.shared
    private let thumbnailService = ThumbnailService.shared
    let file: LibraryItem

    @State private var isHovered = false
    @State private var showingDetails = false

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
                    appState.removeLibraryItem(file.id)
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
            if !collectionService.collections.isEmpty {
                Menu(locManager.localized("collection.add")) {
                    ForEach(collectionService.collections) { collection in
                        Button(collectionMenuTitle(collection)) {
                            collectionService.toggle(file.id, in: collection.id)
                        }
                    }
                }
            }
            Button(locManager.localized("library.details.edit")) {
                showingDetails = true
            }
            Divider()
            Button(locManager.localized("library.remove")) {
                appState.removeLibraryItem(file.id)
            }
        }
        .sheet(isPresented: $showingDetails) {
            LibraryItemDetailsView(itemID: file.id)
                .environmentObject(appState)
                .environmentObject(locManager)
        }
    }

    private func collectionMenuTitle(_ collection: LibraryCollection) -> String {
        let marker = collectionService.contains(file.id, in: collection.id) ? "[x] " : ""
        return marker + collection.name
    }

    private func locateFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "swf")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.message = locManager.localized("library.locateFile.message")
        if panel.runModal() == .OK, let url = panel.url {
            libraryService.locateFile(for: file.id, newURL: url)
        }
        #elseif os(iOS)
        appState.locateLibraryItem(file.id)
        #endif
    }

    private var thumbnailPreview: some View {
        ZStack {
            if file.availabilityStatus == .missing {
                missingThumbnail
            } else if let data = thumbnailData, let cgImage = thumbnailCGImage(from: data) {
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

    private var thumbnailData: Data? {
        thumbnailService.data(for: file.thumbnailIdentifier) ?? file.thumbnailData
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

            if let metadataText {
                Text(metadataText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if !file.tags.isEmpty {
                Text(file.tags.prefix(3).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataText: String? {
        guard let metadata = file.metadata else { return nil }
        var parts: [String] = []
        if metadata.hasStageSize {
            parts.append("\(metadata.stageWidth) \u{00d7} \(metadata.stageHeight)")
        }
        if metadata.hasFrameRate {
            parts.append(String(format: locManager.localized("metadata.fps"), metadata.frameRate))
        }
        if metadata.hasTotalFrames {
            parts.append(String(format: locManager.localized("metadata.frames"), Int64(metadata.totalFrames)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }
}
