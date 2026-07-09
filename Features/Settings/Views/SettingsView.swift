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

#if os(macOS)
struct MacSettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @Environment(\.settingsActions) private var settingsActions
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: SettingsCategory = .general
    @AppStorage("autoplay") private var autoplay = true
    @AppStorage("letterbox") private var letterbox = "fullscreen"
    @AppStorage("defaultPlayerMode") private var defaultPlayerMode = PlayerMode.normal.rawValue
    @AppStorage("loop") private var isLooping = false
    @AppStorage("quality") private var qualityRawValue = Int(RuffleQuality.high.rawValue)
    @AppStorage("speed") private var playbackSpeed = 1.0
    @AppStorage("graphicsBackend") private var graphicsBackend = "auto"
    @AppStorage("maxExecutionDuration") private var maxExecutionDuration = 15.0
    @AppStorage("showDebugUI") private var showDebugUI = false
    @ObservedObject private var permissionPolicy = PermissionPolicyService.shared
    @State private var avm2OptimizerEnabled = true
    @State private var showResetAlert = false

    private let categories = SettingsCategory.macSettingsCases
    private let windowSize = NSSize(width: 700, height: 560)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text(locManager.localized(selectedCategory.titleKey))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 28) {
                    ForEach(categories) { category in
                        MacSettingsTab(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.top, 22)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    switch selectedCategory {
                    case .general:
                        macGeneralPane
                    case .rendering:
                        macRenderingPane
                    case .privacy:
                        macPrivacyPane
                    case .advanced:
                        macAdvancedPane
                    case .about:
                        EmptyView()
                    }
                }
                .frame(width: 580, alignment: .top)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            HStack {
                Button {
                    AppCommandRouter.openHelp()
                } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                .accessibilityLabel(locManager.localized("menu.help"))

                Spacer()

                Button(locManager.localized("collection.cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(locManager.localized("library.selection.done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(MacFixedSizeWindowConfigurator(size: windowSize))
        .animation(.glassSmooth, value: selectedCategory)
        .onAppear {
            avm2OptimizerEnabled = settingsActions.avm2OptimizerEnabled()
            if graphicsBackend == "vulkan" {
                graphicsBackend = "auto"
            }
        }
        .alert(locManager.localized("settings.advanced.reset.title"), isPresented: $showResetAlert) {
            Button(locManager.localized("settings.advanced.reset.actionLabel"), role: .destructive, action: resetSettings)
            Button(locManager.localized("collection.cancel"), role: .cancel) {}
        } message: {
            Text(locManager.localized("settings.advanced.reset.message"))
        }
    }

    private var macGeneralPane: some View {
        VStack(spacing: 12) {
            MacSettingsGroup(title: locManager.localized("settings.general.playback")) {
                Toggle(locManager.localized("settings.general.playback.autoplay"), isOn: $autoplay)
                    .toggleStyle(.checkbox)

                MacInlineSetting(label: locManager.localized("settings.general.playback.letterbox")) {
                    Picker("", selection: $letterbox) {
                        Text(locManager.localized("settings.general.playback.letterbox.fullscreen")).tag("fullscreen")
                        Text(locManager.localized("settings.general.playback.letterbox.on")).tag("on")
                        Text(locManager.localized("settings.general.playback.letterbox.off")).tag("off")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 128, alignment: .leading)
                }

                MacInlineSetting(label: locManager.localized("settings.general.playback.defaultMode")) {
                    Picker("", selection: defaultPlayerModeBinding) {
                        ForEach(PlayerMode.allCases) { mode in
                            Text(locManager.localized(mode.localizedKey)).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 128, alignment: .leading)
                }

                Toggle(locManager.localized("settings.general.playback.loop"), isOn: loopingBinding)
                        .toggleStyle(.checkbox)

                MacInlineSetting(label: locManager.localized("settings.rendering.quality.stageQuality")) {
                    Picker("", selection: qualityBinding) {
                        Text(locManager.localized("settings.rendering.quality.low")).tag(RuffleQuality.low)
                        Text(locManager.localized("settings.rendering.quality.medium")).tag(RuffleQuality.medium)
                        Text(locManager.localized("settings.rendering.quality.high")).tag(RuffleQuality.high)
                        Text(locManager.localized("settings.rendering.quality.best")).tag(RuffleQuality.best)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 128, alignment: .leading)
                }

                MacInlineSetting(label: locManager.localized("settings.general.playback.speed")) {
                    HStack(spacing: 14) {
                        Slider(value: speedBinding, in: 0.25...4.0, step: 0.25)
                            .frame(width: 160)
                        Text(String(format: "%.2fx", effectivePlaybackSpeed))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }

            MacSettingsSeparator()

            MacSettingsGroup(title: locManager.localized("settings.inline.language")) {
                Picker("", selection: languageBinding) {
                    ForEach(Language.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 128, alignment: .leading)
            }
        }
    }

    private var macRenderingPane: some View {
        VStack(spacing: 12) {
            MacSettingsGroup(title: locManager.localized("settings.rendering.graphics")) {
                MacInlineSetting(label: locManager.localized("settings.rendering.graphics.backend")) {
                    Picker("", selection: $graphicsBackend) {
                        Text(locManager.localized("settings.rendering.graphics.auto")).tag("auto")
                        Text(locManager.localized("settings.rendering.graphics.metal")).tag("metal")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 128, alignment: .leading)
                }

                MacInlineSetting(label: locManager.localized("settings.rendering.graphics.unavailable")) {
                    Text(locManager.localized("settings.rendering.graphics.vulkan.unavailable"))
                        .foregroundStyle(.secondary)
                }

                Text(String(format: locManager.localized("settings.rendering.graphics.metal.recommended"), platformName))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var macPrivacyPane: some View {
        VStack(spacing: 12) {
            MacSettingsGroup(title: locManager.localized("settings.privacy")) {
                MacInlineSetting(label: locManager.localized("settings.privacy.network.prompt")) {
                    Picker("", selection: globalDefaultBinding(for: .network)) {
                        Text(locManager.localized("permission.global.alwaysAsk")).tag(PermissionGlobalDefault.alwaysAsk)
                        Text(locManager.localized("permission.global.allow")).tag(PermissionGlobalDefault.allow)
                        Text(locManager.localized("permission.global.deny")).tag(PermissionGlobalDefault.deny)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 128, alignment: .leading)
                }

                MacInlineSetting(label: locManager.localized("settings.privacy.filesystem.prompt")) {
                    Picker("", selection: globalDefaultBinding(for: .filesystem)) {
                        Text(locManager.localized("permission.global.alwaysAsk")).tag(PermissionGlobalDefault.alwaysAsk)
                        Text(locManager.localized("permission.global.allow")).tag(PermissionGlobalDefault.allow)
                        Text(locManager.localized("permission.global.deny")).tag(PermissionGlobalDefault.deny)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 128, alignment: .leading)
                }

                Text(locManager.localized("settings.privacy.defaults.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MacSettingsSeparator()

            MacSettingsGroup(title: locManager.localized("settings.privacy.overrides")) {
                if permissionPolicy.overrides.isEmpty {
                    Text(locManager.localized("settings.privacy.overrides.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(permissionPolicy.overrides) { override in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(override.fileName)
                                Text("\(localizedScope(override.scope)) - \(localizedDecision(override.decision))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                permissionPolicy.clearOverride(override.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button(role: .destructive) {
                        permissionPolicy.clearAllOverrides()
                    } label: {
                        Label(locManager.localized("settings.privacy.overrides.clearAll"), systemImage: "trash")
                    }
                }

                Text(locManager.localized("settings.privacy.overrides.subtitle"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MacSettingsSeparator()

            MacSettingsGroup(title: locManager.localized("settings.privacy.data")) {
                MacInlineSetting(label: locManager.localized("settings.privacy.data.usageStats")) {
                    Text(locManager.localized("settings.privacy.data.disabled"))
                        .foregroundStyle(.secondary)
                }

                Text(locManager.localized("settings.privacy.data.noCollection"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var macAdvancedPane: some View {
        VStack(spacing: 12) {
            MacSettingsGroup(title: locManager.localized("settings.advanced.actionscript")) {
                Toggle(locManager.localized("settings.advanced.actionscript.avm2Optimizer"), isOn: avm2OptimizerBinding)
                    .toggleStyle(.checkbox)

                MacInlineSetting(label: locManager.localized("settings.advanced.actionscript.maxDuration")) {
                    HStack(spacing: 14) {
                        Slider(value: maxExecutionDurationBinding, in: 5...60, step: 1)
                            .frame(width: 160)
                        Text(String(format: locManager.localized("settings.advanced.actionscript.secondsFormat"), Int(effectiveMaxExecutionDuration)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 74, alignment: .trailing)
                    }
                }
            }

            MacSettingsSeparator()

            MacSettingsGroup(title: locManager.localized("settings.advanced.debug")) {
                Toggle(locManager.localized("settings.advanced.debug.showUI"), isOn: showDebugUIBinding)
                    .toggleStyle(.checkbox)

                Button {
                    settingsActions.showDiagnostics()
                } label: {
                    Label(locManager.localized("diagnostics.title"), systemImage: "stethoscope")
                }
                .disabled(!settingsActions.hasCurrentFile())

                Text(locManager.localized("settings.advanced.debug.warning"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MacSettingsSeparator()

            MacSettingsGroup(title: locManager.localized("settings.advanced.reset")) {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label(locManager.localized("settings.advanced.reset"), systemImage: "arrow.counterclockwise")
                }
            }
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

    private func globalDefaultBinding(for scope: PermissionScope) -> Binding<PermissionGlobalDefault> {
        Binding(
            get: { permissionPolicy.globalDefault(for: scope) },
            set: { permissionPolicy.setGlobalDefault($0, for: scope) }
        )
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

    private var platformName: String { "macOS" }

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

private struct MacSettingsTab: View {
    @EnvironmentObject private var locManager: LocalizationManager
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: NativeSpacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: 31, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 38)

                Text(locManager.localized(category.titleKey))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 66, height: 66)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.7)
                    )
            }
        }
        .accessibilityLabel(locManager.localized(category.titleKey))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MacSettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title + ":")
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .frame(width: 108, alignment: .trailing)

            VStack(alignment: .leading, spacing: 9) {
                content
            }
            .controlSize(.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

private struct MacInlineSetting<Control: View>: View {
    let label: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.primary)
                .frame(width: 170, alignment: .leading)

            control
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MacSettingsSeparator: View {
    var body: some View {
        Divider()
            .padding(.leading, 124)
    }
}

private struct MacFixedSizeWindowConfigurator: NSViewRepresentable {
    let size: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.minSize = size
        window.maxSize = size
        window.setContentSize(size)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.remove(.resizable)
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}
#endif

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
        settingsPageBackground
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
        .background(settingsPageBackground)
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
        }

        Section {
            Picker(locManager.localized("settings.general.language"), selection: languageBinding) {
                ForEach(Language.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
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
        } footer: {
            Text(locManager.localized("settings.privacy.defaults.footer"))
        }

        Section {
            PermissionOverridesListView()
        } footer: {
            Text(locManager.localized("settings.privacy.overrides.subtitle"))
        }

        Section {
            LabeledContent(locManager.localized("settings.privacy.data.usageStats")) {
                Text(locManager.localized("settings.privacy.data.disabled"))
                    .foregroundStyle(.secondary)
            }
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
        }

        Section {
            Toggle(locManager.localized("settings.advanced.debug.showUI"), isOn: showDebugUIBinding)
            Button {
                settingsActions.showDiagnostics()
            } label: {
                Label(locManager.localized("diagnostics.title"), systemImage: "stethoscope")
            }
            .disabled(!settingsActions.hasCurrentFile())
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
            VStack(alignment: .leading, spacing: NativeSpacing.md) {
                AppBrandHeader(size: .about)
                VStack(alignment: .leading, spacing: NativeSpacing.xs) {
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

private var settingsPageBackground: Color {
    #if os(macOS)
    Color(nsColor: .underPageBackgroundColor)
    #else
    Color(.systemGroupedBackground)
    #endif
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
        MacSettingsView()
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

    #if os(macOS)
    static let macSettingsCases: [SettingsCategory] = [.general, .rendering, .privacy, .advanced]
    #endif

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
