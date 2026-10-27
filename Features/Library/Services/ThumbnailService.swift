import Foundation
import ImageIO
import OSLog

@MainActor
final class ThumbnailService {
    static let shared = ThumbnailService()

    private final class ImageBox: NSObject {
        let image: CGImage

        init(_ image: CGImage) {
            self.image = image
        }
    }

    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.ruffnova", category: "thumbnails")
    private let memoryCache: NSCache<NSString, ImageBox> = {
        let cache = NSCache<NSString, ImageBox>()
        cache.countLimit = 256
        cache.totalCostLimit = 64 * 1_024 * 1_024
        return cache
    }()

    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.init(cacheDirectory: appSupport
            .appendingPathComponent("RuffleFlashPlayer")
            .appendingPathComponent("Thumbnails"))
    }

    init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func store(_ data: Data, for itemID: UUID) -> String? {
        guard isReadableImage(data) else { return nil }

        let identifier = "\(itemID.uuidString).png"
        let url = cacheDirectory.appendingPathComponent(identifier)
        do {
            try data.write(to: url, options: .atomic)
            memoryCache.removeObject(forKey: identifier as NSString)
            return identifier
        } catch {
            logger.error("Failed to store thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    /// Returns a decoded thumbnail without blocking the main actor. Disk reads and
    /// image decoding happen off the main thread and results are cached in memory.
    func image(for identifier: String?, fallbackData: Data? = nil) async -> CGImage? {
        guard let identifier, !identifier.isEmpty else {
            guard let fallbackData else { return nil }
            return await Self.decode(fallbackData)
        }

        if let cached = memoryCache.object(forKey: identifier as NSString) {
            return cached.image
        }

        let url = cacheDirectory.appendingPathComponent(identifier)
        let diskData = await Task.detached(priority: .utility) {
            try? Data(contentsOf: url, options: .mappedIfSafe)
        }.value

        guard let data = diskData ?? fallbackData, let image = await Self.decode(data) else {
            return nil
        }
        memoryCache.setObject(
            ImageBox(image),
            forKey: identifier as NSString,
            cost: image.bytesPerRow * image.height
        )
        return image
    }

    func remove(_ identifier: String?) {
        guard let identifier, !identifier.isEmpty else { return }
        memoryCache.removeObject(forKey: identifier as NSString)
        let url = cacheDirectory.appendingPathComponent(identifier)
        try? fileManager.removeItem(at: url)
    }

    private func isReadableImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0
    }

    private nonisolated static func decode(_ data: Data) async -> CGImage? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            )
        }.value
    }
}
