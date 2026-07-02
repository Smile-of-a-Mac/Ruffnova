import SwiftUI

struct RecentListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var libraryService = LibraryService.shared

    private var recentItems: [LibraryItem] {
        libraryService.sorted(by: .lastOpened)
            .filter { $0.availabilityStatus == .available }
            .prefix(20).map { $0 }
    }

    var body: some View {
        Group {
            if recentItems.isEmpty {
                LibrarySectionEmptyState(
                    icon: "clock",
                    titleKey: "library.noRecent",
                    subtitleKey: "library.noRecent.subtitle"
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
                        LazyVStack(spacing: NativeSpacing.sm) {
                            ForEach(recentItems) { item in
                                RecentFileRow(file: item)
                            }
                        }
                    }
                    .padding(NativeSpacing.section)
                }
            }
        }
        .accessibilityLabel(locManager.localized("workspace.recentFiles"))
    }
}
