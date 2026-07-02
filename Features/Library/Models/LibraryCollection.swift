import Foundation

struct LibraryCollection: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var itemIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
    var sortSettings: LibraryCollectionSortSettings

    init(
        id: UUID = UUID(),
        name: String,
        itemIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortSettings: LibraryCollectionSortSettings = LibraryCollectionSortSettings()
    ) {
        self.id = id
        self.name = name
        self.itemIDs = itemIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortSettings = sortSettings
    }
}

struct LibraryCollectionSortSettings: Codable, Equatable {
    var order: LibrarySortOrder
    var ascending: Bool

    init(order: LibrarySortOrder = .name, ascending: Bool = true) {
        self.order = order
        self.ascending = ascending
    }
}
