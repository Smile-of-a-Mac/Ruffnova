import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct SettingsActions {
    var setLooping: @MainActor (Bool) -> Void = { _ in }
    var setQuality: @MainActor (RuffleQuality) -> Void = { _ in }
    var setSpeed: @MainActor (Float) -> Void = { _ in }
    var setMaxExecutionDuration: @MainActor (Double) -> Void = { _ in }
    var setAVM2OptimizerEnabled: @MainActor (Bool) -> Void = { _ in }
    var setShowDebugUI: @MainActor (Bool) -> Void = { _ in }
    var showTraceConsole: @MainActor () -> Void = {}
    var showDiagnostics: @MainActor () -> Void = {}
    var hasCurrentFile: @MainActor () -> Bool = { false }
    var avm2OptimizerEnabled: @MainActor () -> Bool = { true }
    var resetRuntimeSettings: @MainActor () -> Void = {}

    init() {}

    @MainActor
    init(appState: AppState) {
        setLooping = { [weak appState] value in appState?.isLooping = value }
        setQuality = { [weak appState] value in appState?.quality = value }
        setSpeed = { [weak appState] value in appState?.setSpeed(value) }
        setMaxExecutionDuration = { [weak appState] value in appState?.maxExecutionDuration = value }
        setAVM2OptimizerEnabled = { [weak appState] value in appState?.avm2OptimizerEnabled = value }
        setShowDebugUI = { [weak appState] value in appState?.showDebugUI = value }
        showTraceConsole = { [weak appState] in appState?.showTraceConsole = true }
        showDiagnostics = { [weak appState] in appState?.showDiagnostics = true }
        hasCurrentFile = { [weak appState] in appState?.currentFileURL != nil }
        avm2OptimizerEnabled = { [weak appState] in appState?.avm2OptimizerEnabled ?? true }
        resetRuntimeSettings = { [weak appState] in
            appState?.quality = .high
            appState?.isLooping = false
            appState?.setSpeed(1.0)
            appState?.maxExecutionDuration = SettingsPersistence.shared.maxExecutionDuration
            appState?.playerMode = .normal
            appState?.avm2OptimizerEnabled = true
            appState?.showDebugUI = false
        }
    }
}

private struct SettingsActionsKey: EnvironmentKey {
    static let defaultValue = SettingsActions()
}

extension EnvironmentValues {
    var settingsActions: SettingsActions {
        get { self[SettingsActionsKey.self] }
        set { self[SettingsActionsKey.self] = newValue }
    }
}

struct InlineSettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @State private var selectedCategory: SettingsCategory = .general
    var centerContent = true

    init(initialCategory: SettingsCategory = .general, centerContent: Bool = true) {
        self._selectedCategory = State(initialValue: initialCategory)
        self.centerContent = centerContent
    }

    private var categoryPickerWidth: CGFloat {
        #if os(macOS)
        480
        #else
        460
        #endif
    }

    private var formWidth: CGFloat {
        #if os(macOS)
        560
        #else
        680
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(macOS)
        NativeSpacing.xxl
        #else
        NativeSpacing.section
        #endif
    }

    private var platformBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemGroupedBackground)
        #endif
    }

    var body: some View {
        VStack(alignment: centerContent ? .center : .leading, spacing: NativeSpacing.xl) {
            Picker("", selection: $selectedCategory) {
                ForEach(SettingsCategory.allCases) { category in
                    Text(locManager.localized(category.titleKey)).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: categoryPickerWidth)
            .accessibilityLabel(locManager.localized("settings.category"))

            SettingsForm(category: selectedCategory)
                .frame(width: formWidth, alignment: .center)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: centerContent ? .top : .topLeading)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, NativeSpacing.section)
        .background(platformBackground)
        .animation(.glassSmooth, value: selectedCategory)
    }
}

private struct SettingsForm: View {
    let category: SettingsCategory

    var body: some View {
        Form {
            switch category {
            case .general:
                GeneralSettingsView()
            case .rendering:
                RenderingSettingsView()
            case .privacy:
                PrivacySettingsView()
            case .advanced:
                AdvancedSettingsView()
            case .about:
                AboutSettingsView()
            }
        }
        .scrollContentBackground(.hidden)
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @Environment(\.settingsActions) private var settingsActions
    @AppStorage("autoplay") private var autoplay = true
    @AppStorage("letterbox") private var letterbox = "fullscreen"
    @AppStorage("defaultPlayerMode") private var defaultPlayerMode = PlayerMode.normal.rawValue
    @AppStorage("loop") private var isLooping = false
    @AppStorage("quality") private var qualityRawValue = Int(RuffleQuality.high.rawValue)
    @AppStorage("speed") private var playbackSpeed = 1.0

    var body: some View {
        Section {
            Toggle(locManager.localized("settings.general.playback.autoplay"), isOn: $autoplay)
            Picker(locManager.localized("settings.general.playback.letterbox"), selection: $letterbox) {
                Text(locManager.localized("settings.general.playback.letterbox.fullscreen")).tag("fullscreen")
                Text(locManager.localized("settings.general.playback.letterbox.on")).tag("on")
                Text(locManager.localized("settings.general.playback.letterbox.off")).tag("off")
            }
            Picker(locManager.localized("settings.general.playback.defaultMode"), selection: defaultPlayerModeBinding) {
                ForEach(PlayerMode.allCases) { mode in
                    Text(locManager.localized(mode.localizedKey)).tag(mode.rawValue)
                }
            }
            Toggle(locManager.localized("settings.general.playback.loop"), isOn: loopingBinding)
            Picker(locManager.localized("settings.rendering.quality.stageQuality"), selection: qualityBinding) {
                Text(locManager.localized("settings.rendering.quality.low")).tag(RuffleQuality.low)
                Text(locManager.localized("settings.rendering.quality.medium")).tag(RuffleQuality.medium)
                Text(locManager.localized("settings.rendering.quality.high")).tag(RuffleQuality.high)
                Text(locManager.localized("settings.rendering.quality.best")).tag(RuffleQuality.best)
            }
            LabeledContent(locManager.localized("settings.general.playback.speed")) {
                HStack(spacing: NativeSpacing.md) {
                    Slider(value: speedBinding, in: 0.25...4.0, step: 0.25)
                        .frame(minWidth: 160)
                    Text(String(format: "%.2fx", effectivePlaybackSpeed))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
                .settingsControlColumn()
            }
        } header: {
            Label(locManager.localized("settings.general.playback"), systemImage: "play.circle")
        }

        Section {
            Picker(locManager.localized("settings.general.language"), selection: languageBinding) {
                ForEach(Language.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
        } header: {
            Label(locManager.localized("settings.inline.language"), systemImage: "globe")
        }
    }

    private var defaultPlayerModeBinding: Binding<String> {
        Binding(
            get: { defaultPlayerMode },
            set: { newValue in
                defaultPlayerMode = newValue
                SettingsPersistence.shared.defaultPlayerMode = PlayerMode(rawValue: newValue) ?? .normal
            }
        )
    }

    private var loopingBinding: Binding<Bool> {
        Binding(
            get: { isLooping },
            set: { newValue in
                isLooping = newValue
                settingsActions.setLooping(newValue)
            }
        )
    }

    private var qualityBinding: Binding<RuffleQuality> {
        Binding(
            get: { RuffleQuality(rawValue: Int32(qualityRawValue)) ?? .high },
            set: { newValue in
                qualityRawValue = Int(newValue.rawValue)
                settingsActions.setQuality(newValue)
            }
        )
    }

    private var effectivePlaybackSpeed: Double {
        playbackSpeed == 0 ? 1.0 : playbackSpeed
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { effectivePlaybackSpeed },
            set: { newValue in
                playbackSpeed = newValue
                settingsActions.setSpeed(Float(newValue))
            }
        )
    }

    private var languageBinding: Binding<Language> {
        Binding(
            get: { locManager.selectedLanguage },
            set: { locManager.setLanguage($0) }
        )
    }
}

struct RenderingSettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @AppStorage("graphicsBackend") private var graphicsBackend = "auto"

    var body: some View {
        Section {
            Picker(locManager.localized("settings.rendering.graphics.backend"), selection: $graphicsBackend) {
                Text(locManager.localized("settings.rendering.graphics.auto")).tag("auto")
                Text(locManager.localized("settings.rendering.graphics.metal")).tag("metal")
            }
            LabeledContent(locManager.localized("settings.rendering.graphics.unavailable")) {
                Text(locManager.localized("settings.rendering.graphics.vulkan.unavailable"))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label(locManager.localized("settings.rendering.graphics"), systemImage: "display")
        } footer: {
            Text(String(format: locManager.localized("settings.rendering.graphics.metal.recommended"), platformName))
        }
        .onAppear {
            if graphicsBackend == "vulkan" {
                graphicsBackend = "auto"
            }
        }
    }

    private var platformName: String {
        #if os(macOS)
        "macOS"
        #else
        "iOS"
        #endif
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @ObservedObject private var permissionPolicy = PermissionPolicyService.shared

    var body: some View {
        Section {
            Picker(locManager.localized("settings.privacy.network.prompt"), selection: globalDefaultBinding(for: .network)) {
                Text(locManager.localized("permission.global.alwaysAsk")).tag(PermissionGlobalDefault.alwaysAsk)
                Text(locManager.localized("permission.global.allow")).tag(PermissionGlobalDefault.allow)
                Text(locManager.localized("permission.global.deny")).tag(PermissionGlobalDefault.deny)
            }
            Picker(locManager.localized("settings.privacy.filesystem.prompt"), selection: globalDefaultBinding(for: .filesystem)) {
                Text(locManager.localized("permission.global.alwaysAsk")).tag(PermissionGlobalDefault.alwaysAsk)
                Text(locManager.localized("permission.global.allow")).tag(PermissionGlobalDefault.allow)
                Text(locManager.localized("permission.global.deny")).tag(PermissionGlobalDefault.deny)
            }
        } header: {
            Label(locManager.localized("settings.privacy"), systemImage: "hand.raised")
        } footer: {
            Text(locManager.localized("settings.privacy.defaults.footer"))
        }

        Section {
            PermissionOverridesListView()
        } header: {
            Label(locManager.localized("settings.privacy.overrides"), systemImage: "doc.badge.gearshape")
        } footer: {
            Text(locManager.localized("settings.privacy.overrides.subtitle"))
        }

        Section {
            LabeledContent(locManager.localized("settings.privacy.data.usageStats")) {
                Text(locManager.localized("settings.privacy.data.disabled"))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label(locManager.localized("settings.privacy.data"), systemImage: "checkmark.shield")
        } footer: {
            Text(locManager.localized("settings.privacy.data.noCollection"))
        }
    }

    private func globalDefaultBinding(for scope: PermissionScope) -> Binding<PermissionGlobalDefault> {
        Binding(
            get: { permissionPolicy.globalDefault(for: scope) },
            set: { permissionPolicy.setGlobalDefault($0, for: scope) }
        )
    }
}

private struct PermissionOverridesListView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @ObservedObject private var permissionPolicy = PermissionPolicyService.shared

    var body: some View {
        if permissionPolicy.overrides.isEmpty {
            LabeledContent(locManager.localized("settings.privacy.overrides.empty")) {
                Text(locManager.localized("settings.privacy.overrides.none"))
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(permissionPolicy.overrides) { override in
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                        Text(override.fileName)
                        Text("\(localizedScope(override.scope)) - \(localizedDecision(override.decision))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        permissionPolicy.clearOverride(override.id)
                    } label: {
                        Label(locManager.localized("settings.privacy.overrides.clear"), systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }

            Button(role: .destructive) {
                permissionPolicy.clearAllOverrides()
            } label: {
                Label(locManager.localized("settings.privacy.overrides.clearAll"), systemImage: "trash")
            }
        }
    }

    private func localizedScope(_ scope: PermissionScope) -> String {
        switch scope {
        case .network:
            return locManager.localized("permission.scope.network")
        case .filesystem:
            return locManager.localized("permission.scope.filesystem")
        }
    }

    private func localizedDecision(_ decision: PermissionDecision) -> String {
        switch decision {
        case .alwaysAsk:
            return locManager.localized("permission.decision.alwaysAsk")
        case .allowOnce:
            return locManager.localized("permission.decision.allowOnce")
        case .allowForFile:
            return locManager.localized("permission.decision.allowForFile")
        case .denyForFile:
            return locManager.localized("permission.decision.denyForFile")
        case .useGlobalDefault:
            return locManager.localized("permission.decision.useGlobalDefault")
        }
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @Environment(\.settingsActions) private var settingsActions
    @AppStorage("maxExecutionDuration") private var maxExecutionDuration = 15.0
    @AppStorage("showDebugUI") private var showDebugUI = false
    @State private var avm2OptimizerEnabled = true
    @State private var showResetAlert = false

    var body: some View {
        Section {
            Toggle(locManager.localized("settings.advanced.actionscript.avm2Optimizer"), isOn: avm2OptimizerBinding)
            LabeledContent(locManager.localized("settings.advanced.actionscript.maxDuration")) {
                HStack(spacing: NativeSpacing.md) {
                    Slider(value: maxExecutionDurationBinding, in: 5...60, step: 1)
                        .frame(minWidth: 160)
                    Text(String(format: locManager.localized("settings.advanced.actionscript.secondsFormat"), Int(effectiveMaxExecutionDuration)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .trailing)
                }
                .settingsControlColumn()
            }
        } header: {
            Label(locManager.localized("settings.advanced.actionscript"), systemImage: "curlybraces")
        }

        Section {
            Toggle(locManager.localized("settings.advanced.debug.showUI"), isOn: showDebugUIBinding)
            Button {
                settingsActions.showTraceConsole()
            } label: {
                Label(locManager.localized("menu.traceConsole"), systemImage: "terminal")
            }
            Button {
                settingsActions.showDiagnostics()
            } label: {
                Label(locManager.localized("diagnostics.title"), systemImage: "stethoscope")
            }
            .disabled(!settingsActions.hasCurrentFile())
        } header: {
            Label(locManager.localized("settings.advanced.debug"), systemImage: "ladybug")
        } footer: {
            Text(locManager.localized("settings.advanced.debug.warning"))
        }

        Section {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label(locManager.localized("settings.advanced.reset"), systemImage: "arrow.counterclockwise")
            }
        }
        .alert(locManager.localized("settings.advanced.reset.title"), isPresented: $showResetAlert) {
            Button(locManager.localized("settings.advanced.reset.actionLabel"), role: .destructive, action: resetSettings)
            Button(locManager.localized("collection.cancel"), role: .cancel) {}
        } message: {
            Text(locManager.localized("settings.advanced.reset.message"))
        }
        .onAppear {
            avm2OptimizerEnabled = settingsActions.avm2OptimizerEnabled()
        }
    }

    private var avm2OptimizerBinding: Binding<Bool> {
        Binding(
            get: { avm2OptimizerEnabled },
            set: { newValue in
                avm2OptimizerEnabled = newValue
                settingsActions.setAVM2OptimizerEnabled(newValue)
            }
        )
    }

    private var effectiveMaxExecutionDuration: Double {
        maxExecutionDuration == 0 ? 15.0 : maxExecutionDuration
    }

    private var maxExecutionDurationBinding: Binding<Double> {
        Binding(
            get: { effectiveMaxExecutionDuration },
            set: { newValue in
                maxExecutionDuration = newValue
                settingsActions.setMaxExecutionDuration(newValue)
            }
        )
    }

    private var showDebugUIBinding: Binding<Bool> {
        Binding(
            get: { showDebugUI },
            set: { newValue in
                showDebugUI = newValue
                settingsActions.setShowDebugUI(newValue)
            }
        )
    }

    private func resetSettings() {
        SettingsPersistence.shared.resetAll()
        PermissionPolicyService.shared.setGlobalDefault(.alwaysAsk, for: .network)
        PermissionPolicyService.shared.setGlobalDefault(.alwaysAsk, for: .filesystem)
        PermissionPolicyService.shared.clearAllOverrides()
        maxExecutionDuration = SettingsPersistence.shared.maxExecutionDuration
        showDebugUI = false
        avm2OptimizerEnabled = true
        settingsActions.resetRuntimeSettings()
    }
}

struct AboutSettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager

    private let ruffleSourceURL = URL(string: "https://github.com/ruffle-rs/ruffle")

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        Section {
            HStack(alignment: .center, spacing: NativeSpacing.xl) {
                AboutAppIconView()

                VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                    Text(locManager.localized("about.title"))
                        .font(.largeTitle.weight(.semibold))
                    Text(locManager.localized("about.subtitle"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, NativeSpacing.md)
            .accessibilityElement(children: .combine)
        }

        Section {
            LabeledContent(locManager.localized("about.version"), value: appVersion)
            LabeledContent(locManager.localized("about.build"), value: buildNumber)
            LabeledContent(locManager.localized("about.ruffleVersion"), value: "0.3.0")
        } header: {
            Label(locManager.localized("settings.about"), systemImage: "info.circle")
        }

        if let ruffleSourceURL {
            Section {
                Link(locManager.localized("about.sourceLink"), destination: ruffleSourceURL)
            } footer: {
                VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                    Text(locManager.localized("about.copyright"))
                    Text(locManager.localized("about.license"))
                }
            }
        }
    }
}

private struct AboutAppIconView: View {
    var body: some View {
        icon
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: NativeRadius.lg, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var icon: some View {
        #if os(macOS)
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
        #else
        if let image = iosAppIcon {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "sparkles.tv")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(.hierarchical)
        }
        #endif
    }

    #if os(iOS)
    private var iosAppIcon: UIImage? {
        if let image = UIImage(named: "AppIcon") {
            return image
        }

        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
        else { return nil }

        return iconFiles.reversed().compactMap { UIImage(named: $0) }.first
    }
    #endif
}

private extension View {
    @ViewBuilder
    func settingsControlColumn() -> some View {
        #if os(macOS)
        self.frame(width: 280, alignment: .trailing)
        #else
        self
        #endif
    }
}

struct SettingsView: View {
    @EnvironmentObject var locManager: LocalizationManager
    let settingsActions: SettingsActions

    init(settingsActions: SettingsActions = SettingsActions()) {
        self.settingsActions = settingsActions
    }

    var body: some View {
        #if os(iOS)
        if isIPad {
            InlineSettingsView()
                .environmentObject(locManager)
                .environment(\.settingsActions, settingsActions)
        } else {
            IOSSettingsRootView()
                .environmentObject(locManager)
                .environment(\.settingsActions, settingsActions)
        }
        #else
        InlineSettingsView()
            .environmentObject(locManager)
            .environment(\.settingsActions, settingsActions)
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
                    Label(locManager.localized(category.titleKey), systemImage: category.icon)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(locManager.localized("sidebar.settings"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct SettingsCategoryDetailView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    let category: SettingsCategory

    var body: some View {
        SettingsForm(category: category)
            .navigationTitle(locManager.localized(category.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
    }
}
#endif

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case rendering
    case privacy
    case advanced
    case about

    var id: Self { self }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .rendering: return "display"
        case .privacy: return "hand.raised"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }

    var titleKey: String {
        switch self {
        case .general: return "settings.general"
        case .rendering: return "settings.rendering"
        case .privacy: return "settings.privacy"
        case .advanced: return "settings.advanced"
        case .about: return "settings.about"
        }
    }
}

#Preview("Settings") {
    InlineSettingsView()
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
        .frame(width: 900, height: 640)
}
