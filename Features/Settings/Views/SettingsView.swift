import SwiftUI

struct InlineSettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @State private var selectedCategory: SettingsCategory = .general
    var centerContent = false

    private var platformBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: centerContent ? .center : .leading, spacing: NativeSpacing.xxxl) {
                settingsHeader

                SettingsPane(category: selectedCategory)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: centerContent ? .center : .leading)
            .padding(.horizontal, NativeSpacing.section)
            .padding(.top, NativeSpacing.section)
            .padding(.bottom, NativeSpacing.section)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(platformBackground)
        .animation(.glassSmooth, value: selectedCategory)
    }

    private var settingsHeader: some View {
        VStack(alignment: centerContent ? .center : .leading, spacing: NativeSpacing.lg) {
            Picker("", selection: $selectedCategory) {
                ForEach(SettingsCategory.allCases) { category in
                    Text(locManager.localized(category.titleKey))
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 420)
            .frame(maxWidth: centerContent ? .infinity : nil, alignment: centerContent ? .center : .leading)
        }
    }
}

private struct SettingsPane: View {
    let category: SettingsCategory

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @AppStorage("autoplay") private var autoplay = true
    @AppStorage("letterbox") private var letterbox = "fullscreen"

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
            SettingsSection(
                title: locManager.localized("settings.general.playback"),
                subtitle: locManager.localized("settings.general.playback.subtitle")
            ) {
                SettingsToggleRow(title: locManager.localized("settings.general.playback.autoplay"), isOn: $autoplay)
                SettingsPickerRow(title: locManager.localized("settings.general.playback.letterbox"), selection: $letterbox) {
                    Text(locManager.localized("settings.general.playback.letterbox.fullscreen")).tag("fullscreen")
                    Text(locManager.localized("settings.general.playback.letterbox.on")).tag("on")
                    Text(locManager.localized("settings.general.playback.letterbox.off")).tag("off")
                }
            }

            SettingsSection(
                title: locManager.localized("settings.inline.language"),
                subtitle: locManager.localized("settings.general.language.subtitle")
            ) {
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
}

struct RenderingSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locManager: LocalizationManager
    @AppStorage("graphicsBackend") private var graphicsBackend = "auto"

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
            SettingsSection(
                title: locManager.localized("settings.rendering.quality"),
                subtitle: locManager.localized("settings.rendering.quality.subtitle")
            ) {
                SettingsPickerRow(title: locManager.localized("settings.rendering.quality.stageQuality"), selection: $appState.quality) {
                    Text(locManager.localized("settings.rendering.quality.low")).tag(RuffleQuality.low)
                    Text(locManager.localized("settings.rendering.quality.medium")).tag(RuffleQuality.medium)
                    Text(locManager.localized("settings.rendering.quality.high")).tag(RuffleQuality.high)
                    Text(locManager.localized("settings.rendering.quality.best")).tag(RuffleQuality.best)
                }
            }

            SettingsSection(
                title: locManager.localized("settings.rendering.graphics"),
                subtitle: locManager.localized("settings.rendering.graphics.subtitle")
            ) {
                SettingsPickerRow(title: locManager.localized("settings.rendering.graphics.backend"), selection: $graphicsBackend) {
                    Text(locManager.localized("settings.rendering.graphics.auto")).tag("auto")
                    Text(locManager.localized("settings.rendering.graphics.metal")).tag("metal")
                    Text(locManager.localized("settings.rendering.graphics.vulkan")).tag("vulkan")
                }
                let osName: String = {
                    #if os(macOS)
                    "macOS"
                    #else
                    "iOS"
                    #endif
                }()
                SettingsFootnote(text: String(format: locManager.localized("settings.rendering.graphics.metal.recommended"), osName), systemImage: "info.circle.fill")
            }

        }
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @AppStorage("networkAccess") private var networkAccess = "prompt"
    @AppStorage("filesystemAccess") private var filesystemAccess = "prompt"

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
            SettingsSection(
                title: locManager.localized("settings.privacy.network"),
                subtitle: locManager.localized("settings.privacy.network.subtitle")
            ) {
                SettingsPickerRow(title: locManager.localized("settings.privacy.network.prompt"), selection: $networkAccess) {
                    Text(locManager.localized("settings.privacy.network.alwaysAsk")).tag("prompt")
                    Text(locManager.localized("settings.privacy.network.allow")).tag("allow")
                    Text(locManager.localized("settings.privacy.network.deny")).tag("deny")
                }
                SettingsFootnote(text: locManager.localized("settings.privacy.network.sandboxed"), systemImage: "lock.fill")
            }

            SettingsSection(
                title: locManager.localized("settings.privacy.filesystem"),
                subtitle: locManager.localized("settings.privacy.filesystem.subtitle")
            ) {
                SettingsPickerRow(title: locManager.localized("settings.privacy.filesystem.prompt"), selection: $filesystemAccess) {
                    Text(locManager.localized("settings.inline.alwaysAsk")).tag("prompt")
                    Text(locManager.localized("settings.inline.allow")).tag("allow")
                    Text(locManager.localized("settings.inline.deny")).tag("deny")
                }
                SettingsFootnote(text: locManager.localized("settings.privacy.filesystem.restricted"), systemImage: "shield.fill")
            }

            SettingsSection(
                title: locManager.localized("settings.privacy.data"),
                subtitle: locManager.localized("settings.privacy.data.subtitle")
            ) {
                SettingsValueRow(
                    title: locManager.localized("settings.privacy.data.usageStats"),
                    value: locManager.localized("settings.privacy.data.disabled")
                )
                SettingsFootnote(text: locManager.localized("settings.privacy.data.noCollection"), systemImage: "checkmark.shield.fill")
            }
        }
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locManager: LocalizationManager
    @AppStorage("maxExecutionDuration") private var maxExecutionDuration = 15.0
    @State private var showResetAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
            SettingsSection(
                title: locManager.localized("settings.advanced.actionscript"),
                subtitle: locManager.localized("settings.advanced.actionscript.subtitle")
            ) {
                SettingsToggleRow(title: locManager.localized("settings.advanced.actionscript.avm2Optimizer"), isOn: $appState.avm2OptimizerEnabled)
                SettingsDurationRow(
                    title: locManager.localized("settings.advanced.actionscript.maxDuration"),
                    value: $maxExecutionDuration,
                    unit: locManager.localized("settings.advanced.actionscript.seconds")
                )
            }

            SettingsSection(
                title: locManager.localized("settings.advanced.debug"),
                subtitle: locManager.localized("settings.advanced.debug.subtitle")
            ) {
                SettingsToggleRow(title: locManager.localized("settings.advanced.debug.showUI"), isOn: $appState.showDebugUI)
                SettingsFootnote(text: locManager.localized("settings.advanced.debug.warning"), systemImage: "exclamationmark.triangle.fill")
            }

            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label(locManager.localized("settings.advanced.reset"), systemImage: "arrow.counterclockwise")
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

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(title: title) {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

private struct SettingsPickerRow<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder var content: Content

    var body: some View {
        SettingsRow(title: title) {
            Picker(title, selection: $selection) {
                content
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(minWidth: 180, alignment: .trailing)
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        SettingsRow(title: title) {
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsDurationRow: View {
    let title: String
    @Binding var value: Double
    let unit: String

    var body: some View {
        SettingsRow(title: title) {
            HStack(spacing: NativeSpacing.sm) {
                TextField(title, value: $value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsFootnote: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, NativeSpacing.xs)
            .padding(.bottom, NativeSpacing.sm)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    @ViewBuilder var control: Control

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: NativeSpacing.xxl) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                control
                    .frame(minWidth: 180, alignment: .trailing)
            }
            .frame(minHeight: 44)
            .padding(.vertical, NativeSpacing.sm)

            Divider()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    var body: some View {
        #if os(iOS)
        if isIPad {
            InlineSettingsView(centerContent: true)
                .environmentObject(appState)
                .environmentObject(locManager)
        } else {
            IOSSettingsRootView()
                .environmentObject(appState)
                .environmentObject(locManager)
        }
        #else
        InlineSettingsView()
            .environmentObject(appState)
            .environmentObject(locManager)
        #endif
    }

    #if os(iOS)
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    #endif
}

#if os(iOS)
struct IOSSettingsRootView: View {
    @EnvironmentObject private var locManager: LocalizationManager

    var body: some View {
        List {
            ForEach(SettingsCategory.allCases) { category in
                NavigationLink {
                    SettingsCategoryDetailView(category: category)
                } label: {
                    Label(locManager.localized(category.titleKey),
                          systemImage: category.icon)
                }
            }
        }
        .navigationTitle(locManager.localized("sidebar.settings"))
    }
}

struct SettingsCategoryDetailView: View {
    let category: SettingsCategory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
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
            .padding(NativeSpacing.section)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #if os(iOS)
        .background(Color(.systemBackground))
        #endif
    }
}
#endif

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case rendering
    case privacy
    case advanced

    var id: Self { self }

    #if os(iOS)
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .rendering: return "display"
        case .privacy: return "hand.raised"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
    #endif

    var titleKey: String {
        switch self {
        case .general: return "settings.general"
        case .rendering: return "settings.rendering"
        case .privacy: return "settings.privacy"
        case .advanced: return "settings.advanced"
        }
    }
}

#Preview("Settings") {
    InlineSettingsView()
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
        .frame(width: 900, height: 640)
}
