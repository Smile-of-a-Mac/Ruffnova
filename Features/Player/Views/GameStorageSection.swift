import SwiftUI
import UniformTypeIdentifiers

struct GameStorageFile: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct GameStorageSection: View {
    let libraryID: UUID
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locManager: LocalizationManager

    @State private var entries = [GameStorageEntry]()
    @State private var usage: GameStorageUsage?
    @State private var snapshots = [SharedObjectSlot: SharedObjectSnapshot]()
    @State private var pendingImportName: String?
    @State private var exportDocument: GameStorageFile?
    @State private var exportName = "save.sol"
    @State private var showImporter = false
    @State private var showClearConfirmation = false
    @State private var restoreSlot: SharedObjectSlot?
    @State private var errorMessage: String?

    var body: some View {
        Section(locManager.localized("storage.title")) {
            if let usage {
                LabeledContent(locManager.localized("storage.usage")) {
                    Text("\(ByteCountFormatter.string(fromByteCount: usage.usedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: usage.quotaBytes, countStyle: .file))")
                        .monospacedDigit()
                }
            }

            ForEach(SharedObjectSlot.allCases) { slot in
                let snapshot = snapshots[slot]
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: locManager.localized("storage.slot"), slot.rawValue))
                        Text(snapshot.map { $0.createdAt.formatted(date: .abbreviated, time: .shortened) } ?? locManager.localized("storage.slot.empty"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(locManager.localized(snapshot == nil ? "storage.slot.save" : "storage.slot.overwrite")) { save(to: slot) }
                    if snapshot != nil {
                        Button(locManager.localized("storage.slot.restore")) { restoreSlot = slot }
                    }
                }
            }

            AutomaticBackupSection(libraryID: libraryID)

            if entries.isEmpty {
                Text(locManager.localized("storage.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .lineLimit(1)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(entry.size), countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(locManager.localized("storage.export")) { export(entry) }
                        Button(locManager.localized("storage.import")) { pendingImportName = entry.name; showImporter = true }
                        Button(role: .destructive) { delete(entry) } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(locManager.localized("storage.delete"))
                    }
                }

                Button(locManager.localized("storage.clearAll"), role: .destructive) {
                    showClearConfirmation = true
                }
            }
        }
        .task(id: libraryID) { reload() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data]) { result in
            guard let name = pendingImportName else { return }
            defer { pendingImportName = nil }
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try appState.importSharedObjectStorage(Data(contentsOf: url), named: name, for: libraryID)
                reload()
            } catch {
                errorMessage = locManager.localized("storage.error.import")
            }
        }
        .fileExporter(isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }), document: exportDocument, contentType: .data, defaultFilename: exportName) { result in
            if case .failure = result { errorMessage = locManager.localized("storage.error.export") }
            exportDocument = nil
        }
        .alert(locManager.localized("storage.slot.restore.confirmTitle"), isPresented: Binding(get: { restoreSlot != nil }, set: { if !$0 { restoreSlot = nil } })) {
            Button(locManager.localized("storage.slot.restore"), role: .destructive) {
                if let slot = restoreSlot {
                    restore(slot)
                }
                restoreSlot = nil
            }
            Button(locManager.localized("collection.cancel"), role: .cancel) { restoreSlot = nil }
        } message: {
            Text(locManager.localized("storage.slot.restore.confirmMessage"))
        }
        .alert(locManager.localized("storage.clear.confirmTitle"), isPresented: $showClearConfirmation) {
            Button(locManager.localized("storage.clear"), role: .destructive) {
                clearAll()
            }
            Button(locManager.localized("collection.cancel"), role: .cancel) {}
        } message: {
            Text(locManager.localized("storage.clear.confirmMessage"))
        }
        .alert(locManager.localized("storage.title"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save(to slot: SharedObjectSlot) {
        do {
            try appState.saveSharedObjectStorage(to: slot, for: libraryID)
            reload()
        } catch {
            errorMessage = locManager.localized("storage.slot.error.save")
        }
    }

    private func restore(_ slot: SharedObjectSlot) {
        do {
            try appState.restoreSharedObjectSlot(slot, for: libraryID)
            reload()
        } catch {
            errorMessage = locManager.localized("storage.slot.error.restore")
        }
    }

    private func reload() {
        do {
            entries = try GameStorageService.shared.entries(for: libraryID)
            usage = try GameStorageService.shared.usage(for: libraryID)
            snapshots = SharedObjectSlot.allCases.reduce(into: [:]) { result, slot in
                if let snapshot = try? SharedObjectSnapshotService.shared.snapshot(in: slot, for: libraryID) {
                    result[slot] = snapshot
                }
            }
        } catch {
            entries = []
            usage = nil
            snapshots = [:]
            errorMessage = locManager.localized("storage.error.load")
        }
    }

    private func export(_ entry: GameStorageEntry) {
        do {
            exportDocument = GameStorageFile(data: try GameStorageService.shared.read(entry.name, for: libraryID))
            exportName = entry.name.replacingOccurrences(of: "/", with: "-") + ".sol"
        } catch {
            errorMessage = locManager.localized("storage.error.export")
        }
    }

    private func delete(_ entry: GameStorageEntry) {
        do {
            try appState.deleteSharedObjectStorage(named: entry.name, for: libraryID)
            reload()
        } catch {
            errorMessage = locManager.localized("storage.error.delete")
        }
    }

    private func clearAll() {
        do {
            try appState.clearSharedObjectStorage(for: libraryID)
            reload()
        } catch {
            errorMessage = locManager.localized("storage.error.delete")
        }
    }
}
