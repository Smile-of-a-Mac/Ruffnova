import XCTest
@testable import Ruffnova

final class FileRuntimeProfileTests: XCTestCase {
    func testUsesApplicationDefaultsWhenNoOverridesExist() {
        let defaults = RuntimeDefaults(
            quality: .medium,
            letterbox: "on",
            playbackSpeed: 1.5,
            isLooping: true,
            autoplay: false,
            maxExecutionDuration: 30
        )

        let resolved = FileRuntimeProfile().resolved(using: defaults)

        XCTAssertEqual(resolved.quality, .medium)
        XCTAssertEqual(resolved.letterbox, "on")
        XCTAssertEqual(resolved.playbackSpeed, 1.5)
        XCTAssertTrue(resolved.isLooping)
        XCTAssertFalse(resolved.autoplay)
        XCTAssertEqual(resolved.maxExecutionDuration, 30)
    }

    func testAppliesOnlyConfiguredFileOverrides() {
        let defaults = RuntimeDefaults()
        let profile = FileRuntimeProfile(
            qualityRawValue: RuffleQuality.best.rawValue,
            playbackSpeed: 0.5,
            isLooping: true,
            maxExecutionDuration: 45
        )

        let resolved = profile.resolved(using: defaults)

        XCTAssertEqual(resolved.quality, .best)
        XCTAssertEqual(resolved.playbackSpeed, 0.5)
        XCTAssertTrue(resolved.isLooping)
        XCTAssertEqual(resolved.letterbox, defaults.letterbox)
        XCTAssertEqual(resolved.maxExecutionDuration, 45)
    }

    func testInvalidQualityOverrideFallsBackToApplicationDefault() {
        let defaults = RuntimeDefaults(quality: .low)
        let profile = FileRuntimeProfile(qualityRawValue: 99)

        XCTAssertEqual(profile.resolved(using: defaults).quality, .low)
    }

    func testFileAutoplayOverrideControlsMovieStart() {
        let runtimeProfile = FileRuntimeProfile(autoplay: false).resolved(using: RuntimeDefaults(autoplay: true))

        XCTAssertFalse(AppState.shouldAutoplayAfterMovieLoads(runtimeProfile))
    }

    func testLibraryItemPreservesRuntimeProfileWhenEncoded() throws {
        let profile = FileRuntimeProfile(letterbox: "off", autoplay: false)
        let item = LibraryItem(url: URL(fileURLWithPath: "/tmp/example.swf"), runtimeProfile: profile)

        let decoded = try JSONDecoder().decode(LibraryItem.self, from: JSONEncoder().encode(item))

        XCTAssertEqual(decoded.runtimeProfile, profile)
    }

    @MainActor
    func testLibraryItemPersistsVirtualControlsPreference() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let thumbnailDirectory = directory.appendingPathComponent("Thumbnails")
        let service = LibraryService(
            directory: directory,
            thumbnailService: ThumbnailService(cacheDirectory: thumbnailDirectory)
        )
        let item = LibraryItem(
            url: directory.appendingPathComponent("game.swf"),
            showsVirtualControls: false
        )
        service.add(item)

        let reloaded = LibraryService(
            directory: directory,
            thumbnailService: ThumbnailService(cacheDirectory: thumbnailDirectory)
        )

        XCTAssertEqual(reloaded.item(with: item.id)?.showsVirtualControls, false)
    }

    @MainActor
    func testResettingFileRuntimeProfileRestoresApplicationDefaults() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = LibraryService(
            directory: directory,
            thumbnailService: ThumbnailService(cacheDirectory: directory.appendingPathComponent("Thumbnails"))
        )
        let item = LibraryItem(
            url: directory.appendingPathComponent("game.swf"),
            runtimeProfile: FileRuntimeProfile(playbackSpeed: 2.0, isLooping: true)
        )
        service.add(item)

        service.resetRuntimeProfile(for: item.id)

        XCTAssertNil(service.item(with: item.id)?.runtimeProfile)
    }
}
