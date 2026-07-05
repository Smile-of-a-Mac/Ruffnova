import SwiftUI

struct LibraryContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var libraryService = LibraryService.shared
    @ObservedObject private var collectionService = CollectionService.shared
    @Binding var isDropTargeted: Bool
    var onShowCollections: (() -> Void)?
    @State private var sortOrder = LibrarySortOrder.lastOpened
    @State private var filter = LibraryFilter.all

    var body: some View {
        content
        #if os(iOS)
        .toolbar {
            if appState.selectedSection == .library {
                ToolbarItem(placement: .primaryAction) {
                    libraryActionsMenu
                }
            }
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
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
            SettingsView(settingsActions: SettingsActions(appState: appState))
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

    #if os(iOS)
    private var libraryActionsMenu: some View {
        Menu {
            Section(locManager.localized("library.menu.actions")) {
                if let onShowCollections {
                    Button {
                        onShowCollections()
                    } label: {
                        Label(locManager.localized("sidebar.collections"), systemImage: "folder")
                    }
                }

                Button {
                    AppCommandRouter.openFile(appState: appState, loc: locManager)
                } label: {
                    Label(locManager.localized("toolbar.openSwf"), systemImage: "doc")
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            Section(locManager.localized("library.menu.sortBy")) {
                Picker(locManager.localized("library.sort"), selection: $sortOrder) {
                    ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                        Text(locManager.localized(order.localizedKey)).tag(order)
                    }
                }
            }

            Section(locManager.localized("library.menu.filterBy")) {
                Picker(locManager.localized("library.filter"), selection: $filter) {
                    ForEach(LibraryFilter.allCases, id: \.self) { f in
                        Text(locManager.localized(f.localizedKey)).tag(f)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(locManager.localized("toolbar.importHelp"))
    }
    #endif
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
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []

    private var displayedItems: [LibraryItem] {
        if let collectionID {
            return collectionService.items(in: collectionID, from: libraryService.items)
        }
        return libraryService.items(matching: filter, sortedBy: sortOrder)
    }

    private var selectedCollection: LibraryCollection? {
        collectionService.collection(with: collectionID)
    }

    private var selectedItems: [LibraryItem] {
        displayedItems.filter { selectedIDs.contains($0.id) }
    }

    private var selectedCountText: String {
        String(format: locManager.localized("library.selection.count"), selectedIDs.count)
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

    private var gridTopPadding: CGFloat {
        #if os(iOS)
        NativeSpacing.md
        #else
        NativeSpacing.section
        #endif
    }

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        #if os(iOS)
        scrollContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isSelecting {
                    iOSSelectionBar
                }
            }
        #else
        scrollContent
        #endif
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: NativeSpacing.md) {
                    VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                        if let selectedCollection {
                            Text(selectedCollection.name)
                                .font(.headline)
                        }
                        Text(isSelecting ? selectedCountText : String(format: locManager.localized("library.fileCount"), displayedItems.count))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    #if os(iOS)
                    if !isSelecting, collectionID == nil {
                        EmptyView()
                    }
                    #else
                    if isSelecting {
                        selectionActions
                    } else if collectionID == nil {
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
                    #endif

                    Button(locManager.localized(isSelecting ? "library.selection.done" : "library.selection.select")) {
                        withAnimation(.glassSmooth) {
                            isSelecting.toggle()
                            if !isSelecting {
                                selectedIDs.removeAll()
                            }
                        }
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, gridHorizontalPadding)
                .padding(.top, gridTopPadding)
                .padding(.bottom, NativeSpacing.md)

                if displayedItems.isEmpty {
                    VStack(spacing: NativeSpacing.md) {
                        Image(systemName: "tray")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.quaternary)
                        Text(locManager.localized(collectionID == nil ? "library.noFilterResults" : "library.emptyCollection"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVGrid(columns: columns, spacing: NativeSpacing.xl) {
                        ForEach(displayedItems) { item in
                            selectableLibraryCell(item)
                        }
                    }
                    .padding(.horizontal, gridHorizontalPadding)
                    .padding(.bottom, NativeSpacing.section)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: displayedItems.map(\.id)) {
            syncSelection(with: displayedItems.map(\.id))
        }
    }

    private func syncSelection(with ids: [LibraryItem.ID]) {
        selectedIDs.formIntersection(Set(ids))
        if ids.isEmpty {
            isSelecting = false
        }
    }

    #if os(iOS)
    private var iOSSelectionBar: some View {
        VStack(spacing: NativeSpacing.sm) {
            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NativeSpacing.sm) {
                Button {
                    selectedIDs = Set(displayedItems.map(\.id))
                } label: {
                    Label(locManager.localized("systemMenu.selectAll"), systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(displayedItems.isEmpty || selectedIDs.count == displayedItems.count)

                Button {
                    setSelectedFavorites(true)
                } label: {
                    Label(locManager.localized("library.selection.favorite"), systemImage: "star")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedIDs.isEmpty)

                Button {
                    setSelectedFavorites(false)
                } label: {
                    Label(locManager.localized("library.selection.unfavorite"), systemImage: "star.slash")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedIDs.isEmpty)

                Button(role: .destructive) {
                    removeSelectedItems()
                } label: {
                    Label(locManager.localized("systemMenu.delete"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedIDs.isEmpty)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
            .padding(.horizontal, NativeSpacing.md)
            .padding(.bottom, NativeSpacing.sm)
        }
        .background(GlassMaterial.light)
    }
    #endif

    private var selectionActions: some View {
        HStack(spacing: NativeSpacing.sm) {
            Button(locManager.localized("systemMenu.selectAll")) {
                selectedIDs = Set(displayedItems.map(\.id))
            }
            .disabled(displayedItems.isEmpty || selectedIDs.count == displayedItems.count)

            Button {
                setSelectedFavorites(true)
            } label: {
                Label(locManager.localized("favorites.add"), systemImage: "star")
            }
            .disabled(selectedIDs.isEmpty)

            Button {
                setSelectedFavorites(false)
            } label: {
                Label(locManager.localized("favorites.remove"), systemImage: "star.slash")
            }
            .disabled(selectedIDs.isEmpty)

            Button(role: .destructive) {
                removeSelectedItems()
            } label: {
                Label(locManager.localized("systemMenu.delete"), systemImage: "trash")
            }
            .disabled(selectedIDs.isEmpty)
        }
        .controlSize(.small)
    }

    private func selectableLibraryCell(_ item: LibraryItem) -> some View {
        ZStack(alignment: .topTrailing) {
            LibraryFileCell(file: item)
                .allowsHitTesting(!isSelecting)

            if isSelecting {
                Button {
                    toggleSelection(for: item.id)
                } label: {
                    ZStack {
                        Circle()
                            .fill(selectedIDs.contains(item.id) ? Color.accentColor : Color.secondary.opacity(0.18))
                        Circle()
                            .strokeBorder(.white.opacity(0.72), lineWidth: 1)
                        if selectedIDs.contains(item.id) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .padding(NativeSpacing.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.name)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelecting {
                toggleSelection(for: item.id)
            }
        }
        .contextMenu {
            if !isSelecting {
                Button(locManager.localized("library.selection.select")) {
                    isSelecting = true
                    selectedIDs = [item.id]
                }
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func setSelectedFavorites(_ favorite: Bool) {
        for item in selectedItems where item.isFavorite != favorite {
            appState.toggleFavorite(for: item.url)
        }
    }

    private func removeSelectedItems() {
        let ids = selectedIDs
        for id in ids {
            libraryService.remove(id)
        }
        selectedIDs.removeAll()
        isSelecting = false
    }
}
