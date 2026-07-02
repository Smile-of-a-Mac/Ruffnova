import Foundation
import ImageIO
import OSLog

@MainActor
final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.ruffnova", category: "thumbnails")

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport
            .appendingPathComponent("RuffleFlashPlayer")
            .appendingPathComponent("Thumbnails")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func store(_ data: Data, for itemID: UUID) -> String? {
        guard isReadableImage(data) else { return nil }

        let identifier = "\(itemID.uuidString).png"
        let url = cacheDirectory.appendingPathComponent(identifier)
        do {
            try data.write(to: url, options: .atomic)
            return identifier
        } catch {
            logger.error("Failed to store thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    func data(for identifier: String?) -> Data? {
        guard let identifier, !identifier.isEmpty else { return nil }
        let url = cacheDirectory.appendingPathComponent(identifier)
        return try? Data(contentsOf: url)
    }

    func remove(_ identifier: String?) {
        guard let identifier, !identifier.isEmpty else { return }
        let url = cacheDirectory.appendingPathComponent(identifier)
        try? fileManager.removeItem(at: url)
    }

    private func isReadableImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0
    }
}
