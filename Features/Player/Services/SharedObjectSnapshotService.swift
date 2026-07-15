import CryptoKit
import Foundation

final class SharedObjectSnapshotService {
    static let shared = SharedObjectSnapshotService()

    private let storageService: GameStorageService
    private let paths: SharedObjectStoragePaths
    private let fileManager: FileManager

    init(
        storageService: GameStorageService = .shared,
        paths: SharedObjectStoragePaths = SharedObjectStoragePaths(),
        fileManager: FileManager = .default
    ) {
        self.storageService = storageService
        self.paths = paths
        self.fileManager = fileManager
    }

    func createSnapshot(
        for libraryID: UUID,
        kind: SharedObjectSnapshotKind = .namedSlot
    ) throws -> SharedObjectSnapshot {
        let snapshotID = UUID()
        let stagingURL = paths.snapshotStagingDirectory(for: libraryID, operationID: UUID())
        let destinationURL = paths.snapshotDirectory(for: libraryID, snapshotID: snapshotID)

        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw SharedObjectSnapshotError.unavailable
        }

        do {
            try fileManager.createDirectory(
                at: stagingURL.appendingPathComponent("objects", isDirectory: true),
                withIntermediateDirectories: true
            )

            let entries = try storageService.entries(for: libraryID)
                .sorted { $0.name < $1.name }
                .map { entry -> SharedObjectSnapshotEntry in
                    let data = try storageService.read(entry.name, for: libraryID)
                    let snapshotEntry = SharedObjectSnapshotEntry(
                        name: entry.name,
                        byteCount: Int64(data.count),
                        sha256: digest(for: data)
                    )
                    try data.write(
                        to: objectURL(for: snapshotEntry, in: stagingURL),
                        options: .atomic
                    )
                    return snapshotEntry
                }

            let manifest = SharedObjectSnapshotManifest(
                schemaVersion: SharedObjectSnapshotManifest.currentSchemaVersion,
                id: snapshotID,
                libraryID: libraryID,
                createdAt: Date(),
                totalBytes: entries.reduce(0) { $0 + $1.byteCount },
                entries: entries,
                kind: kind
            )
            let manifestURL = stagingURL.appendingPathComponent("manifest.json")
            try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)

            let snapshot = try verifySnapshotDirectory(
                stagingURL,
                expectedLibraryID: libraryID,
                expectedSnapshotID: snapshotID
            )
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            return SharedObjectSnapshot(
                id: snapshot.id,
                libraryID: snapshot.libraryID,
                createdAt: snapshot.createdAt,
                totalBytes: snapshot.totalBytes,
                entries: snapshot.entries,
                kind: snapshot.kind,
                directoryURL: destinationURL
            )
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if let error = error as? SharedObjectSnapshotError {
                throw error
            }
            throw SharedObjectSnapshotError.unavailable
        }
    }

    func snapshots(for libraryID: UUID) -> [SharedObjectSnapshot] {
        let namespaceURL = paths.snapshotNamespace(for: libraryID)
        guard let directories = try? fileManager.contentsOfDirectory(
            at: namespaceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return directories.compactMap { directory in
            guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let snapshotID = UUID(uuidString: directory.lastPathComponent)
            else {
                return nil
            }
            return try? verifySnapshotDirectory(
                directory,
                expectedLibraryID: libraryID,
                expectedSnapshotID: snapshotID
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func automaticSnapshots(for libraryID: UUID) -> [SharedObjectSnapshot] {
        snapshots(for: libraryID).filter { $0.kind == .automatic }
    }

    func allSnapshots() -> [SharedObjectSnapshot] {
        guard let namespaces = try? fileManager.contentsOfDirectory(
            at: paths.snapshotRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return namespaces.reduce(into: [SharedObjectSnapshot]()) { result, namespace in
            guard (try? namespace.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let libraryID = UUID(uuidString: namespace.lastPathComponent)
            else {
                return
            }
            result.append(contentsOf: snapshots(for: libraryID))
        }
    }

    func deleteAutomaticSnapshot(_ snapshot: SharedObjectSnapshot) throws {
        let verified = try verifySnapshot(snapshot)
        guard verified.kind == .automatic else { throw SharedObjectSnapshotError.invalidSnapshot }

        do {
            try fileManager.removeItem(at: verified.directoryURL)
        } catch {
            throw SharedObjectSnapshotError.unavailable
        }
    }

    func exportData(for snapshot: SharedObjectSnapshot) throws -> Data {
        let verified = try verifySnapshot(snapshot)
        let entries = try verified.entries.map { entry in
            SharedObjectSnapshotExportEntry(
                entry: entry,
                data: try Data(contentsOf: objectURL(for: entry, in: verified.directoryURL))
            )
        }
        let export = SharedObjectSnapshotExport(
            schemaVersion: 1,
            id: verified.id,
            libraryID: verified.libraryID,
            createdAt: verified.createdAt,
            kind: verified.kind,
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    func currentStorageEntries(for libraryID: UUID) throws -> [SharedObjectSnapshotEntry] {
        try storageService.entries(for: libraryID)
            .sorted { $0.name < $1.name }
            .map { entry in
                let data = try storageService.read(entry.name, for: libraryID)
                return SharedObjectSnapshotEntry(
                    name: entry.name,
                    byteCount: Int64(data.count),
                    sha256: digest(for: data)
                )
            }
    }

    @discardableResult
    func saveCurrentStorage(to slot: SharedObjectSlot, for libraryID: UUID) throws -> SharedObjectSnapshot {
        let snapshot = try createSnapshot(for: libraryID)
        try assign(snapshot, to: slot)
        return snapshot
    }

    func assign(_ snapshot: SharedObjectSnapshot, to slot: SharedObjectSlot) throws {
        let verified = try verifySnapshot(snapshot)
        var assignments = slotAssignments(for: verified.libraryID)
        assignments.snapshots[slot] = verified.id
        let assignmentsURL = paths.slotAssignmentsURL(for: verified.libraryID)
        try fileManager.createDirectory(
            at: assignmentsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(assignments).write(to: assignmentsURL, options: .atomic)
    }

    func snapshot(in slot: SharedObjectSlot, for libraryID: UUID) throws -> SharedObjectSnapshot {
        guard let snapshotID = slotAssignments(for: libraryID).snapshots[slot] else {
            throw SharedObjectSnapshotError.slotIsEmpty
        }
        return try verifySnapshotDirectory(
            paths.snapshotDirectory(for: libraryID, snapshotID: snapshotID),
            expectedLibraryID: libraryID,
            expectedSnapshotID: snapshotID
        )
    }

    func restore(slot: SharedObjectSlot, for libraryID: UUID) throws {
        try restore(snapshot: snapshot(in: slot, for: libraryID))
    }

    func restore(snapshot: SharedObjectSnapshot) throws {
        let verified = try verifySnapshot(snapshot)
        let operationID = UUID()
        let activeURL = paths.namespace(for: verified.libraryID)
        let stagingURL = paths.activeRestoreStagingDirectory(for: verified.libraryID, operationID: operationID)
        let rollbackURL = paths.activeRollbackDirectory(for: verified.libraryID, operationID: operationID)
        var activeMovedToRollback = false

        do {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
            for entry in verified.entries {
                let data = try Data(contentsOf: objectURL(for: entry, in: verified.directoryURL))
                let destination = try activeObjectURL(for: entry.name, in: stagingURL)
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: destination, options: .atomic)
            }
            try verifyActiveDirectory(stagingURL, against: verified)

            try fileManager.createDirectory(at: activeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: activeURL.path) {
                try fileManager.moveItem(at: activeURL, to: rollbackURL)
                activeMovedToRollback = true
            }
            try fileManager.moveItem(at: stagingURL, to: activeURL)

            do {
                try verifyActiveNamespace(against: verified)
            } catch {
                try? fileManager.removeItem(at: activeURL)
                guard activeMovedToRollback else { throw error }
                do {
                    try fileManager.moveItem(at: rollbackURL, to: activeURL)
                } catch {
                    throw SharedObjectSnapshotError.rollbackFailed
                }
                throw error
            }
            if activeMovedToRollback {
                try? fileManager.removeItem(at: rollbackURL)
            }
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if activeMovedToRollback,
               !fileManager.fileExists(atPath: activeURL.path),
               fileManager.fileExists(atPath: rollbackURL.path) {
                do {
                    try fileManager.moveItem(at: rollbackURL, to: activeURL)
                } catch {
                    throw SharedObjectSnapshotError.rollbackFailed
                }
            }
            if let error = error as? SharedObjectSnapshotError {
                throw error
            }
            throw SharedObjectSnapshotError.unavailable
        }
    }

    func verifySnapshot(_ snapshot: SharedObjectSnapshot) throws -> SharedObjectSnapshot {
        try verifySnapshotDirectory(
            snapshot.directoryURL,
            expectedLibraryID: snapshot.libraryID,
            expectedSnapshotID: snapshot.id
        )
    }

    private func verifySnapshotDirectory(
        _ directoryURL: URL,
        expectedLibraryID: UUID,
        expectedSnapshotID: UUID?
    ) throws -> SharedObjectSnapshot {
        let manifestURL = directoryURL.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(SharedObjectSnapshotManifest.self, from: data),
              manifest.schemaVersion == SharedObjectSnapshotManifest.currentSchemaVersion,
              manifest.libraryID == expectedLibraryID,
              expectedSnapshotID.map({ manifest.id == $0 }) ?? true,
              manifest.entries.map(\.name).count == Set(manifest.entries.map(\.name)).count,
              manifest.entries.allSatisfy({ $0.byteCount >= 0 && !$0.sha256.isEmpty })
        else {
            throw SharedObjectSnapshotError.invalidSnapshot
        }

        let totalBytes = try manifest.entries.reduce(Int64(0)) { total, entry in
            let objectURL = objectURL(for: entry, in: directoryURL)
            guard let objectData = try? Data(contentsOf: objectURL),
                  Int64(objectData.count) == entry.byteCount,
                  digest(for: objectData) == entry.sha256
            else {
                throw SharedObjectSnapshotError.verificationFailed
            }
            return total + entry.byteCount
        }

        guard totalBytes == manifest.totalBytes else {
            throw SharedObjectSnapshotError.verificationFailed
        }

        return SharedObjectSnapshot(
            id: manifest.id,
            libraryID: manifest.libraryID,
            createdAt: manifest.createdAt,
            totalBytes: manifest.totalBytes,
            entries: manifest.entries,
            kind: manifest.kind ?? .namedSlot,
            directoryURL: directoryURL
        )
    }

    private func slotAssignments(for libraryID: UUID) -> SharedObjectSlotAssignments {
        let assignmentsURL = paths.slotAssignmentsURL(for: libraryID)
        guard let data = try? Data(contentsOf: assignmentsURL),
              let assignments = try? JSONDecoder().decode(SharedObjectSlotAssignments.self, from: data)
        else {
            return SharedObjectSlotAssignments()
        }
        return assignments
    }

    private func verifyActiveNamespace(against snapshot: SharedObjectSnapshot) throws {
        let entries = try storageService.entries(for: snapshot.libraryID)
            .sorted { $0.name < $1.name }
        guard entries.map(\.name) == snapshot.entries.map(\.name).sorted() else {
            throw SharedObjectSnapshotError.verificationFailed
        }
        for entry in snapshot.entries {
            let data = try storageService.read(entry.name, for: snapshot.libraryID)
            guard Int64(data.count) == entry.byteCount, digest(for: data) == entry.sha256 else {
                throw SharedObjectSnapshotError.verificationFailed
            }
        }
    }

    private func verifyActiveDirectory(
        _ directoryURL: URL,
        against snapshot: SharedObjectSnapshot
    ) throws {
        let expectedNames = Set(snapshot.entries.map(\.name))
        let files = try fileManager.subpathsOfDirectory(atPath: directoryURL.path)
            .filter { !$0.hasSuffix("/") }
        let actualNames = Set(files.compactMap { path -> String? in
            guard path.hasSuffix(".sol") else { return nil }
            return String(path.dropLast(4))
        })
        guard actualNames == expectedNames else {
            throw SharedObjectSnapshotError.verificationFailed
        }
        for entry in snapshot.entries {
            let data = try Data(contentsOf: try activeObjectURL(for: entry.name, in: directoryURL))
            guard Int64(data.count) == entry.byteCount, digest(for: data) == entry.sha256 else {
                throw SharedObjectSnapshotError.verificationFailed
            }
        }
    }

    private func activeObjectURL(for name: String, in namespaceURL: URL) throws -> URL {
        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            throw SharedObjectSnapshotError.invalidSnapshot
        }
        return components.dropLast().reduce(namespaceURL) { url, component in
            url.appendingPathComponent(String(component), isDirectory: true)
        }
        .appendingPathComponent("\(components.last!).sol")
    }

    private func objectURL(for entry: SharedObjectSnapshotEntry, in snapshotDirectory: URL) -> URL {
        snapshotDirectory
            .appendingPathComponent("objects", isDirectory: true)
            .appendingPathComponent(digest(for: Data(entry.name.utf8)))
    }

    private func digest(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct SharedObjectSnapshotExport: Codable {
    let schemaVersion: Int
    let id: UUID
    let libraryID: UUID
    let createdAt: Date
    let kind: SharedObjectSnapshotKind
    let entries: [SharedObjectSnapshotExportEntry]
}

private struct SharedObjectSnapshotExportEntry: Codable {
    let entry: SharedObjectSnapshotEntry
    let data: Data
}
