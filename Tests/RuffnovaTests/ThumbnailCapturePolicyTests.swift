import XCTest
@testable import Ruffnova

final class ThumbnailCapturePolicyTests: XCTestCase {
    func testAttemptsCaptureWhenNoThumbnailExists() {
        XCTAssertTrue(ThumbnailCapturePolicy.shouldAttempt(thumbnailIdentifier: nil))
        XCTAssertTrue(ThumbnailCapturePolicy.shouldAttempt(thumbnailIdentifier: ""))
    }

    func testSkipsCaptureWhenThumbnailExists() {
        XCTAssertFalse(ThumbnailCapturePolicy.shouldAttempt(thumbnailIdentifier: "item-id.png"))
    }

    func testCenteredCoverCropForWideImage() {
        let crop = ThumbnailCapturePolicy.centeredCoverCrop(
            imageSize: CGSize(width: 1600, height: 900),
            aspectRatio: ThumbnailCapturePolicy.coverAspectRatio
        )

        XCTAssertEqual(crop.origin.x, 200)
        XCTAssertEqual(crop.origin.y, 0)
        XCTAssertEqual(crop.size.width, 1200)
        XCTAssertEqual(crop.size.height, 900)
    }

    func testCenteredCoverCropForTallImage() {
        let crop = ThumbnailCapturePolicy.centeredCoverCrop(
            imageSize: CGSize(width: 900, height: 1600),
            aspectRatio: ThumbnailCapturePolicy.coverAspectRatio
        )

        XCTAssertEqual(crop.origin.x, 0)
        XCTAssertEqual(crop.origin.y, 462.5)
        XCTAssertEqual(crop.size.width, 900)
        XCTAssertEqual(crop.size.height, 675)
    }
}
