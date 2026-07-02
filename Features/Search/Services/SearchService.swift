import Foundation

@MainActor
final class SearchService {
    static let shared = SearchService(libraryService: LibraryService.shared, collectionService: CollectionService.shared)

    private let libraryService: LibraryService
    private let collectionService: CollectionService

    init(libraryService: LibraryService, collectionService: CollectionService) {
        self.libraryService = libraryService
        self.collectionService = collectionService
    }

    func search(query: String) -> [LibraryItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let normalizedQuery = query.lowercased()
        let items = libraryService.items

        return items.filter { item in
            matchesItem(item, query: normalizedQuery)
        }
    }

    private func matchesItem(_ item: LibraryItem, query: String) -> Bool {
        if item.name.localizedCaseInsensitiveContains(query) {
            return true
        }

        if item.url.path.localizedCaseInsensitiveContains(query) {
            return true
        }

        if item.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) {
            return true
        }

        if item.notes.localizedCaseInsensitiveContains(query) {
            return true
        }

        if collectionService.collections(containing: item.id).contains(where: { $0.name.localizedCaseInsensitiveContains(query) }) {
            return true
        }

        if item.isFavorite && "favorite".localizedCaseInsensitiveContains(query) {
            return true
        }

        if item.isFavorite && "favourite".localizedCaseInsensitiveContains(query) {
            return true
        }

        if item.availabilityStatus.rawValue.localizedCaseInsensitiveContains(query) {
            return true
        }

        if item.compatibilityStatus.rawValue.localizedCaseInsensitiveContains(query) {
            return true
        }

        if item.contentType?.rawValue.localizedCaseInsensitiveContains(query) == true {
            return true
        }

        return false
    }
}
