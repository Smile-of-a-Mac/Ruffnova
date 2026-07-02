import Foundation
import OSLog

@MainActor
final class CollectionService: ObservableObject {
    static let shared = CollectionService()

    @Published private(set) var collections: [LibraryCollection] = []

    private let storageURL: URL
    private let schemaVersion = 1
    private let logger = Logger(subsystem: "com.ruffnova", category: "collections")

    convenience init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("RuffleFlashPlayer")
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.init(storageURL: directory.appendingPathComponent("collections.json"))
    }

    init(storageURL: URL) {
        self.storageURL = storageURL
        load()
    }

    @discardableResult
    func create(name: String) -> LibraryCollection? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let collection = LibraryCollection(name: trimmedName)
        collections.append(collection)
        save()
        return collection
    }

    func rename(_ id: UUID, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = collections.firstIndex(where: { $0.id == id })
        else { return }

        objectWillChange.send()
        collections[index].name = trimmedName
        collections[index].updatedAt = Date()
        save()
    }

    func delete(_ id: UUID) {
        collections.removeAll { $0.id == id }
        save()
    }

    func collection(with id: UUID?) -> LibraryCollection? {
        guard let id else { return nil }
        return collections.first { $0.id == id }
    }

    func contains(_ itemID: UUID, in collectionID: UUID) -> Bool {
        collection(with: collectionID)?.itemIDs.contains(itemID) == true
    }

    func add(_ itemID: UUID, to collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }),
              !collections[index].itemIDs.contains(itemID)
        else { return }

        objectWillChange.send()
        collections[index].itemIDs.append(itemID)
        collections[index].updatedAt = Date()
        save()
    }

    func remove(_ itemID: UUID, from collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        objectWillChange.send()
        collections[index].itemIDs.removeAll { $0 == itemID }
        collections[index].updatedAt = Date()
        save()
    }

    func toggle(_ itemID: UUID, in collectionID: UUID) {
        if contains(itemID, in: collectionID) {
            remove(itemID, from: collectionID)
        } else {
            add(itemID, to: collectionID)
        }
    }

    func removeItemFromAllCollections(_ itemID: UUID) {
        var didChange = false
        objectWillChange.send()
        for index in collections.indices where collections[index].itemIDs.contains(itemID) {
            collections[index].itemIDs.removeAll { $0 == itemID }
            collections[index].updatedAt = Date()
            didChange = true
        }
        if didChange { save() }
    }

    func collections(containing itemID: UUID) -> [LibraryCollection] {
        collections.filter { $0.itemIDs.contains(itemID) }
    }

    func items(in collectionID: UUID, from libraryItems: [LibraryItem]) -> [LibraryItem] {
        guard let collection = collection(with: collectionID) else { return [] }
        let itemIDs = Set(collection.itemIDs)
        return sort(libraryItems.filter { itemIDs.contains($0.id) }, using: collection.sortSettings)
    }

    private func sort(_ items: [LibraryItem], using settings: LibraryCollectionSortSettings) -> [LibraryItem] {
        let sorted: [LibraryItem]
        switch settings.order {
        case .name:
            sorted = items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .lastOpened:
            sorted = items.sorted { $0.lastOpened > $1.lastOpened }
        case .dateAdded:
            sorted = items.sorted { $0.dateAdded > $1.dateAdded }
        case .fileSize:
            sorted = items.sorted { $0.fileSize > $1.fileSize }
        }
        return settings.ascending ? sorted : sorted.reversed()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        do {
            let store = try JSONDecoder().decode(CollectionStore.self, from: data)
            collections = store.collections
        } catch {
            logger.error("Failed to load collections: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(CollectionStore(schemaVersion: schemaVersion, collections: collections))
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save collections: \(error.localizedDescription)")
        }
    }
}

private struct CollectionStore: Codable {
    var schemaVersion: Int
    var collections: [LibraryCollection]
}
