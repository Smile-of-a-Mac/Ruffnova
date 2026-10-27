import XCTest
@testable import Ruffnova

@MainActor
final class PlaybackMetricsTests: XCTestCase {
    func testFormattedTimesDeriveFromFrameRate() {
        let metrics = PlaybackMetrics()
        metrics.frameRate = 30
        metrics.currentFrame = 30 * 65
        metrics.totalFrames = 30 * 120

        XCTAssertEqual(metrics.formattedCurrentTime, "1:05")
        XCTAssertEqual(metrics.formattedTotalTime, "2:00")
    }

    func testResetClearsTimelineState() {
        let metrics = PlaybackMetrics()
        metrics.currentFrame = 42
        metrics.totalFrames = 100
        metrics.frameRate = 12
        metrics.seekPosition = 42

        metrics.reset()

        XCTAssertEqual(metrics.currentFrame, 0)
        XCTAssertEqual(metrics.totalFrames, 0)
        XCTAssertEqual(metrics.frameRate, 30)
        XCTAssertEqual(metrics.seekPosition, 0)
    }

    func testFormattedTimeIsClampedWhenFrameRateIsUnknown() {
        let metrics = PlaybackMetrics()
        metrics.frameRate = 0
        metrics.currentFrame = 30

        XCTAssertEqual(metrics.formattedCurrentTime, "0:00")
    }
}
