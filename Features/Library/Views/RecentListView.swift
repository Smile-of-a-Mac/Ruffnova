// RecentListView — Lightweight list for recently opened SWF files.
// Rows breathe. Scrolling feels effortless.

import SwiftUI

struct RecentListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
                LazyVStack(spacing: NativeSpacing.sm) {
                    ForEach(appState.recentFiles) { file in
                        RecentFileRow(file: file)
                    }
                }
            }
            .padding(NativeSpacing.section)
        }
        .accessibilityLabel(locManager.localized("workspace.recentFiles"))
    }
}
