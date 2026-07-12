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
    var setLetterbox: @MainActor (String) -> Void = { _ in }
    var setShowDebugUI: @MainActor (Bool) -> Void = { _ in }
    var showTraceConsole: @MainActor () -> Void = {}
    var showDiagnostics: @MainActor () -> Void = {}
    var hasCurrentFile: @MainActor () -> Bool = { false }
    var resetRuntimeSettings: @MainActor () -> Void = {}

    init() {}

    @MainActor
    init(appState: AppState) {
        setLooping = { [weak appState] value in appState?.isLooping = value }
        setQuality = { [weak appState] value in appState?.quality = value }
        setSpeed = { [weak appState] value in appState?.setSpeed(value) }
        setMaxExecutionDuration = { [weak appState] value in appState?.maxExecutionDuration = value }
        setLetterbox = { [weak appState] value in appState?.setLetterbox(value) }
        setShowDebugUI = { [weak appState] value in appState?.showDebugUI = value }
        showTraceConsole = { [weak appState] in appState?.showTraceConsole = true }
        showDiagnostics = { [weak appState] in appState?.showDiagnostics = true }
        hasCurrentFile = { [weak appState] in appState?.currentFileURL != nil }
        resetRuntimeSettings = { [weak appState] in
            appState?.quality = .high
            appState?.isLooping = false
            appState?.setSpeed(1.0)
            appState?.maxExecutionDuration = SettingsPersistence.shared.maxExecutionDuration
            appState?.setLetterbox(SettingsPersistence.shared.letterbox)
            appState?.playerMode = .normal
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
    @AppStorage("maxExecutionDuration") private var maxExecutionDuration = 15.0
    @AppStorage("showDebugUI") private var showDebugUI = false
    @State private var showResetAlert = false
    @ObservedObject private var permissionPolicyService = PermissionPolicyService.shared

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
                    case .advanced:
                        macAdvancedPane
                    case .privacy:
                        macPrivacyPane
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
                    Picker("", selection: letterboxBinding) {
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

    private var macAdvancedPane: some View {
        VStack(spacing: 12) {
            MacSettingsGroup(title: locManager.localized("settings.advanced.actionscript")) {
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

                Text(locManager.localized("settings.advanced.actionscript.maxDuration.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    private var macPrivacyPane: some View {
        VStack(spacing: 12) {
            MacSettingsGroup(title: locManager.localized("settings.privacy")) {
                MacInlineSetting(label: locManager.localized("settings.privacy.network")) {
                    Picker("", selection: globalPermissionBinding(.network)) {
                        ForEach(PermissionGlobalDefault.allCases) { decision in
                            Text(locManager.localized("permission.global.\(decision.rawValue)")).tag(decision)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 128, alignment: .leading)
                }
                MacInlineSetting(label: locManager.localized("settings.privacy.filesystem")) {
                    Picker("", selection: globalPermissionBinding(.filesystem)) {
                        ForEach(PermissionGlobalDefault.allCases) { decision in
                            Text(locManager.localized("permission.global.\(decision.rawValue)")).tag(decision)
                        }
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
            if !permissionPolicyService.overrides.isEmpty {
                MacSettingsSeparator()
                MacSettingsGroup(title: locManager.localized("settings.privacy.overrides")) {
                    Button(locManager.localized("settings.privacy.overrides.clearAll"), role: .destructive) {
                        permissionPolicyService.clearAllOverrides()
                    }
                }
            }
        }
    }

    private func globalPermissionBinding(_ scope: PermissionScope) -> Binding<PermissionGlobalDefault> {
        Binding(
            get: { permissionPolicyService.globalDefault(for: scope) },
            set: { permissionPolicyService.setGlobalDefault($0, for: scope) }
        )
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

    private var letterboxBinding: Binding<String> {
        Binding(
            get: { letterbox },
            set: { newValue in
                letterbox = newValue
                settingsActions.setLetterbox(newValue)
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
            case .advanced:
                AdvancedSettingsView()
            case .privacy:
                PrivacySettingsView()
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
            Picker(locManager.localized("settings.general.playback.letterbox"), selection: letterboxBinding) {
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
                        .settingsSliderWidth()
                    Text(String(format: "%.2fx", effectivePlaybackSpeed))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .settingsSliderValueWidth(minimumWidth: 56)
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

    private var letterboxBinding: Binding<String> {
        Binding(
            get: { letterbox },
            set: { newValue in
                letterbox = newValue
                settingsActions.setLetterbox(newValue)
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

struct AdvancedSettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @Environment(\.settingsActions) private var settingsActions
    @AppStorage("maxExecutionDuration") private var maxExecutionDuration = 15.0
    @AppStorage("showDebugUI") private var showDebugUI = false
    @State private var showResetAlert = false

    var body: some View {
        Section {
            LabeledContent(locManager.localized("settings.advanced.actionscript.maxDuration")) {
                HStack(spacing: NativeSpacing.md) {
                    Slider(value: maxExecutionDurationBinding, in: 5...60, step: 1)
                        .settingsSliderWidth()
                    Text(String(format: locManager.localized("settings.advanced.actionscript.secondsFormat"), Int(effectiveMaxExecutionDuration)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .settingsSliderValueWidth(minimumWidth: 74)
                }
                .settingsControlColumn()
            }
        } footer: {
            Text(locManager.localized("settings.advanced.actionscript.maxDuration.footer"))
        }

        #if os(macOS)
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
        #endif

        Section {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label(locManager.localized("settings.advanced.reset"), systemImage: "arrow.counterclockwise")
                    .foregroundStyle(.red)
            }
        }
        .alert(locManager.localized("settings.advanced.reset.title"), isPresented: $showResetAlert) {
            Button(locManager.localized("settings.advanced.reset.actionLabel"), role: .destructive, action: resetSettings)
            Button(locManager.localized("collection.cancel"), role: .cancel) {}
        } message: {
            Text(locManager.localized("settings.advanced.reset.message"))
        }
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
        settingsActions.resetRuntimeSettings()
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @ObservedObject private var permissionPolicyService = PermissionPolicyService.shared
    var showsOverrides = true

    var body: some View {
        Section {
            Picker(locManager.localized("settings.privacy.network"), selection: globalPermissionBinding(.network)) {
                permissionOptions
            }
            Picker(locManager.localized("settings.privacy.filesystem"), selection: globalPermissionBinding(.filesystem)) {
                permissionOptions
            }
        } footer: {
            Text(locManager.localized("settings.privacy.defaults.footer"))
        }

        if showsOverrides {
            Section(locManager.localized("settings.privacy.overrides")) {
                if permissionPolicyService.overrides.isEmpty {
                    Text(locManager.localized("settings.privacy.overrides.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(permissionPolicyService.overrides) { override in
                        HStack {
                            Text(override.fileName)
                            Spacer()
                            Button(locManager.localized("settings.privacy.overrides.clear"), role: .destructive) {
                                permissionPolicyService.clearOverride(override.id)
                            }
                        }
                    }
                    Button(locManager.localized("settings.privacy.overrides.clearAll"), role: .destructive) {
                        permissionPolicyService.clearAllOverrides()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var permissionOptions: some View {
        ForEach(PermissionGlobalDefault.allCases) { decision in
            Text(locManager.localized("permission.global.\(decision.rawValue)")).tag(decision)
        }
    }

    private func globalPermissionBinding(_ scope: PermissionScope) -> Binding<PermissionGlobalDefault> {
        Binding(
            get: { permissionPolicyService.globalDefault(for: scope) },
            set: { permissionPolicyService.setGlobalDefault($0, for: scope) }
        )
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
        #if os(iOS)
        Form {
            aboutSections
        }
        .scrollContentBackground(.hidden)
        .background(settingsPageBackground)
        .navigationTitle(locManager.localized("settings.about"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        #else
        aboutSections
        #endif
    }

    @ViewBuilder
    private var aboutSections: some View {
        Section {
            HStack(alignment: .center, spacing: NativeSpacing.xl) {
                #if os(iOS)
                IOSAboutBrandBlock(subtitle: locManager.localized("about.subtitle"))
                #else
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
                #endif
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

#if os(iOS)
private struct IOSAboutBrandBlock: View {
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: NativeSpacing.xl) {
            if let appIcon = UIImage(named: "AppIcon") {
                Image(uiImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 84, height: 84)
            } else {
                Image("SidebarBrandIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 84, height: 84)
            }

            VStack(alignment: .leading, spacing: 0) {
                Image("SidebarWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 156, height: 48, alignment: .leading)

                Spacer(minLength: NativeSpacing.sm)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 84, alignment: .topLeading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ruffnova, \(subtitle)")
    }
}
#endif

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
    func settingsSliderWidth() -> some View {
        #if os(macOS)
        self.frame(width: 160)
        #else
        self.frame(minWidth: 0, maxWidth: .infinity)
        #endif
    }

    @ViewBuilder
    func settingsSliderValueWidth(minimumWidth: CGFloat) -> some View {
        #if os(macOS)
        self.frame(width: minimumWidth, alignment: .trailing)
        #else
        self.fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: minimumWidth, alignment: .trailing)
        #endif
    }

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
        IOSSettingsRootView()
            .environmentObject(locManager)
            .environment(\.settingsActions, settingsActions)
        #else
        MacSettingsView()
            .environmentObject(locManager)
            .environment(\.settingsActions, settingsActions)
        #endif
    }
}

#if os(iOS)
struct IOSSettingsRootView: View {
    @EnvironmentObject private var locManager: LocalizationManager

    var body: some View {
        Form {
            GeneralSettingsView()
            PrivacySettingsView(showsOverrides: false)
            AdvancedSettingsView()

            Section {
                NavigationLink {
                    AboutSettingsView()
                } label: {
                    Label(locManager.localized("settings.about"), systemImage: "info.circle")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(settingsPageBackground)
        .navigationTitle(locManager.localized("sidebar.settings"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
    }
}
#endif

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case privacy
    case advanced
    case about

    var id: Self { self }

    #if os(macOS)
    static let macSettingsCases: [SettingsCategory] = [.general, .privacy, .advanced]
    #endif

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .privacy: return "lock"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }

    var titleKey: String {
        switch self {
        case .general: return "settings.general"
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
