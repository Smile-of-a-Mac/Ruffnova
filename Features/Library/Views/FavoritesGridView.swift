import SwiftUI
import UniformTypeIdentifiers

struct FavoritesGridView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    private var favoriteItems: [LibraryItem] {
        LibraryService.shared.filtered(by: .favorites)
    }

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: NativeSpacing.xxxl)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
                LazyVGrid(columns: columns, spacing: NativeSpacing.xl) {
                    ForEach(favoriteItems) { item in
                        Button { appState.openFile(item.url) } label: {
                            VStack(alignment: .leading, spacing: NativeSpacing.md) {
                                ZStack {
                                    if item.availabilityStatus == .missing {
                                        RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
                                            .fill(GlassMaterial.heavy)
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 28, weight: .light))
                                            .foregroundStyle(.tertiary)
                                    } else {
                                        RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
                                            .fill(GlassMaterial.ultraLight)
                                        Image(systemName: "star")
                                            .font(.system(size: 28, weight: .light))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .frame(height: 112)

                                Text(item.name)
                                    .font(.callout)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.name)
                        .contextMenu {
                            Button(locManager.localized("favorites.remove")) {
                                appState.toggleFavorite(for: item.url)
                            }
                            if item.availabilityStatus == .missing {
                                Button(locManager.localized("library.locateFile")) {
                                    locateFile(item)
                                }
                                Button(locManager.localized("library.remove")) {
                                    LibraryService.shared.remove(item.id)
                                }
                            }
                        }
                    }
                }
            }
            .padding(NativeSpacing.section)
        }
        .accessibilityLabel(locManager.localized("sidebar.favorites"))
    }

    private func locateFile(_ item: LibraryItem) {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "swf")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.message = locManager.localized("library.locateFile.message")
        if panel.runModal() == .OK, let url = panel.url {
            LibraryService.shared.locateFile(for: item.id, newURL: url)
        }
        #endif
    }
}
