import Foundation

struct SharedObjectStoragePaths {
    let rootURL: URL

    var snapshotRootURL: URL {
        rootURL.deletingLastPathComponent().appendingPathComponent("SharedObjectSnapshots", isDirectory: true)
    }

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.rootURL = applicationSupport
                .appendingPathComponent("RuffleFlashPlayer", isDirectory: true)
                .appendingPathComponent("SharedObjects", isDirectory: true)
        }
    }

    func namespace(for libraryID: UUID) -> URL {
        rootURL.appendingPathComponent(libraryID.uuidString, isDirectory: true)
    }

    func snapshotNamespace(for libraryID: UUID) -> URL {
        snapshotRootURL.appendingPathComponent(libraryID.uuidString, isDirectory: true)
    }

    func snapshotStagingDirectory(for libraryID: UUID, operationID: UUID) -> URL {
        snapshotNamespace(for: libraryID)
            .appendingPathComponent(".staging", isDirectory: true)
            .appendingPathComponent(operationID.uuidString, isDirectory: true)
    }

    func snapshotDirectory(for libraryID: UUID, snapshotID: UUID) -> URL {
        snapshotNamespace(for: libraryID)
            .appendingPathComponent(snapshotID.uuidString, isDirectory: true)
    }

    func slotAssignmentsURL(for libraryID: UUID) -> URL {
        snapshotNamespace(for: libraryID).appendingPathComponent("slots.json")
    }

    func activeRestoreStagingDirectory(for libraryID: UUID, operationID: UUID) -> URL {
        rootURL.appendingPathComponent(".restore-staging-\(libraryID.uuidString)-\(operationID.uuidString)", isDirectory: true)
    }

    func activeRollbackDirectory(for libraryID: UUID, operationID: UUID) -> URL {
        rootURL.appendingPathComponent(".rollback-\(libraryID.uuidString)-\(operationID.uuidString)", isDirectory: true)
    }
}
