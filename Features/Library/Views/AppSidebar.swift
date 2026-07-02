// AppSidebar — Sidebar blends into the window glass.
// NavigationSplitView handles glass separation automatically.
// No decorative elements — pure navigation structure.

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AppSidebar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var libraryService = LibraryService.shared
    @FocusState private var searchFocused: Bool
    @State private var handledSearchFocusRequest = 0

    private let primarySections: [AppState.Section] = [.player, .library, .recent, .favorites]

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xl) {
            VStack(alignment: .leading, spacing: NativeSpacing.md) {
                brandHeader
                searchField
            }

            VStack(spacing: NativeSpacing.xs) {
                ForEach(primarySections, id: \.self) { section in
                    sidebarButton(for: section)
                }
            }

            SidebarCollectionsView()
                .environmentObject(appState)
                .environmentObject(locManager)

            Spacer()
        }
        .padding(.top, sidebarTopPadding)
        .padding(.horizontal, NativeSpacing.lg)
        .padding(.bottom, NativeSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        .onAppear {
            handlePendingSearchFocusRequest()
        }
    }

    private var sidebarTopPadding: CGFloat {
        #if os(macOS)
        NativeSpacing.lg
        #else
        NativeSpacing.section + NativeSpacing.md
        #endif
    }

    private var brandHeader: some View {
        HStack(spacing: NativeSpacing.md) {
            brandIcon

            Text(locManager.localized("app.name"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, NativeSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(locManager.localized("app.name"))
    }

    @ViewBuilder
    private var brandIcon: some View {
        #if os(macOS)
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            .padding(3)
            .background(GlassMaterial.ultraLight, in: RoundedRectangle(cornerRadius: NativeRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: NativeRadius.sm, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 0.7)
            }
        #else
        Image(systemName: "play.rectangle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.tint)
            .frame(width: 30, height: 30)
            .background(GlassMaterial.ultraLight, in: RoundedRectangle(cornerRadius: NativeRadius.sm, style: .continuous))
        #endif
    }

    private var searchField: some View {
        HStack(spacing: NativeSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(searchFocused ? .primary : .secondary)

            TextField(locManager.localized("search.placeholder"), text: searchBinding)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { appState.updateSearchText(appState.searchText) }

            if !appState.searchText.isEmpty {
                Button {
                    appState.clearSearch()
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
        .onChange(of: appState.searchFocusRequest) { _ in
            handlePendingSearchFocusRequest()
        }
    }

    private func handlePendingSearchFocusRequest() {
        guard appState.searchFocusRequest != handledSearchFocusRequest else { return }
        handledSearchFocusRequest = appState.searchFocusRequest
        DispatchQueue.main.async {
            searchFocused = true
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { appState.searchText },
            set: { appState.updateSearchText($0) }
        )
    }

    private func sidebarButton(for section: AppState.Section) -> some View {
        Button {
            withAnimation(.default) {
                appState.selectSection(section)
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

                if section == .recent {
                    let count = libraryService.sorted(by: .lastOpened).prefix(20).count
                    Text("\(count)")
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
        appState.selectedCollectionID == nil && appState.selectedSection == section
    }

}

#Preview("Sidebar") {
    AppSidebar()
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
        .frame(width: 200, height: 500)
}
