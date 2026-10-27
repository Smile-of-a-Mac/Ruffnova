import SwiftUI

struct LibraryFileCell: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var collectionService = CollectionService.shared
    let file: LibraryItem

    @State private var isHovered = false
    @State private var showingDetails = false
    @State private var thumbnail: CGImage?

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
        Task { await appState.relocateLibraryItem(file.id) }
    }

    private var thumbnailPreview: some View {
        ZStack {
            if file.availabilityStatus == .missing {
                missingThumbnail
            } else if let thumbnail {
                Image(decorative: thumbnail, scale: 1.0)
                    .resizable()
                    .aspectRatio(4 / 3, contentMode: .fill)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous))
            } else {
                placeholderThumbnail
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .task(id: file.thumbnailIdentifier) {
            guard file.availabilityStatus != .missing else { return }
            thumbnail = await ThumbnailService.shared.image(
                for: file.thumbnailIdentifier,
                fallbackData: file.thumbnailData
            )
        }
    }

    private var missingThumbnail: some View {
        RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
            .fill(GlassMaterial.heavy)
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.secondary)
            }
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
            .fill(GlassMaterial.light)
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                Image(systemName: "play.rectangle")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.tertiary)
            }
    }

    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xs) {
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
