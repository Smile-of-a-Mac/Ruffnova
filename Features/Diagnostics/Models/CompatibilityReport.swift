import Foundation

struct CompatibilityReport: Equatable {
    var generatedAt: Date
    var fileName: String
    var filePath: String
    var fileSize: Int64
    var appVersion: String?
    var engineVersion: String?
    var metadata: SWFMetadata?
    var currentFrame: UInt32
    var issues: [PlayerIssue]
    var permissionPolicy: String
    var traceSummary: [String]

    func plainText(localize: (String) -> String) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        var lines: [String] = []
        lines.append(localize("diagnostics.report.title"))
        lines.append("\(localize("diagnostics.report.generatedAt")): \(Self.dateFormatter.string(from: generatedAt))")
        lines.append("")
        lines.append("\(localize("diagnostics.report.fileName")): \(fileName)")
        lines.append("\(localize("diagnostics.report.path")): \(filePath)")
        lines.append("\(localize("diagnostics.report.fileSize")): \(formatter.string(fromByteCount: fileSize))")
        lines.append("\(localize("diagnostics.report.appVersion")): \(appVersion ?? localize("diagnostics.unavailable"))")
        lines.append("\(localize("diagnostics.report.engineVersion")): \(engineVersion ?? localize("diagnostics.unavailable"))")
        lines.append("\(localize("diagnostics.report.permissionPolicy")): \(permissionPolicy)")
        lines.append("")
        appendPlaybackLines(to: &lines, localize: localize)
        appendIssueLines(to: &lines, localize: localize)
        appendTraceLines(to: &lines, localize: localize)
        return lines.joined(separator: "\n")
    }

    private func appendPlaybackLines(to lines: inout [String], localize: (String) -> String) {
        lines.append(localize("diagnostics.report.playback"))
        if let metadata {
            if metadata.hasStageSize {
                lines.append("\(localize("diagnostics.report.stageDimensions")): \(metadata.stageWidth) x \(metadata.stageHeight)")
            } else {
                lines.append("\(localize("diagnostics.report.stageDimensions")): \(localize("diagnostics.unavailable"))")
            }
            lines.append("\(localize("diagnostics.report.frameRate")): \(metadata.hasFrameRate ? String(format: "%.1f", metadata.frameRate) : localize("diagnostics.unavailable"))")
            lines.append("\(localize("diagnostics.report.totalFrames")): \(metadata.hasTotalFrames ? String(metadata.totalFrames) : localize("diagnostics.unavailable"))")
        } else {
            lines.append("\(localize("diagnostics.report.stageDimensions")): \(localize("diagnostics.unavailable"))")
            lines.append("\(localize("diagnostics.report.frameRate")): \(localize("diagnostics.unavailable"))")
            lines.append("\(localize("diagnostics.report.totalFrames")): \(localize("diagnostics.unavailable"))")
        }
        lines.append("\(localize("diagnostics.report.currentFrame")): \(currentFrame)")
        lines.append("")
    }

    private func appendIssueLines(to lines: inout [String], localize: (String) -> String) {
        lines.append(localize("diagnostics.report.issues"))
        if issues.isEmpty {
            lines.append(localize("diagnostics.noIssues"))
        } else {
            lines.append(contentsOf: issues.map { "- \($0.displayMessage(localize: localize))" })
        }
        lines.append("")
    }

    private func appendTraceLines(to lines: inout [String], localize: (String) -> String) {
        lines.append(localize("diagnostics.report.traceSummary"))
        if traceSummary.isEmpty {
            lines.append(localize("diagnostics.noTrace"))
        } else {
            lines.append(contentsOf: traceSummary.map { "- \($0)" })
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
