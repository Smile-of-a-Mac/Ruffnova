import SwiftUI
import UniformTypeIdentifiers

struct AutomaticBackupSection: View {
    let libraryID: UUID

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locManager: LocalizationManager

    @State private var snapshots = [SharedObjectSnapshot]()
    @State private var snapshotToRestore: SharedObjectSnapshot?
    @State private var exportDocument: GameStorageFile?
    @State private var exportName = "backup.json"
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: NativeSpacing.md) {
            Text(locManager.localized("storage.automatic.title"))
                .font(.headline)

            Toggle(
                locManager.localized("storage.automatic.enabled"),
                isOn: Binding(
                    get: { appState.isAutomaticBackupEnabled(for: libraryID) },
                    set: { enabled in
                        appState.setAutomaticBackupEnabled(enabled, for: libraryID)
                        Task { await reload() }
                    }
                )
            )

            if snapshots.isEmpty {
                Text(locManager.localized("storage.automatic.none"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshots) { snapshot in
                    HStack(spacing: NativeSpacing.sm) {
                        VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                            Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                            Text(ByteCountFormatter.string(fromByteCount: snapshot.totalBytes, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            snapshotToRestore = snapshot
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .accessibilityLabel(locManager.localized("storage.automatic.restore"))

                        Button {
                            export(snapshot)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(locManager.localized("storage.automatic.export"))

                        Button(role: .destructive) {
                            delete(snapshot)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(locManager.localized("storage.automatic.delete"))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .task(id: "\(libraryID.uuidString)-\(appState.automaticBackupRefreshToken)") {
            await reload()
        }
        .alert(
            locManager.localized("storage.automatic.restore.confirmTitle"),
            isPresented: Binding(
                get: { snapshotToRestore != nil },
                set: { if !$0 { snapshotToRestore = nil } }
            )
        ) {
            Button(locManager.localized("storage.automatic.restore"), role: .destructive) {
                if let snapshot = snapshotToRestore {
                    restore(snapshot)
                }
                snapshotToRestore = nil
            }
            Button(locManager.localized("collection.cancel"), role: .cancel) {
                snapshotToRestore = nil
            }
        } message: {
            Text(locManager.localized("storage.automatic.restore.confirmMessage"))
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportName
        ) { result in
            if case .failure = result {
                errorMessage = locManager.localized("storage.error.export")
            }
            exportDocument = nil
        }
        .alert(
            locManager.localized("storage.title"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(locManager.localized("menu.close"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func reload() async {
        snapshots = await AutomaticBackupService.shared.automaticSnapshots(for: libraryID)
    }

    private func restore(_ snapshot: SharedObjectSnapshot) {
        Task {
            do {
                try await appState.restoreAutomaticSharedObjectSnapshot(snapshot)
                await reload()
            } catch {
                errorMessage = locManager.localized("storage.slot.error.restore")
            }
        }
    }

    private func delete(_ snapshot: SharedObjectSnapshot) {
        Task {
            do {
                try await AutomaticBackupService.shared.delete(snapshot)
                await reload()
            } catch {
                errorMessage = locManager.localized("storage.error.delete")
            }
        }
    }

    private func export(_ snapshot: SharedObjectSnapshot) {
        Task {
            do {
                exportDocument = GameStorageFile(data: try await AutomaticBackupService.shared.exportData(for: snapshot))
                exportName = "backup-\(snapshot.createdAt.formatted(.dateTime.year().month().day().hour().minute())).json"
            } catch {
                errorMessage = locManager.localized("storage.error.export")
            }
        }
    }
}
