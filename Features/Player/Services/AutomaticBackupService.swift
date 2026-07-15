import Foundation

enum AutomaticBackupResult: Equatable {
    case created(SharedObjectSnapshot)
    case unchanged
}

actor AutomaticBackupService {
    static let shared = AutomaticBackupService()

    private let snapshotService: SharedObjectSnapshotService
    private let retentionPolicy: AutomaticBackupRetentionPolicy

    init(
        snapshotService: SharedObjectSnapshotService = .shared,
        retentionPolicy: AutomaticBackupRetentionPolicy = AutomaticBackupRetentionPolicy()
    ) {
        self.snapshotService = snapshotService
        self.retentionPolicy = retentionPolicy
    }

    func createIfNeeded(for libraryID: UUID) throws -> AutomaticBackupResult {
        let currentEntries = try snapshotService.currentStorageEntries(for: libraryID)
        guard !currentEntries.isEmpty else { return .unchanged }

        if let latestSnapshot = snapshotService.automaticSnapshots(for: libraryID).first,
           latestSnapshot.entries == currentEntries {
            return .unchanged
        }

        let snapshot = try snapshotService.createSnapshot(for: libraryID, kind: .automatic)
        try enforceRetention(for: libraryID)
        return .created(snapshot)
    }

    func createSafetySnapshot(for libraryID: UUID) throws -> SharedObjectSnapshot {
        return try snapshotService.createSnapshot(for: libraryID, kind: .safety)
    }

    func automaticSnapshots(for libraryID: UUID) -> [SharedObjectSnapshot] {
        snapshotService.automaticSnapshots(for: libraryID)
    }

    func delete(_ snapshot: SharedObjectSnapshot) throws {
        try snapshotService.deleteAutomaticSnapshot(snapshot)
    }

    func exportData(for snapshot: SharedObjectSnapshot) throws -> Data {
        try snapshotService.exportData(for: snapshot)
    }

    func restore(_ snapshot: SharedObjectSnapshot) throws {
        guard snapshot.kind == .automatic else { throw SharedObjectSnapshotError.invalidSnapshot }
        _ = try createSafetySnapshot(for: snapshot.libraryID)
        try snapshotService.restore(snapshot: snapshot)
    }

    private func enforceRetention(for libraryID: UUID) throws {
        let automaticSnapshots = snapshotService.automaticSnapshots(for: libraryID)
        let references = automaticSnapshots.map(AutomaticBackupSnapshotReference.init)
        let deletionIDs = retentionPolicy.deletionCandidates(from: references, now: Date())
        try deleteAutomaticSnapshots(with: deletionIDs, from: automaticSnapshots)

        let allSnapshots = snapshotService.allSnapshots()
        let allReferences = allSnapshots.map(AutomaticBackupSnapshotReference.init)
        let globalDeletionIDs = retentionPolicy.globalLimitDeletionCandidates(from: allReferences)
        try deleteAutomaticSnapshots(with: globalDeletionIDs, from: allSnapshots)
    }

    private func deleteAutomaticSnapshots(
        with ids: [UUID],
        from snapshots: [SharedObjectSnapshot]
    ) throws {
        let snapshotsByID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        for id in ids {
            guard let snapshot = snapshotsByID[id] else { continue }
            try snapshotService.deleteAutomaticSnapshot(snapshot)
        }
    }
}

private extension AutomaticBackupSnapshotReference {
    init(snapshot: SharedObjectSnapshot) {
        self.init(
            id: snapshot.id,
            createdAt: snapshot.createdAt,
            totalBytes: snapshot.totalBytes,
            kind: snapshot.kind
        )
    }
}
