import SwiftUI

struct AboutView: View {
    @EnvironmentObject var locManager: LocalizationManager

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
                AboutRow(label: locManager.localized("about.renderer"), value: "Metal (wgpu)")
            }

            Divider()
                .frame(width: 200)

            Link(locManager.localized("about.sourceLink"),
                 destination: URL(string: "https://github.com/ruffle-rs/ruffle")!)
                .font(.caption)

            Text(locManager.localized("about.license"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(width: 360, height: 420)
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
