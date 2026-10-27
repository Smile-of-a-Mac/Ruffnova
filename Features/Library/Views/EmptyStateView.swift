// EmptyStateView — Floating welcome experience.
// Minimal chrome. Content-first. Glass above glass.
// Animations are subtle and physical.

import SwiftUI

/// iPhone Duo's inner display reserves a vertical control strip on its trailing edge, which
/// offsets the safe-area center from the physical display center. Centered, non-scrolling
/// content opts in to spanning that strip so it reads as centered on the display, the same
/// way Safari centers its start page.
private struct CentersOnDisplayKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var centersOnDisplay: Bool {
        get { self[CentersOnDisplayKey.self] }
        set { self[CentersOnDisplayKey.self] = newValue }
    }
}

private struct DisplayCenteredModifier: ViewModifier {
    @Environment(\.centersOnDisplay) private var centersOnDisplay

    func body(content: Content) -> some View {
        // Span the reserved trailing strip for the whole regular-width lifetime. The
        // content position is then driven purely by the split view's own column-width
        // animation, so showing or hiding the sidebar stays a single smooth motion.
        // Vertical edges are included so the split view's per-column insets can't shift
        // the content up or down when the sidebar is toggled.
        content.ignoresSafeArea(
            .container,
            edges: centersOnDisplay ? [.trailing, .top, .bottom] : []
        )
    }
}

extension View {
    /// Centers non-scrolling content on the physical display, spanning any reserved trailing
    /// control strip. No effect unless an ancestor sets `centersOnDisplay`.
    func centersOnDisplay() -> some View {
        modifier(DisplayCenteredModifier())
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var libraryService = LibraryService.shared
    @Binding var isDropTargeted: Bool

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            flashIcon
                .padding(.bottom, NativeSpacing.section)

            Text(locManager.localized("empty.welcome.title"))
                .font(.largeTitle)
                .padding(.bottom, NativeSpacing.sm)

            Text(locManager.localized("empty.welcome.subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .padding(.bottom, NativeSpacing.section)

            HStack(spacing: NativeSpacing.xl) {
                primaryButton
                secondaryButton
            }
            .padding(.bottom, NativeSpacing.section)

            if !libraryService.items.isEmpty {
                recentFilesSection
                    .padding(.bottom, NativeSpacing.section)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                    appeared = true
                }
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: NativeRadius.xxl, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 2)
                    .padding(NativeSpacing.xl)
                    .transition(.opacity)
            }
        }
        .centersOnDisplay()
    }

    // MARK: - Flash Icon

    private var flashIcon: some View {
        Image(systemName: "play.rectangle.fill")
            .font(.system(size: 36, weight: .medium))
            .foregroundStyle(.tint)
            .frame(width: 104, height: 104)
            .nativeLiquidGlass(in: Circle(), material: GlassMaterial.light)
            .scaleEffect(appeared ? 1.0 : 0.9)
            .opacity(appeared ? 1 : 0)
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button { showOpenPanel() } label: {
            VStack(spacing: NativeSpacing.sm) {
                Image(systemName: "doc")
                    .font(.system(size: 20, weight: .regular))
                Text(locManager.localized("empty.openSwf"))
                    .font(.callout)
            }
            .frame(width: 120, height: 96)
            .contentShape(RoundedRectangle(cornerRadius: NativeRadius.xxl, style: .continuous))
        }
        .buttonStyle(.plain)
        .liquidGlassRounded(cornerRadius: NativeRadius.xxl, material: GlassMaterial.light)
        .scaleEffect(appeared ? 1.0 : 0.9)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Secondary Button

    private var secondaryButton: some View {
        Button { showImportFolderPanel() } label: {
            VStack(spacing: NativeSpacing.sm) {
                Image(systemName: "folder")
                    .font(.system(size: 20, weight: .regular))
                Text(locManager.localized("empty.importFolder"))
                    .font(.callout)
            }
            .frame(width: 120, height: 96)
            .contentShape(RoundedRectangle(cornerRadius: NativeRadius.xxl, style: .continuous))
        }
        .buttonStyle(.plain)
        .liquidGlassRounded(cornerRadius: NativeRadius.xxl, material: GlassMaterial.light)
        .scaleEffect(appeared ? 1.0 : 0.9)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Recent Files

    @ViewBuilder
    private var recentFilesSection: some View {
        let recentLibraryItems = libraryService.sorted(by: .lastOpened)
            .filter { $0.availabilityStatus == .available }
            .prefix(6)
        if !recentLibraryItems.isEmpty {
            VStack(alignment: .leading, spacing: NativeSpacing.md) {
                HStack(spacing: NativeSpacing.sm) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(locManager.localized("workspace.recent"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .padding(.leading, NativeSpacing.xs)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NativeSpacing.sm) {
                        ForEach(Array(recentLibraryItems)) { item in
                            recentFileItem(item)
                        }
                    }
                }
            }
            .frame(maxWidth: 560)
            .scaleEffect(appeared ? 1.0 : 0.95)
            .opacity(appeared ? 1 : 0)
        }
    }

    private func recentFileItem(_ item: LibraryItem) -> some View {
        Button { appState.openFile(item.url) } label: {
            VStack(alignment: .leading, spacing: NativeSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: NativeRadius.lg, style: .continuous)
                        .fill(GlassMaterial.light)
                        .aspectRatio(4/3, contentMode: .fill)
                        .frame(width: 110, height: 82)

                    Image(systemName: "play.rectangle")
                        .font(.system(size: 20))
                        .foregroundStyle(.quaternary)
                }

                Text(item.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: 110, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Panels

    private func showOpenPanel() {
        Task { await appState.presentOpenFilePanel() }
    }

    private func showImportFolderPanel() {
        Task { await appState.presentFolderPicker() }
    }
}
