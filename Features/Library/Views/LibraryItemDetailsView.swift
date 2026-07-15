import SwiftUI

struct LibraryItemDetailsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var libraryService = LibraryService.shared
    @ObservedObject private var collectionService = CollectionService.shared
    @ObservedObject private var permissionPolicyService = PermissionPolicyService.shared

    let itemID: UUID
    let initialSection: LibraryItemDetailsSection
    @State private var tagsText = ""
    @State private var notesText = ""
    @State private var selectedSection: LibraryItemDetailsSection?
    @State private var showInputMappingEditor = false
    @State private var showTouchLayoutEditor = false

    init(itemID: UUID, initialSection: LibraryItemDetailsSection = .overview) {
        self.itemID = itemID
        self.initialSection = initialSection
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }

    @ViewBuilder
    private var macOSBody: some View {
        NavigationSplitView {
            List {
                ForEach(LibraryItemDetailsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Label(
                            locManager.localized(section.localizedKey),
                            systemImage: section.systemImage
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .listRowBackground(
                        (selectedSection ?? initialSection) == section
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        (selectedSection ?? initialSection) == section ? .isSelected : []
                    )
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(locManager.localized("library.details.title"))
        } detail: {
            VStack(spacing: 0) {
                detailContent
                detailActionBar
            }
            .navigationTitle(locManager.localized((selectedSection ?? initialSection).localizedKey))
        }
        .frame(width: 640, height: 480)
        .onAppear(perform: loadDraft)
        .sheet(isPresented: $showInputMappingEditor) {
            InputMappingEditorView(itemID: itemID, profile: libraryService.item(with: itemID)?.inputProfile ?? InputProfile())
                .environmentObject(appState)
                .environmentObject(locManager)
        }
        .sheet(isPresented: $showTouchLayoutEditor) {
            TouchLayoutEditorView(itemID: itemID, layoutSet: libraryService.item(with: itemID)?.inputProfile?.touchLayouts ?? TouchLayoutSet())
                .environmentObject(appState)
                .environmentObject(locManager)
        }
    }

    private var iOSBody: some View {
        NavigationStack {
            detailContent
            .navigationTitle(locManager.localized((selectedSection ?? initialSection).localizedKey))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        saveDraft()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(locManager.localized("menu.close"))
                }

                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(LibraryItemDetailsSection.allCases) { section in
                            Button {
                                selectedSection = section
                            } label: {
                                Label(
                                    locManager.localized(section.localizedKey),
                                    systemImage: section.systemImage
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .accessibilityLabel(locManager.localized("library.details.title"))
                }
            }
        }
        .frame(minHeight: 500)
        .onAppear(perform: loadDraft)
        .sheet(isPresented: $showInputMappingEditor) {
            InputMappingEditorView(itemID: itemID, profile: libraryService.item(with: itemID)?.inputProfile ?? InputProfile())
                .environmentObject(appState)
                .environmentObject(locManager)
        }
        .sheet(isPresented: $showTouchLayoutEditor) {
            TouchLayoutEditorView(itemID: itemID, layoutSet: libraryService.item(with: itemID)?.inputProfile?.touchLayouts ?? TouchLayoutSet())
                .environmentObject(appState)
                .environmentObject(locManager)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let item = libraryService.item(with: itemID) {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: NativeSpacing.xxl) {
                    switch selectedSection ?? initialSection {
                    case .overview:
                        fileSection(item)
                        organizationSection(item)
                        runtimeSettingsSection(item)
                    case .compatibility:
                        compatibilitySection(item)
                    case .controls:
                        controlsSection(item)
                    case .storage:
                        GameStorageSection(libraryID: item.id)
                    case .permissions:
                        permissionSettingsSection(item)
                    }
                }
                .padding(.horizontal, NativeSpacing.lg)
                .padding(.vertical, NativeSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
        } else {
            VStack(spacing: NativeSpacing.md) {
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)
                Text(locManager.localized("library.details.missing"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var detailActionBar: some View {
        HStack {
            Spacer()

            Button(locManager.localized("menu.close")) {
                saveDraft()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, NativeSpacing.lg)
        .padding(.vertical, NativeSpacing.sm)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func fileSection(_ item: LibraryItem) -> some View {
        Section(locManager.localized("library.details.file")) {
            LabeledContent(locManager.localized("diagnostics.report.fileName"), value: item.name)
            LabeledContent(locManager.localized("diagnostics.report.path"), value: item.url.path)
        }
    }

    private func organizationSection(_ item: LibraryItem) -> some View {
        Section(locManager.localized("library.details.organization")) {
            Toggle(locManager.localized(item.isFavorite ? "favorites.remove" : "favorites.add"), isOn: favoriteBinding(item))
            TextField(locManager.localized("library.details.tags.placeholder"), text: $tagsText)
                .onSubmit { saveTags() }
            TextEditor(text: $notesText)
                .frame(minHeight: 96)
                .accessibilityLabel(locManager.localized("library.details.notes"))

            if collectionService.collections.isEmpty {
                Text(locManager.localized("collection.noCollections"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(collectionService.collections) { collection in
                    Toggle(collection.name, isOn: collectionBinding(itemID: item.id, collectionID: collection.id))
                }
            }
        }
    }

    private func compatibilitySection(_ item: LibraryItem) -> some View {
        CompatibilityDetailsView(itemID: item.id) { section in
            selectedSection = section
        }
    }

    private func controlsSection(_ item: LibraryItem) -> some View {
        Section {
            Toggle(
                locManager.localized("player.virtualControls.show"),
                isOn: Binding(
                    get: { libraryService.item(with: item.id)?.showsVirtualControls ?? true },
                    set: { appState.setVirtualControls($0, for: item.id) }
                )
            )

            LabeledContent(
                locManager.localized("library.details.controls.profile"),
                value: String(format: locManager.localized("library.details.controls.actionCount"), item.inputProfile?.mapping.count ?? GameAction.allCases.count)
            )
            Button(locManager.localized("input.editor.open")) {
                showInputMappingEditor = true
            }
            #if os(iOS)
            Button(locManager.localized("touchLayout.editor.open")) {
                showTouchLayoutEditor = true
            }
            #endif
            Text(locManager.localized("input.editor.controlsNote"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text(locManager.localized("library.details.controls.title"))
        }
    }

    private func compatibilityStatusTitle(_ status: CompatibilityStatus) -> String {
        switch status {
        case .compatible:
            return locManager.localized("library.details.compatibility.status.compatible")
        case .unknown:
            return locManager.localized("library.details.compatibility.status.unknown")
        case .unsupported:
            return locManager.localized("library.details.compatibility.status.unsupported")
        }
    }

    private func compatibilityStatusIcon(_ status: CompatibilityStatus) -> String {
        switch status {
        case .compatible: return "checkmark.circle"
        case .unknown: return "questionmark.circle"
        case .unsupported: return "xmark.octagon"
        }
    }

    private func compatibilityStatusColor(_ status: CompatibilityStatus) -> Color {
        switch status {
        case .compatible: return .green
        case .unknown: return .secondary
        case .unsupported: return .red
        }
    }

    private func favoriteBinding(_ item: LibraryItem) -> Binding<Bool> {
        Binding(
            get: { libraryService.item(with: item.id)?.isFavorite ?? item.isFavorite },
            set: { isFavorite in
                guard let current = libraryService.item(with: item.id) else { return }
                if current.isFavorite != isFavorite {
                    appState.toggleFavorite(for: current.url)
                }
            }
        )
    }

    private func collectionBinding(itemID: UUID, collectionID: UUID) -> Binding<Bool> {
        Binding(
            get: { collectionService.contains(itemID, in: collectionID) },
            set: { isIncluded in
                if isIncluded {
                    collectionService.add(itemID, to: collectionID)
                } else {
                    collectionService.remove(itemID, from: collectionID)
                }
            }
        )
    }

    private func runtimeSettingsSection(_ item: LibraryItem) -> some View {
        Section(locManager.localized("library.details.runtime")) {
            Picker(locManager.localized("menu.quality"), selection: runtimeProfileBinding(\.qualityRawValue)) {
                Text(locManager.localized("library.details.runtime.useDefault")).tag(Optional<Int32>.none)
                Text(locManager.localized("menu.quality.low")).tag(Optional(RuffleQuality.low.rawValue))
                Text(locManager.localized("menu.quality.medium")).tag(Optional(RuffleQuality.medium.rawValue))
                Text(locManager.localized("menu.quality.high")).tag(Optional(RuffleQuality.high.rawValue))
                Text(locManager.localized("menu.quality.best")).tag(Optional(RuffleQuality.best.rawValue))
            }

            Picker(locManager.localized("settings.general.playback.letterbox"), selection: runtimeProfileBinding(\.letterbox)) {
                Text(locManager.localized("library.details.runtime.useDefault")).tag(Optional<String>.none)
                Text(locManager.localized("settings.general.playback.letterbox.fullscreen")).tag(Optional("fullscreen"))
                Text(locManager.localized("settings.general.playback.letterbox.on")).tag(Optional("on"))
                Text(locManager.localized("settings.general.playback.letterbox.off")).tag(Optional("off"))
            }

            Picker(locManager.localized("settings.general.playback.loop"), selection: runtimeProfileBinding(\.isLooping)) {
                Text(locManager.localized("library.details.runtime.useDefault")).tag(Optional<Bool>.none)
                Text(locManager.localized("player.loop.on")).tag(Optional(true))
                Text(locManager.localized("player.loop.off")).tag(Optional(false))
            }

            Picker(locManager.localized("settings.general.playback.autoplay"), selection: runtimeProfileBinding(\.autoplay)) {
                Text(locManager.localized("library.details.runtime.useDefault")).tag(Optional<Bool>.none)
                Text(locManager.localized("player.loop.on")).tag(Optional(true))
                Text(locManager.localized("player.loop.off")).tag(Optional(false))
            }

            Toggle(locManager.localized("settings.general.playback.speed"), isOn: speedOverrideBinding)
            if runtimeProfile.playbackSpeed != nil {
                Slider(value: speedBinding, in: 0.25...4.0, step: 0.25)
                Text(String(format: "%.2fx", runtimeProfile.playbackSpeed ?? 1.0))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Toggle(locManager.localized("settings.advanced.actionscript.maxDuration"), isOn: executionDurationOverrideBinding)
            if runtimeProfile.maxExecutionDuration != nil {
                Slider(value: executionDurationBinding, in: 5...60, step: 1)
                Text(String(format: locManager.localized("settings.advanced.actionscript.secondsFormat"), Int(runtimeProfile.maxExecutionDuration ?? 15)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if item.url == appState.currentFileURL {
                Button(locManager.localized("menu.reload")) {
                    appState.retryCurrentFile()
                }
            }
            Text(locManager.localized("library.details.runtime.reloadRequired"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(locManager.localized("library.details.runtime.reset"), role: .destructive) {
                libraryService.resetRuntimeProfile(for: itemID)
                appState.applyRuntimeProfile(for: itemID)
            }
            .disabled(runtimeProfile.isEmpty)
        }
    }

    private func permissionSettingsSection(_ item: LibraryItem) -> some View {
        Section(locManager.localized("library.details.permissions")) {
            ForEach(PermissionScope.allCases) { scope in
                Picker(permissionScopeTitle(scope), selection: permissionBinding(item.url, scope: scope)) {
                    Text(locManager.localized("permission.decision.useGlobalDefault")).tag(PermissionDecision.useGlobalDefault)
                    Text(locManager.localized("permission.decision.allowForFile")).tag(PermissionDecision.allowForFile)
                    Text(locManager.localized("permission.decision.denyForFile")).tag(PermissionDecision.denyForFile)
                }
            }
            Text(locManager.localized("library.details.permissions.p1bNote"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var runtimeProfile: FileRuntimeProfile {
        libraryService.item(with: itemID)?.runtimeProfile ?? FileRuntimeProfile()
    }

    private func runtimeProfileBinding<Value>(_ keyPath: WritableKeyPath<FileRuntimeProfile, Value>) -> Binding<Value> {
        Binding(
            get: { runtimeProfile[keyPath: keyPath] },
            set: { value in updateRuntimeProfile { $0[keyPath: keyPath] = value } }
        )
    }

    private var speedOverrideBinding: Binding<Bool> {
        Binding(
            get: { runtimeProfile.playbackSpeed != nil },
            set: { enabled in
                updateRuntimeProfile { $0.playbackSpeed = enabled ? SettingsPersistence.shared.speed : nil }
            }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { Double(runtimeProfile.playbackSpeed ?? SettingsPersistence.shared.speed) },
            set: { value in updateRuntimeProfile { $0.playbackSpeed = Float(value) } }
        )
    }

    private var executionDurationOverrideBinding: Binding<Bool> {
        Binding(
            get: { runtimeProfile.maxExecutionDuration != nil },
            set: { enabled in
                updateRuntimeProfile { $0.maxExecutionDuration = enabled ? SettingsPersistence.shared.maxExecutionDuration : nil }
            }
        )
    }

    private var executionDurationBinding: Binding<Double> {
        Binding(
            get: { runtimeProfile.maxExecutionDuration ?? SettingsPersistence.shared.maxExecutionDuration },
            set: { value in updateRuntimeProfile { $0.maxExecutionDuration = value } }
        )
    }

    private func updateRuntimeProfile(_ changes: (inout FileRuntimeProfile) -> Void) {
        var profile = runtimeProfile
        changes(&profile)
        libraryService.update(itemID) { $0.runtimeProfile = profile.isEmpty ? nil : profile }
        appState.applyRuntimeProfile(for: itemID)
    }

    private func permissionBinding(_ url: URL, scope: PermissionScope) -> Binding<PermissionDecision> {
        Binding(
            get: { permissionPolicyService.override(for: url, scope: scope)?.decision ?? .useGlobalDefault },
            set: { _ = permissionPolicyService.apply($0, for: url, scope: scope) }
        )
    }

    private func permissionScopeTitle(_ scope: PermissionScope) -> String {
        switch scope {
        case .network:
            locManager.localized("permission.scope.network")
        case .filesystem:
            locManager.localized("permission.scope.filesystem")
        }
    }

    private func loadDraft() {
        guard let item = libraryService.item(with: itemID) else { return }
        tagsText = item.tags.joined(separator: ", ")
        notesText = item.notes
    }

    private func saveDraft() {
        saveTags()
        saveNotes()
    }

    private func saveTags() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        let uniqueTags = tags.filter { seen.insert($0.lowercased()).inserted }
        libraryService.update(itemID) { $0.tags = uniqueTags }
    }

    private func saveNotes() {
        libraryService.update(itemID) { $0.notes = notesText.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
