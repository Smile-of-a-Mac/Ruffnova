import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager
    @State private var report: CompatibilityReport?
    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let report {
                Form {
                    issuesSection(report)
                    fileSection(report)
                    playbackSection(report)
                    traceSection(report)
                }
                .formStyle(.grouped)

                Divider()
                footer(report)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 520, minHeight: 520)
        .onAppear(perform: refresh)
        .onChange(of: appState.playerIssues) { _ in refresh() }
    }

    private var header: some View {
        HStack(spacing: NativeSpacing.md) {
            Image(systemName: "stethoscope")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                Text(locManager.localized("diagnostics.title"))
                    .font(.headline)
                Text(locManager.localized("diagnostics.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, NativeSpacing.xl)
        .padding(.vertical, NativeSpacing.md)
    }

    private func issuesSection(_ report: CompatibilityReport) -> some View {
        Section(locManager.localized("diagnostics.issues")) {
            if report.issues.isEmpty {
                Text(locManager.localized("diagnostics.noIssues"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(report.issues) { issue in
                    IssueRow(issue: issue)
                }
            }
        }
    }

    private func fileSection(_ report: CompatibilityReport) -> some View {
        Section(locManager.localized("diagnostics.file")) {
            ReportRow(label: locManager.localized("diagnostics.report.fileName"), value: report.fileName)
            ReportRow(label: locManager.localized("diagnostics.report.path"), value: report.filePath)
            ReportRow(label: locManager.localized("diagnostics.report.fileSize"), value: fileSizeString(report.fileSize))
            ReportRow(label: locManager.localized("diagnostics.report.appVersion"), value: report.appVersion ?? locManager.localized("diagnostics.unavailable"))
            ReportRow(label: locManager.localized("diagnostics.report.engineVersion"), value: report.engineVersion ?? locManager.localized("diagnostics.unavailable"))
            ReportRow(label: locManager.localized("diagnostics.report.permissionPolicy"), value: report.permissionPolicy)
        }
    }

    private func playbackSection(_ report: CompatibilityReport) -> some View {
        Section(locManager.localized("diagnostics.report.playback")) {
            if let metadata = report.metadata {
                ReportRow(
                    label: locManager.localized("diagnostics.report.stageDimensions"),
                    value: metadata.hasStageSize ? "\(metadata.stageWidth) x \(metadata.stageHeight)" : locManager.localized("diagnostics.unavailable")
                )
                ReportRow(
                    label: locManager.localized("diagnostics.report.frameRate"),
                    value: metadata.hasFrameRate ? String(format: "%.1f", metadata.frameRate) : locManager.localized("diagnostics.unavailable")
                )
                ReportRow(
                    label: locManager.localized("diagnostics.report.totalFrames"),
                    value: metadata.hasTotalFrames ? String(metadata.totalFrames) : locManager.localized("diagnostics.unavailable")
                )
            } else {
                ReportRow(label: locManager.localized("diagnostics.report.stageDimensions"), value: locManager.localized("diagnostics.unavailable"))
                ReportRow(label: locManager.localized("diagnostics.report.frameRate"), value: locManager.localized("diagnostics.unavailable"))
                ReportRow(label: locManager.localized("diagnostics.report.totalFrames"), value: locManager.localized("diagnostics.unavailable"))
            }
            ReportRow(label: locManager.localized("diagnostics.report.currentFrame"), value: String(report.currentFrame))
        }
    }

    private func traceSection(_ report: CompatibilityReport) -> some View {
        Section {
            DisclosureGroup(locManager.localized("diagnostics.report.traceSummary")) {
                if report.traceSummary.isEmpty {
                    Text(locManager.localized("diagnostics.noTrace"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.traceSummary, id: \.self) { message in
                        Text(message)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func footer(_ report: CompatibilityReport) -> some View {
        HStack {
            Text(didCopy ? locManager.localized("diagnostics.copied") : locManager.localized("diagnostics.copyHelp"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                DiagnosticsService.shared.copyReport(report.plainText { locManager.localized($0) })
                didCopy = true
            } label: {
                Label(locManager.localized("diagnostics.copyReport"), systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
        .padding(.horizontal, NativeSpacing.xl)
        .padding(.vertical, NativeSpacing.md)
    }

    private func refresh() {
        report = appState.makeCompatibilityReport()
        didCopy = false
    }

    private func fileSizeString(_ fileSize: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

private struct IssueRow: View {
    @EnvironmentObject var locManager: LocalizationManager
    let issue: PlayerIssue

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                Text(issue.displayMessage { locManager.localized($0) })
                if let key = issue.recoverySuggestionKey {
                    Text(locManager.localized(key))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.yellow)
        }
    }
}

private struct ReportRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label, value: value)
            .textSelection(.enabled)
    }
}
