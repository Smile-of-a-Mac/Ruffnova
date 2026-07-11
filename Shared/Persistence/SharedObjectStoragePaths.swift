import Foundation

struct SharedObjectStoragePaths {
    let rootURL: URL

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
}
