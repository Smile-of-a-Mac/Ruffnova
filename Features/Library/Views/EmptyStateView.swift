// EmptyStateView — Floating welcome experience.
// Minimal chrome. Content-first. Glass above glass.
// Animations are subtle and physical.

import SwiftUI
import UniformTypeIdentifiers

struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
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

            if !appState.recentFiles.isEmpty {
                recentFilesSection
                    .padding(.bottom, NativeSpacing.section)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
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
    }

    // MARK: - Flash Icon

    private var flashIcon: some View {
        ZStack {
            Circle()
                .fill(.tint.opacity(0.05))
                .frame(width: 140, height: 140)
                .blur(radius: 30)
                .scaleEffect(appeared ? 1.0 : 0.5)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(GlassMaterial.light)
                .frame(width: 104, height: 104)
                .overlay {
                    Circle()
                        .strokeBorder(.quaternary.opacity(0.6), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 10)

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(appeared ? 1.0 : 0.5)
                .opacity(appeared ? 1 : 0)
        }
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
        }
        .buttonStyle(.plain)
        .liquidGlassRounded(cornerRadius: NativeRadius.xxl, material: GlassMaterial.light)
        .scaleEffect(appeared ? 1.0 : 0.9)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Recent Files

    private var recentFilesSection: some View {
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
                    ForEach(Array(appState.recentFiles.prefix(6))) { file in
                        recentFileItem(file)
                    }
                }
            }
        }
        .frame(maxWidth: 560)
        .scaleEffect(appeared ? 1.0 : 0.95)
        .opacity(appeared ? 1 : 0)
    }

    private func recentFileItem(_ file: RecentFile) -> some View {
        Button { appState.openFile(file.url) } label: {
            VStack(alignment: .leading, spacing: NativeSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: NativeRadius.lg, style: .continuous)
                        .fill(GlassMaterial.light)
                        .aspectRatio(4/3, contentMode: .fill)
                        .frame(width: 110, height: 82)
                        .overlay {
                            RoundedRectangle(cornerRadius: NativeRadius.lg, style: .continuous)
                                .strokeBorder(.quaternary.opacity(0.45), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)

                    Image(systemName: "play.rectangle")
                        .font(.system(size: 20))
                        .foregroundStyle(.quaternary)
                }

                Text(file.name)
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
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "swf")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.message = locManager.localized("workspace.openPanel.message")
        if panel.runModal() == .OK, let url = panel.url {
            appState.openFile(url)
        }
    }

    private func showImportFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = locManager.localized("library.chooseFolder.message")
        if panel.runModal() == .OK, let url = panel.url {
            appState.browseDirectory(url)
        }
    }
}
