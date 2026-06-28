// LibraryContentView — Content browser.
// Content floats above window glass.
// Uses native typography and materials for hierarchy.

import SwiftUI

struct LibraryContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @Binding var isDropTargeted: Bool

    var body: some View {
        switch appState.selectedSection {
        case .player:
            EmptyView()
        case .library:
            libraryView
        case .recent:
            recentView
        case .favorites:
            favoritesView
        case .collections:
            collectionsView
        case .downloads:
            emptySection("square.and.arrow.down", "sidebar.downloads", "library.noDownloads.subtitle")
        case .settings:
            SettingsView()
                .environmentObject(appState)
                .environmentObject(locManager)
        }
    }

    // MARK: - Library View

    private var libraryView: some View {
        Group {
            if appState.recentFiles.isEmpty {
                EmptyStateView(isDropTargeted: $isDropTargeted)
            } else {
                LibraryGridView()
            }
        }
    }

    // MARK: - Recent View

    private var recentView: some View {
        Group {
            if appState.recentFiles.isEmpty {
                emptySection("clock", "library.noRecent", "library.noRecent.subtitle")
            } else {
                RecentListView()
            }
        }
    }

    // MARK: - Favorites View

    private var favoritesView: some View {
        Group {
            if appState.bookmarks.isEmpty {
                emptySection("star", "library.noFavorites", "library.noFavorites.subtitle")
            } else {
                FavoritesGridView()
            }
        }
    }

    // MARK: - Collections View

    private var collectionsView: some View {
        Group {
            if appState.collections.isEmpty {
                emptySection("folder", "library.noCollections", "library.noCollections.subtitle")
            } else {
                CollectionsListView()
            }
        }
    }

    // MARK: - Empty Section

    private func emptySection(_ icon: String, _ titleKey: String, _ subtitleKey: String) -> some View {
        VStack(spacing: NativeSpacing.xxl) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.quaternary)
            VStack(spacing: NativeSpacing.sm) {
                Text(locManager.localized(titleKey))
                    .font(.title)
                Text(locManager.localized(subtitleKey))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Library Grid View

struct LibraryGridView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: NativeSpacing.xxxl)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
                VStack(alignment: .leading, spacing: NativeSpacing.sm) {
                    Text(locManager.localized("library.title"))
                        .font(.largeTitle)
                    Text(String(format: locManager.localized("library.fileCount"), appState.recentFiles.count))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, NativeSpacing.section)
                .padding(.top, NativeSpacing.section)

                LazyVGrid(columns: columns, spacing: NativeSpacing.xl) {
                    ForEach(appState.recentFiles) { file in
                        LibraryFileCell(file: file)
                    }
                }
                .padding(.horizontal, NativeSpacing.section)
                .padding(.bottom, NativeSpacing.section)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Library") {
    LibraryContentView(isDropTargeted: .constant(false))
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
        .frame(width: 600, height: 500)
}
