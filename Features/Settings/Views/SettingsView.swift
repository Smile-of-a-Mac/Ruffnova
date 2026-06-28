import SwiftUI

struct InlineSettingsView: View {
    @State private var selectedCategory: SettingsCategory = .general

    var body: some View {
        VStack(spacing: 0) {
            SettingsTopBar(selectedCategory: $selectedCategory)
            Divider()
            SettingsPane(category: selectedCategory)
                .id(selectedCategory)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case rendering
    case privacy
    case advanced

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .general: return "settings.general"
        case .rendering: return "settings.rendering"
        case .privacy: return "settings.privacy"
        case .advanced: return "settings.advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .rendering: return "display"
        case .privacy: return "hand.raised"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

private struct SettingsTopBar: View {
    @EnvironmentObject var locManager: LocalizationManager
    @Binding var selectedCategory: SettingsCategory

    var body: some View {
        VStack(spacing: NativeSpacing.md) {
            Text(locManager.localized(selectedCategory.titleKey))
                .font(.headline)
                .foregroundStyle(.secondary)

            Picker("", selection: $selectedCategory) {
                ForEach(SettingsCategory.allCases) { category in
                    Label(locManager.localized(category.titleKey), systemImage: category.systemImage)
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 520)
        }
        .padding(.top, NativeSpacing.xl)
        .padding(.bottom, NativeSpacing.lg)
    }
}

private struct SettingsPane: View {
    let category: SettingsCategory

    var body: some View {
        VStack {
            Spacer(minLength: NativeSpacing.xxl)
            Group {
                switch category {
                case .general:
                    GeneralSettingsView()
                case .rendering:
                    RenderingSettingsView()
                case .privacy:
                    PrivacySettingsView()
                case .advanced:
                    AdvancedSettingsView()
                }
            }
            .frame(maxWidth: 560)
            Spacer(minLength: NativeSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var locManager: LocalizationManager
    @AppStorage("autoplay") private var autoplay = true
    @AppStorage("letterbox") private var letterbox = "fullscreen"

    var body: some View {
        SettingsForm {
            SettingsToggleRow(title: locManager.localized("settings.general.playback.autoplay"), isOn: $autoplay)
            SettingsPickerRow(title: locManager.localized("settings.general.playback.letterbox"), selection: $letterbox) {
                Text(locManager.localized("settings.general.playback.letterbox.fullscreen")).tag("fullscreen")
                Text(locManager.localized("settings.general.playback.letterbox.on")).tag("on")
                Text(locManager.localized("settings.general.playback.letterbox.off")).tag("off")
            }
            SettingsPickerRow(title: locManager.localized("settings.general.language"), selection: Binding(
                get: { locManager.selectedLanguage },
                set: { locManager.setLanguage($0) }
            )) {
                ForEach(Language.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
        }
    }
}

struct RenderingSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @AppStorage("graphicsBackend") private var graphicsBackend = "auto"

    var body: some View {
        SettingsForm {
            SettingsPickerRow(title: locManager.localized("settings.rendering.quality.stageQuality"), selection: $appState.quality) {
                Text(locManager.localized("settings.rendering.quality.low")).tag(RuffleQuality.low)
                Text(locManager.localized("settings.rendering.quality.medium")).tag(RuffleQuality.medium)
                Text(locManager.localized("settings.rendering.quality.high")).tag(RuffleQuality.high)
                Text(locManager.localized("settings.rendering.quality.best")).tag(RuffleQuality.best)
            }
            SettingsPickerRow(title: locManager.localized("settings.rendering.graphics.backend"), selection: $graphicsBackend) {
                Text(locManager.localized("settings.rendering.graphics.auto")).tag("auto")
                Text(locManager.localized("settings.rendering.graphics.metal")).tag("metal")
                Text(locManager.localized("settings.rendering.graphics.vulkan")).tag("vulkan")
            }
            SettingsFootnote(text: locManager.localized("settings.rendering.graphics.metal.recommended"), systemImage: "info.circle.fill")
            SettingsValueRow(
                title: locManager.localized("settings.rendering.stage.defaultSize"),
                value: "\(appState.stageWidth) \u{00D7} \(appState.stageHeight)"
            )
        }
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject var locManager: LocalizationManager
    @AppStorage("networkAccess") private var networkAccess = "prompt"
    @AppStorage("filesystemAccess") private var filesystemAccess = "prompt"

    var body: some View {
        SettingsForm {
            SettingsPickerRow(title: locManager.localized("settings.privacy.network.prompt"), selection: $networkAccess) {
                Text(locManager.localized("settings.privacy.network.alwaysAsk")).tag("prompt")
                Text(locManager.localized("settings.privacy.network.allow")).tag("allow")
                Text(locManager.localized("settings.privacy.network.deny")).tag("deny")
            }
            SettingsFootnote(text: locManager.localized("settings.privacy.network.sandboxed"), systemImage: "lock.fill")
            SettingsPickerRow(title: locManager.localized("settings.privacy.filesystem.prompt"), selection: $filesystemAccess) {
                Text(locManager.localized("settings.inline.alwaysAsk")).tag("prompt")
                Text(locManager.localized("settings.inline.allow")).tag("allow")
                Text(locManager.localized("settings.inline.deny")).tag("deny")
            }
            SettingsFootnote(text: locManager.localized("settings.privacy.filesystem.restricted"), systemImage: "shield.fill")
            SettingsValueRow(
                title: locManager.localized("settings.privacy.data.usageStats"),
                value: locManager.localized("settings.privacy.data.disabled")
            )
            SettingsFootnote(text: locManager.localized("settings.privacy.data.noCollection"), systemImage: "checkmark.shield.fill")
        }
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @AppStorage("maxExecutionDuration") private var maxExecutionDuration = 15.0
    @State private var showResetAlert = false

    var body: some View {
        SettingsForm {
            SettingsToggleRow(title: locManager.localized("settings.advanced.actionscript.avm2Optimizer"), isOn: $appState.avm2OptimizerEnabled)
            SettingsDurationRow(
                title: locManager.localized("settings.advanced.actionscript.maxDuration"),
                value: $maxExecutionDuration,
                unit: locManager.localized("settings.advanced.actionscript.seconds")
            )
            SettingsToggleRow(title: locManager.localized("settings.advanced.debug.showUI"), isOn: $appState.showDebugUI)
            SettingsFootnote(text: locManager.localized("settings.advanced.debug.warning"), systemImage: "exclamationmark.triangle.fill")
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label(locManager.localized("settings.advanced.reset"), systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
        .alert(locManager.localized("settings.advanced.reset.title"), isPresented: $showResetAlert) {
            Button(locManager.localized("settings.advanced.reset.actionLabel"), role: .destructive, action: resetSettings)
            Button(locManager.localized("collection.cancel"), role: .cancel) {}
        } message: {
            Text(locManager.localized("settings.advanced.reset.message"))
        }
    }

    private func resetSettings() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "autoplay")
        defaults.set("fullscreen", forKey: "letterbox")
        defaults.set("auto", forKey: "graphicsBackend")
        defaults.set("prompt", forKey: "networkAccess")
        defaults.set("prompt", forKey: "filesystemAccess")
        defaults.set(15.0, forKey: "maxExecutionDuration")
        appState.quality = .high
        appState.avm2OptimizerEnabled = true
        appState.showDebugUI = false
    }
}

private struct SettingsForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Grid(alignment: .trailing, horizontalSpacing: NativeSpacing.md, verticalSpacing: NativeSpacing.lg) {
            content
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        GridRow {
            SettingsRowLabel(title)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .frame(width: 220, alignment: .leading)
        }
    }
}

private struct SettingsPickerRow<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder var content: Content

    var body: some View {
        GridRow {
            SettingsRowLabel(title)
            Picker(title, selection: $selection) {
                content
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 220, alignment: .leading)
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        GridRow {
            SettingsRowLabel(title)
            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)
        }
    }
}

private struct SettingsDurationRow: View {
    let title: String
    @Binding var value: Double
    let unit: String

    var body: some View {
        GridRow {
            SettingsRowLabel(title)
            HStack(spacing: NativeSpacing.sm) {
                TextField("", value: $value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 220, alignment: .leading)
        }
    }
}

private struct SettingsFootnote: View {
    let text: String
    let systemImage: String

    var body: some View {
        GridRow {
            Color.clear
                .gridCellUnsizedAxes([.horizontal, .vertical])
            Label(text, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsRowLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: 260, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    var body: some View {
        InlineSettingsView()
            .environmentObject(appState)
            .environmentObject(locManager)
    }
}

#Preview("Settings") {
    InlineSettingsView()
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
        .frame(width: 860, height: 560)
}
