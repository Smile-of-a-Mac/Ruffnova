import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

final class DiagnosticsService {
    static let shared = DiagnosticsService()

    private init() {}

    func makeReport(
        fileURL: URL?,
        fileSize: Int64,
        metadata: SWFMetadata?,
        currentFrame: UInt32,
        issues: [PlayerIssue],
        permissionPolicy: String,
        traceMessages: [String],
        appVersion: String? = DiagnosticsService.appVersion,
        engineVersion: String? = nil,
        generatedAt: Date = Date()
    ) -> CompatibilityReport {
        CompatibilityReport(
            generatedAt: generatedAt,
            fileName: fileURL?.lastPathComponent ?? "-",
            filePath: fileURL?.path ?? "-",
            fileSize: fileSize,
            appVersion: appVersion,
            engineVersion: engineVersion,
            metadata: metadata,
            currentFrame: currentFrame,
            issues: issues,
            permissionPolicy: permissionPolicy,
            traceSummary: traceSummary(from: traceMessages)
        )
    }

    func traceSummary(from messages: [String], maxEntries: Int = 10) -> [String] {
        Array(messages.suffix(maxEntries))
    }

    func copyReport(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }

    private static var appVersion: String? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (version, build) {
        case let (version?, build?) where !build.isEmpty:
            return "\(version) (\(build))"
        case let (version?, _):
            return version
        default:
            return nil
        }
    }
}
