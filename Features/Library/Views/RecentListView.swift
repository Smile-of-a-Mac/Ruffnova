import SwiftUI

struct RecentListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var libraryService = LibraryService.shared

    private var recentItems: [LibraryItem] {
        libraryService.sorted(by: .lastOpened)
            .filter { $0.availabilityStatus == .available }
            .prefix(20).map { $0 }
            .matchingSearchText(appState.searchText)
    }

    private var contentInsets: EdgeInsets {
        #if os(iOS)
        EdgeInsets(top: NativeSpacing.md, leading: NativeSpacing.section, bottom: NativeSpacing.section, trailing: NativeSpacing.section)
        #else
        EdgeInsets(top: NativeSpacing.section, leading: NativeSpacing.section, bottom: NativeSpacing.section, trailing: NativeSpacing.section)
        #endif
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
                    .padding(contentInsets)
                }
            }
        }
        .accessibilityLabel(locManager.localized("workspace.recentFiles"))
    }
}
