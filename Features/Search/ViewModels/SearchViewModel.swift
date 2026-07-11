import Foundation
import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [LibraryItem] = []
    @Published var isSearching: Bool = false

    private let searchService: SearchService
    private let libraryService: LibraryService
    private let appState: AppState

    init(
        searchService: SearchService,
        libraryService: LibraryService,
        appState: AppState
    ) {
        self.searchService = searchService
        self.libraryService = libraryService
        self.appState = appState
    }

    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchResults = searchService.search(query: searchText)
    }

    func updateSearchText(_ text: String) {
        searchText = text
        performSearch()
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
        isSearching = false
    }

    func openResult(_ item: LibraryItem) {
        appState.clearSearch()
        appState.openFile(item.url)
    }

    func deleteResult(_ item: LibraryItem) {
        appState.removeLibraryItem(item.id)
        searchResults.removeAll { $0.id == item.id }
    }

    func toggleFavorite(_ item: LibraryItem) {
        appState.toggleFavorite(for: item.url)
        if let index = searchResults.firstIndex(where: { $0.id == item.id }) {
            searchResults[index].isFavorite = appState.bookmarkManager.contains(item.url)
        }
    }
}
