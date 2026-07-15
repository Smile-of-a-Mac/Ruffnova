import Foundation

struct SharedObjectSnapshot: Identifiable, Equatable {
    let id: UUID
    let libraryID: UUID
    let createdAt: Date
    let totalBytes: Int64
    let entries: [SharedObjectSnapshotEntry]
    let kind: SharedObjectSnapshotKind
    let directoryURL: URL
}

enum SharedObjectSnapshotKind: String, Codable, Equatable {
    case automatic
    case namedSlot
    case safety
}

struct SharedObjectSnapshotEntry: Codable, Equatable, Identifiable {
    let name: String
    let byteCount: Int64
    let sha256: String

    var id: String { name }
}

struct SharedObjectSnapshotManifest: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: UUID
    let libraryID: UUID
    let createdAt: Date
    let totalBytes: Int64
    let entries: [SharedObjectSnapshotEntry]
    let kind: SharedObjectSnapshotKind?
}

enum SharedObjectSlot: String, Codable, CaseIterable, Identifiable {
    case one
    case two
    case three

    var id: String { rawValue }
}

struct SharedObjectSlotAssignments: Codable, Equatable {
    var snapshots: [SharedObjectSlot: UUID]

    init(snapshots: [SharedObjectSlot: UUID] = [:]) {
        self.snapshots = snapshots
    }
}

enum SharedObjectSnapshotError: Error, Equatable {
    case unavailable
    case invalidSnapshot
    case verificationFailed
    case slotIsEmpty
    case rollbackFailed
}
