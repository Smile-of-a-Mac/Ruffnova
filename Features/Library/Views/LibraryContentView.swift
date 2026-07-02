import SwiftUI

struct LibraryContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var libraryService = LibraryService.shared
    @ObservedObject private var collectionService = CollectionService.shared
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
            if let collectionID = appState.selectedCollectionID {
                LibraryGridView(
                    sortOrder: $sortOrder,
                    filter: $filter,
                    collectionID: collectionID
                )
            } else if libraryService.items.isEmpty {
                EmptyStateView(isDropTargeted: $isDropTargeted)
            } else {
                LibraryGridView(
                    sortOrder: $sortOrder,
                    filter: $filter,
                    collectionID: nil
                )
            }
        }
    }

    private var recentView: some View {
        Group {
            if libraryService.items.isEmpty {
                LibrarySectionEmptyState(icon: "clock", titleKey: "library.noRecent", subtitleKey: "library.noRecent.subtitle")
            } else {
                RecentListView()
            }
        }
    }

    private var favoritesView: some View {
        Group {
            if libraryService.items.filter({ $0.isFavorite }).isEmpty {
                LibrarySectionEmptyState(icon: "star", titleKey: "library.noFavorites", subtitleKey: "library.noFavorites.subtitle")
            } else {
                FavoritesGridView()
            }
        }
    }
}

struct LibrarySectionEmptyState: View {
    @EnvironmentObject var locManager: LocalizationManager
    let icon: String
    let titleKey: String
    let subtitleKey: String

    var body: some View {
        #if os(iOS)
        ContentUnavailableView(
            locManager.localized(titleKey),
            systemImage: icon,
            description: Text(locManager.localized(subtitleKey))
        )
        #else
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
        #endif
    }
}

struct LibraryGridView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var libraryService = LibraryService.shared
    @ObservedObject private var collectionService = CollectionService.shared
    @Binding var sortOrder: LibrarySortOrder
    @Binding var filter: LibraryFilter
    var collectionID: UUID?

    private var displayedItems: [LibraryItem] {
        if let collectionID {
            return collectionService.items(in: collectionID, from: libraryService.items)
        }
        return libraryService.items(matching: filter, sortedBy: sortOrder)
    }

    private var selectedCollection: LibraryCollection? {
        collectionService.collection(with: collectionID)
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
        content
        #if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    sortMenu
                    filterMenu
                }
            }
        #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NativeSpacing.md) {
                VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                    if let selectedCollection {
                        Text(selectedCollection.name)
                            .font(.headline)
                    }
                    Text(String(format: locManager.localized("library.fileCount"), displayedItems.count))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if collectionID == nil {
                    #if !os(iOS)
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
                    #endif
                }
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
                    Text(locManager.localized(collectionID == nil ? "library.noFilterResults" : "library.emptyCollection"))
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

    #if os(iOS)
    private var sortMenu: some View {
        Menu {
            Picker(locManager.localized("library.sort"), selection: $sortOrder) {
                ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                    Text(locManager.localized(order.localizedKey)).tag(order)
                }
            }
        } label: {
            Label(locManager.localized("library.sort"), systemImage: "arrow.up.arrow.down")
        }
        .accessibilityLabel(locManager.localized("library.sort"))
    }

    private var filterMenu: some View {
        Menu {
            Picker(locManager.localized("library.filter"), selection: $filter) {
                ForEach(LibraryFilter.allCases, id: \.self) { f in
                    Text(locManager.localized(f.localizedKey)).tag(f)
                }
            }
        } label: {
            Label(locManager.localized("library.filter"), systemImage: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(locManager.localized("library.filter"))
    }
    #endif
}
