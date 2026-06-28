// RecentListView — Lightweight list for recently opened SWF files.
// Rows breathe. Scrolling feels effortless.

import SwiftUI

struct RecentListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
                VStack(alignment: .leading, spacing: NativeSpacing.sm) {
                    Text(locManager.localized("sidebar.recent"))
                        .font(.largeTitle)
                    Text(locManager.localized("workspace.recent.subtitle"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

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
