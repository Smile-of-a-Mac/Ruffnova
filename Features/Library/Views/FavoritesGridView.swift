import SwiftUI

struct FavoritesGridView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
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

    private var columns: [GridItem] {
        #if os(iOS)
        [GridItem(.adaptive(minimum: 280, maximum: 320), spacing: NativeSpacing.xxxl)]
        #else
        [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: NativeSpacing.xxxl)]
        #endif
    }

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
                    LazyVGrid(columns: columns, spacing: NativeSpacing.xl) {
                        ForEach(favoriteItems) { item in
                            LibraryFileCell(file: item)
                        }
                    }
                    .padding(contentInsets)
                }
            }
        }
        .accessibilityLabel(locManager.localized("sidebar.favorites"))
    }
}
