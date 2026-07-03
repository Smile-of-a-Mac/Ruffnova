import SwiftUI

struct SidebarCollectionsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var collectionService = CollectionService.shared
    var onSelectCollection: (LibraryCollection) -> Void = { _ in }

    @State private var showingNewCollectionAlert = false
    @State private var collectionNameDraft = ""
    @State private var renamingCollection: LibraryCollection?

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xs) {
            header
            collectionList
        }
        .alert(locManager.localized("collection.new"), isPresented: $showingNewCollectionAlert) {
            TextField(locManager.localized("collection.name.placeholder"), text: $collectionNameDraft)
            Button(locManager.localized("collection.create"), action: createCollection)
            Button(locManager.localized("collection.cancel"), role: .cancel, action: clearDraft)
        }
        .alert(locManager.localized("collection.rename"), isPresented: renameAlertBinding) {
            TextField(locManager.localized("collection.name.placeholder"), text: $collectionNameDraft)
            Button(locManager.localized("collection.rename"), action: renameCollection)
            Button(locManager.localized("collection.cancel"), role: .cancel, action: clearDraft)
        }
    }

    private var header: some View {
        HStack(spacing: NativeSpacing.sm) {
            Text(locManager.localized("sidebar.collections"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()

            Button {
                clearDraft()
                showingNewCollectionAlert = true
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(locManager.localized("collection.new"))
        }
        .padding(.horizontal, NativeSpacing.md)
        .padding(.top, NativeSpacing.md)
    }

    @ViewBuilder
    private var collectionList: some View {
        if collectionService.collections.isEmpty {
            Text(locManager.localized("collection.noCollections"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, NativeSpacing.md)
                .padding(.vertical, NativeSpacing.xs)
        } else {
            ForEach(collectionService.collections) { collection in
                collectionButton(collection)
            }
        }
    }

    private func collectionButton(_ collection: LibraryCollection) -> some View {
        Button {
            withAnimation(.default) {
                appState.selectCollection(collection.id)
            }
            onSelectCollection(collection)
        } label: {
            HStack(spacing: NativeSpacing.md) {
                Image(systemName: "folder")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isSelected(collection) ? Color.accentColor : Color.secondary)
                    .frame(width: 22)

                Text(collection.name)
                    .font(.headline)
                    .foregroundStyle(isSelected(collection) ? .primary : .secondary)
                    .lineLimit(1)

                Spacer()

                Text("\(collection.itemIDs.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, NativeSpacing.sm)
                    .padding(.vertical, 2)
            }
            .padding(.horizontal, NativeSpacing.md)
            .padding(.vertical, NativeSpacing.sm)
            .contentShape(Capsule())
            .background {
                if isSelected(collection) {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(locManager.localized("collection.rename")) {
                collectionNameDraft = collection.name
                renamingCollection = collection
            }
            Button(locManager.localized("collection.delete"), role: .destructive) {
                deleteCollection(collection)
            }
        }
        .accessibilityLabel(collection.name)
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingCollection != nil },
            set: { isPresented in
                if !isPresented { clearDraft() }
            }
        )
    }

    private func createCollection() {
        if let collection = collectionService.create(name: collectionNameDraft) {
            appState.selectCollection(collection.id)
            onSelectCollection(collection)
        }
        clearDraft()
    }

    private func renameCollection() {
        if let renamingCollection {
            collectionService.rename(renamingCollection.id, to: collectionNameDraft)
        }
        clearDraft()
    }

    private func deleteCollection(_ collection: LibraryCollection) {
        collectionService.delete(collection.id)
        if appState.selectedCollectionID == collection.id {
            appState.selectSection(.library)
        }
    }

    private func clearDraft() {
        renamingCollection = nil
        collectionNameDraft = ""
    }

    private func isSelected(_ collection: LibraryCollection) -> Bool {
        appState.selectedCollectionID == collection.id
    }
}
