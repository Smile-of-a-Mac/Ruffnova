import SwiftUI

struct RecentListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    private var recentItems: [LibraryItem] {
        LibraryService.shared.sorted(by: .lastOpened)
            .filter { $0.availabilityStatus == .available }
            .prefix(20).map { $0 }
    }

    var body: some View {
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
        .accessibilityLabel(locManager.localized("workspace.recentFiles"))
    }
}
