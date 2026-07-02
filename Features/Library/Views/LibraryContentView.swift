import SwiftUI

struct LibraryContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @Binding var isDropTargeted: Bool
    @State private var sortOrder = LibrarySortOrder.lastOpened
    @State private var filter = LibraryFilter.all

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
        case .settings:
            #if os(macOS)
            libraryView
            #else
            SettingsView()
                .environmentObject(appState)
                .environmentObject(locManager)
            #endif
        }
    }

    private var libraryView: some View {
        Group {
            if appState.libraryItems.isEmpty {
                EmptyStateView(isDropTargeted: $isDropTargeted)
            } else {
                LibraryGridView(
                    sortOrder: $sortOrder,
                    filter: $filter
                )
            }
        }
    }

    private var recentView: some View {
        Group {
            if appState.libraryItems.isEmpty {
                emptySection("clock", "library.noRecent", "library.noRecent.subtitle")
            } else {
                RecentListView()
            }
        }
    }

    private var favoritesView: some View {
        Group {
            if appState.libraryItems.filter({ $0.isFavorite }).isEmpty {
                emptySection("star", "library.noFavorites", "library.noFavorites.subtitle")
            } else {
                FavoritesGridView()
            }
        }
    }

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

struct LibraryGridView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @Binding var sortOrder: LibrarySortOrder
    @Binding var filter: LibraryFilter

    private var displayedItems: [LibraryItem] {
        let filtered = LibraryService.shared.filtered(by: filter)
        return LibraryService.shared.sorted(by: sortOrder)
            .filter { filter == .all || filtered.contains($0) }
    }

    private var columns: [GridItem] {
        #if os(iOS)
        [GridItem(.adaptive(minimum: 280, maximum: 320), spacing: NativeSpacing.xxxl)]
        #else
        [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: NativeSpacing.xxxl)]
        #endif
    }

    private var gridHorizontalPadding: CGFloat {
        #if os(iOS)
        NativeSpacing.xxxl
        #else
        NativeSpacing.section
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NativeSpacing.md) {
                Text(String(format: locManager.localized("library.fileCount"), displayedItems.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker(locManager.localized("library.sort"), selection: $sortOrder) {
                    ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                        Text(locManager.localized(order.localizedKey)).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Picker(locManager.localized("library.filter"), selection: $filter) {
                    ForEach(LibraryFilter.allCases, id: \.self) { f in
                        Text(locManager.localized(f.localizedKey)).tag(f)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
            }
            .padding(.horizontal, gridHorizontalPadding)
            .padding(.top, NativeSpacing.section)
            .padding(.bottom, NativeSpacing.md)

            if displayedItems.isEmpty {
                VStack(spacing: NativeSpacing.md) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.quaternary)
                    Text(locManager.localized("library.noFilterResults"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: NativeSpacing.xl) {
                        ForEach(displayedItems) { item in
                            LibraryFileCell(file: item)
                        }
                    }
                    .padding(.horizontal, gridHorizontalPadding)
                    .padding(.bottom, NativeSpacing.section)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
