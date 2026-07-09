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
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 34) {
                brandBlock

                VStack(alignment: .leading, spacing: 12) {
                    Text(locManager.localized("about.subtitle"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        AboutRow(label: locManager.localized("about.version"), value: appVersion)
                        Divider()
                        AboutRow(label: locManager.localized("about.build"), value: buildNumber)
                        Divider()
                        AboutRow(label: locManager.localized("about.ruffleVersion"), value: "0.3.0")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(locManager.localized("about.copyright"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    if let ruffleSourceURL {
                        Link(locManager.localized("about.sourceLink"), destination: ruffleSourceURL)
                    }

                    Text(locManager.localized("about.license"))
                        .foregroundStyle(.tertiary)
                }
                .font(.footnote)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 34)
        .padding(.top, 34)
        .padding(.bottom, 24)
        .frame(width: 520, height: 300)
        .background(.background)
    }

    private var brandBlock: some View {
        VStack(alignment: .center, spacing: 14) {
            Image("SidebarBrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Image("SidebarWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 170, height: 48, alignment: .center)
                .offset(x: 24)
                .accessibilityHidden(true)
        }
        .frame(width: 180, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(locManager.localized("about.title")))
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
