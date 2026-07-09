import SwiftUI
import UniformTypeIdentifiers

struct FavoritesGridView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var libraryService = LibraryService.shared

    private var favoriteItems: [LibraryItem] {
        libraryService.filtered(by: .favorites)
            .matchingSearchText(appState.searchText)
    }

    private var contentInsets: EdgeInsets {
        #if os(iOS)
        EdgeInsets(top: NativeSpacing.md, leading: NativeSpacing.section, bottom: NativeSpacing.section, trailing: NativeSpacing.section)
        #else
        EdgeInsets(top: NativeSpacing.section, leading: NativeSpacing.section, bottom: NativeSpacing.section, trailing: NativeSpacing.section)
        #endif
    }

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: NativeSpacing.xxxl)]

    var body: some View {
        Group {
            if favoriteItems.isEmpty {
                LibrarySectionEmptyState(
                    icon: "star",
                    titleKey: "library.noFavorites",
                    subtitleKey: "library.noFavorites.subtitle"
                )
            } else {
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
                                            libraryService.remove(item.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(contentInsets)
                }
            }
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
            libraryService.locateFile(for: item.id, newURL: url)
        }
        #endif
    }
}
