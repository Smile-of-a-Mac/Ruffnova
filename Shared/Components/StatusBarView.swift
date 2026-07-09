// StatusBarView — Minimal status bar.
// Near-invisible. Information whispers, never shouts.
// Uses ultra-thin material to float above content.

import SwiftUI

// MARK: - Status Bar

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @ObservedObject private var libraryService = LibraryService.shared

    private var appVersion: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty,
              !version.hasPrefix("$(") else {
            return "Unkown"
        }
        return version
    }

    var body: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: NativeSpacing.md) {
                statusItem(
                    icon: "play.rectangle",
                    text: swfCountLabel,
                    helpText: locManager.localized("statusbar.swfCount.help")
                )
                statusItem(
                    icon: "internaldrive",
                    text: librarySizeLabel,
                    helpText: locManager.localized("statusbar.librarySize.help")
                )
            }
            .padding(.horizontal, NativeSpacing.md)
            .padding(.vertical, NativeSpacing.xs)
            .liquidGlassCapsule()

            Spacer()

            HStack(spacing: NativeSpacing.md) {
                statusBadge(
                    text: locManager.localized("statusbar.appName"),
                    helpText: locManager.localized("statusbar.renderer.help")
                )
                statusDivider
                statusItem(
                    icon: "number",
                    text: appVersion,
                    helpText: locManager.localized("statusbar.version.help")
                )
            }
            .padding(.horizontal, NativeSpacing.md)
            .padding(.vertical, NativeSpacing.xs)
            .liquidGlassCapsule()
        }
        .padding(.horizontal, NativeSpacing.xl)
        .padding(.bottom, NativeSpacing.md)
        .frame(height: 44)
        .onAppear {
            appState.updateLibraryStats()
        }
    }

    // MARK: - Status Item

    private func statusItem(icon: String, text: String, helpText: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .help(helpText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(helpText): \(text)")
    }

    // MARK: - Status Badge

    private func statusBadge(text: String, helpText: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.tint.opacity(0.6))
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .help(helpText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(helpText): \(text)")
    }

    // MARK: - Divider

    private var statusDivider: some View {
        Circle()
            .fill(.separator.opacity(0.3))
            .frame(width: 2, height: 2)
    }

    // MARK: - Labels

    private var swfCountLabel: String {
        if libraryService.items.isEmpty {
            return locManager.localized("statusbar.noFiles")
        }
        let count = libraryService.items.count
        let key = count == 1 ? "statusbar.fileCount" : "statusbar.fileCount.plural"
        return String(format: locManager.localized(key), count)
    }

    private var librarySizeLabel: String {
        let totalSize = libraryService.items.reduce(0) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

// MARK: - Preview

#Preview("Status Bar") {
    StatusBarView()
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
        .frame(width: 500, height: 26)
}
