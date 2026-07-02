import SwiftUI

struct LibraryItemDetailsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var libraryService = LibraryService.shared
    @ObservedObject private var collectionService = CollectionService.shared

    let itemID: UUID
    @State private var tagsText = ""
    @State private var notesText = ""

    var body: some View {
        Form {
            if let item = libraryService.item(with: itemID) {
                Section(locManager.localized("library.details.file")) {
                    LabeledContent(locManager.localized("diagnostics.report.fileName"), value: item.name)
                    LabeledContent(locManager.localized("diagnostics.report.path"), value: item.url.path)
                }

                Section(locManager.localized("library.details.organization")) {
                    Toggle(locManager.localized(item.isFavorite ? "favorites.remove" : "favorites.add"), isOn: favoriteBinding(item))
                    TextField(locManager.localized("library.details.tags.placeholder"), text: $tagsText)
                        .onSubmit { saveTags() }
                    TextEditor(text: $notesText)
                        .frame(minHeight: 96)
                        .accessibilityLabel(locManager.localized("library.details.notes"))
                }

                Section(locManager.localized("sidebar.collections")) {
                    if collectionService.collections.isEmpty {
                        Text(locManager.localized("collection.noCollections"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(collectionService.collections) { collection in
                            Toggle(collection.name, isOn: collectionBinding(itemID: item.id, collectionID: collection.id))
                        }
                    }
                }
            } else {
                Section {
                    Label(locManager.localized("library.details.missing"), systemImage: "questionmark.folder")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 420)
        .onAppear(perform: loadDraft)
        .onDisappear(perform: saveDraft)
    }

    private func favoriteBinding(_ item: LibraryItem) -> Binding<Bool> {
        Binding(
            get: { libraryService.item(with: item.id)?.isFavorite ?? item.isFavorite },
            set: { isFavorite in
                guard let current = libraryService.item(with: item.id) else { return }
                if current.isFavorite != isFavorite {
                    appState.toggleFavorite(for: current.url)
                }
            }
        )
    }

    private func collectionBinding(itemID: UUID, collectionID: UUID) -> Binding<Bool> {
        Binding(
            get: { collectionService.contains(itemID, in: collectionID) },
            set: { isIncluded in
                if isIncluded {
                    collectionService.add(itemID, to: collectionID)
                } else {
                    collectionService.remove(itemID, from: collectionID)
                }
            }
        )
    }

    private func loadDraft() {
        guard let item = libraryService.item(with: itemID) else { return }
        tagsText = item.tags.joined(separator: ", ")
        notesText = item.notes
    }

    private func saveDraft() {
        saveTags()
        saveNotes()
    }

    private func saveTags() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        let uniqueTags = tags.filter { seen.insert($0.lowercased()).inserted }
        libraryService.update(itemID) { $0.tags = uniqueTags }
    }

    private func saveNotes() {
        libraryService.update(itemID) { $0.notes = notesText.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
