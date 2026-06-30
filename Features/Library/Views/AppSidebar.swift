// AppSidebar — Sidebar blends into the window glass.
// NavigationSplitView handles glass separation automatically.
// No decorative elements — pure navigation structure.

import SwiftUI

struct AppSidebar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @FocusState private var searchFocused: Bool

    private let primarySections: [AppState.Section] = [.player, .library, .recent, .favorites]

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xl) {
            searchField

            VStack(spacing: NativeSpacing.xs) {
                ForEach(primarySections, id: \.self) { section in
                    sidebarButton(for: section)
                }
            }

            Spacer()
        }
        .padding(.top, NativeSpacing.section + NativeSpacing.md)
        .padding(.horizontal, NativeSpacing.lg)
        .padding(.bottom, NativeSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }

    private var searchField: some View {
        HStack(spacing: NativeSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(searchFocused ? .primary : .secondary)

            TextField(locManager.localized("search.placeholder"), text: $appState.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { appState.isSearching = true }
                .onChange(of: appState.searchText) { newValue in
                    appState.isSearching = !newValue.isEmpty
                }

            if !appState.searchText.isEmpty {
                Button {
                    appState.searchText = ""
                    appState.isSearching = false
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, NativeSpacing.md)
        .padding(.vertical, NativeSpacing.sm)
        .toolbarGlassCapsule(material: GlassMaterial.light)
        .accessibilityLabel(locManager.localized("toolbar.searchLibrary"))
    }

    private func sidebarButton(for section: AppState.Section) -> some View {
        Button {
            withAnimation(.default) {
                appState.selectedSection = section
            }
        } label: {
            HStack(spacing: NativeSpacing.md) {
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isSelected(section) ? Color.accentColor : Color.secondary)
                    .frame(width: 22)

                Text(locManager.localized("sidebar.\(section.rawValue)"))
                    .font(.headline)
                    .foregroundStyle(isSelected(section) ? .primary : .secondary)

                Spacer()

                if section == .recent && !appState.recentFiles.isEmpty {
                    Text("\(appState.recentFiles.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, NativeSpacing.sm)
                        .padding(.vertical, 2)
                }
            }
            .padding(.horizontal, NativeSpacing.md)
            .padding(.vertical, NativeSpacing.sm)
            .contentShape(Capsule())
            .background {
                if isSelected(section) {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locManager.localized("sidebar.\(section.rawValue)"))
    }

    private func isSelected(_ section: AppState.Section) -> Bool {
        appState.selectedSection == section
    }
}

#Preview("Sidebar") {
    AppSidebar()
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
        .frame(width: 200, height: 500)
}
