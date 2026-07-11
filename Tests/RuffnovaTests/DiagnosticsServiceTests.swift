import XCTest
@testable import Ruffnova

final class DiagnosticsServiceTests: XCTestCase {
    func testReportTextIncludesFilePlaybackIssueAndTraceSummary() {
        let url = URL(fileURLWithPath: "/tmp/game.swf")
        let metadata = SWFMetadata(stageWidth: 640, stageHeight: 480, frameRate: 24, totalFrames: 120)
        let report = DiagnosticsService.shared.makeReport(
            fileURL: url,
            fileSize: 2048,
            metadata: metadata,
            currentFrame: 12,
            issues: [.fileMissing, .ruffleLoadFailure],
            permissionPolicy: "Default sandbox policy",
            traceMessages: ["first", "second"],
            appVersion: "1.0 (5)",
            engineVersion: "Ruffle 1",
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        let text = report.plainText(localize: Self.localize)

        XCTAssertTrue(text.contains("Compatibility Report"))
        XCTAssertTrue(text.contains("File Name: game.swf"))
        XCTAssertTrue(text.contains("Stage Dimensions: 640 x 480"))
        XCTAssertTrue(text.contains("Current Frame: 12"))
        XCTAssertTrue(text.contains("- File not found"))
        XCTAssertTrue(text.contains("- Ruffle failed to load the SWF"))
        XCTAssertTrue(text.contains("- second"))
    }

    func testTraceSummaryKeepsMostRecentEntries() {
        let messages = (1...12).map { "trace \($0)" }

        let summary = DiagnosticsService.shared.traceSummary(from: messages, maxEntries: 3)

        XCTAssertEqual(summary, ["trace 10", "trace 11", "trace 12"])
    }

    func testReportRedactsAbsoluteFilePathsAndURLSecrets() {
        let report = DiagnosticsService.shared.makeReport(
            fileURL: URL(fileURLWithPath: "/Users/alice/Documents/private/game.swf"),
            fileSize: 0,
            metadata: nil,
            currentFrame: 0,
            issues: [],
            permissionPolicy: "network: deny",
            traceMessages: ["Policy 1 https://user:password@example.com/path?token=secret"]
        )

        XCTAssertEqual(report.filePath, "game.swf")
        XCTAssertFalse(report.traceSummary.joined().contains("password"))
        XCTAssertFalse(report.traceSummary.joined().contains("token=secret"))
    }

    private static func localize(_ key: String) -> String {
        [
            "diagnostics.report.title": "Compatibility Report",
            "diagnostics.report.generatedAt": "Generated At",
            "diagnostics.report.fileName": "File Name",
            "diagnostics.report.path": "Path",
            "diagnostics.report.fileSize": "File Size",
            "diagnostics.report.appVersion": "App Version",
            "diagnostics.report.engineVersion": "Engine Version",
            "diagnostics.report.permissionPolicy": "Permission Policy",
            "diagnostics.report.playback": "Playback",
            "diagnostics.report.stageDimensions": "Stage Dimensions",
            "diagnostics.report.frameRate": "Frame Rate",
            "diagnostics.report.totalFrames": "Total Frames",
            "diagnostics.report.currentFrame": "Current Frame",
            "diagnostics.report.issues": "Issues",
            "diagnostics.report.traceSummary": "Trace Summary",
            "diagnostics.issue.fileMissing": "File not found",
            "diagnostics.issue.ruffleLoadFailure": "Ruffle failed to load the SWF",
            "diagnostics.noIssues": "No known issues",
            "diagnostics.noTrace": "No trace messages",
            "diagnostics.unavailable": "Unavailable",
        ][key] ?? key
    }
}
