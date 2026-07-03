import SwiftUI

struct AboutView: View {
    @EnvironmentObject var locManager: LocalizationManager

    private let ruffleSourceURL = URL(string: "https://github.com/ruffle-rs/ruffle")

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: NativeSpacing.xl) {
            Image(systemName: "sparkles.tv")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(locManager.localized("about.title"))
                .font(.largeTitle.weight(.semibold))

            Text(locManager.localized("about.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 200)

            VStack(spacing: NativeSpacing.md) {
                AboutRow(label: locManager.localized("about.version"), value: appVersion)
                AboutRow(label: locManager.localized("about.build"), value: buildNumber)
                AboutRow(label: locManager.localized("about.ruffleVersion"), value: "0.3.0")
            }

            Divider()
                .frame(width: 200)

            footer
        }
        .padding(40)
        .frame(width: 360, height: 420)
    }

    private var footer: some View {
        VStack(spacing: NativeSpacing.xs) {
            Text(locManager.localized("about.copyright"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let ruffleSourceURL {
                Link(locManager.localized("about.sourceLink"), destination: ruffleSourceURL)
                    .font(.caption)
            }

            Text(locManager.localized("about.license"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 260)
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .frame(width: 200)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
