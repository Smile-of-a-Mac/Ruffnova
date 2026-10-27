import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Ruffnova

@MainActor
final class ThumbnailServiceTests: XCTestCase {
    func testDecodedThumbnailIsServedFromMemoryCache() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = ThumbnailService(cacheDirectory: directory)
        let identifier = try XCTUnwrap(service.store(makePNG(), for: UUID()))

        let decoded = await service.image(for: identifier)
        XCTAssertNotNil(decoded)

        // The cache serves the decoded image even after the disk copy disappears.
        try FileManager.default.removeItem(
            at: directory.appendingPathComponent(identifier)
        )
        let cached = await service.image(for: identifier)
        XCTAssertNotNil(cached)
    }

    func testRemovingThumbnailClearsTheMemoryCache() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = ThumbnailService(cacheDirectory: directory)
        let identifier = try XCTUnwrap(service.store(makePNG(), for: UUID()))
        _ = await service.image(for: identifier)

        service.remove(identifier)

        let removed = await service.image(for: identifier)
        XCTAssertNil(removed)
    }

    private func makePNG() -> Data {
        let width = 4
        let height = 3
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let image = context.makeImage()
        else {
            XCTFail("Unable to create a test image")
            return Data()
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            XCTFail("Unable to create an image destination")
            return Data()
        }
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
