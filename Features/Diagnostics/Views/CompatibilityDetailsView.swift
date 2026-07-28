import SwiftUI

struct CompatibilityDetailsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locManager: LocalizationManager
    @ObservedObject private var libraryService = LibraryService.shared

    let itemID: UUID
    let openSection: (LibraryItemDetailsSection) -> Void

    @State private var pendingRecommendationIDs = Set<String>()
    @State private var showApplyConfirmation = false
    @State private var latestAutomaticBackup: SharedObjectSnapshot?

    var body: some View {
        if let item = libraryService.item(with: itemID) {
            VStack(alignment: .leading, spacing: NativeSpacing.xl) {
                summary(item)

                if let assessment = item.compatibilityAssessment {
                    recommendations(assessment, item: item)
                    findings(assessment)
                    environment(assessment, item: item)
                    evidence(assessment)
                } else {
                    Text(locManager.localized("library.details.compatibility.noAssessment"))
                        .foregroundStyle(.secondary)
                }
            }
            .alert(
                locManager.localized("compatibility.apply.title"),
                isPresented: $showApplyConfirmation
            ) {
                Button(locManager.localized("compatibility.apply.confirm")) {
                    _ = appState.applyCompatibilityRuntimeRecommendations(
                        for: itemID,
                        recommendationIDs: pendingRecommendationIDs.isEmpty ? nil : pendingRecommendationIDs
                    )
                }
                Button(locManager.localized("collection.cancel"), role: .cancel) {}
            } message: {
                if let application = appState.compatibilityRuntimeApplication(
                    for: itemID,
                    recommendationIDs: pendingRecommendationIDs.isEmpty ? nil : pendingRecommendationIDs
                ) {
                    Text(applicationSummary(application))
                }
            }
            .task(id: "\(itemID.uuidString)-\(appState.automaticBackupRefreshToken)") {
                latestAutomaticBackup = await AutomaticBackupService.shared.automaticSnapshots(for: itemID).first
            }
        }
    }

    private func summary(_ item: LibraryItem) -> some View {
        HStack(alignment: .top, spacing: NativeSpacing.md) {
            Image(systemName: statusSymbol(item.compatibilityAssessment?.status ?? .unknown))
                .font(.title2)
                .foregroundStyle(statusColor(item.compatibilityAssessment?.status ?? .unknown))

            VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                Text(statusTitle(item.compatibilityAssessment?.status ?? .unknown))
                    .font(.headline)
                if let assessment = item.compatibilityAssessment {
                    Text(
                        "\(locManager.localized("library.details.compatibility.lastChecked")): \(assessment.generatedAt.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if appState.isCompatibilityAssessmentStale(for: itemID) {
                        Label(locManager.localized("compatibility.stale"), systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Button {
                _ = appState.recheckCompatibility(for: itemID)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(item.url != appState.currentFileURL)
            .accessibilityLabel(locManager.localized("compatibility.recheck"))
        }
    }

    private func recommendations(_ assessment: PersistedCompatibilityAssessment, item: LibraryItem) -> some View {
        let safeRecommendations = assessment.recommendations.filter {
            $0.action == .setRuntimeOverrides && !$0.alreadyApplied
        }
        return detailGroup(locManager.localized("compatibility.recommendations")) {
            if assessment.recommendations.isEmpty {
                Text(locManager.localized("compatibility.recommendations.none"))
                    .foregroundStyle(.secondary)
            } else {
                if !safeRecommendations.isEmpty {
                    HStack {
                        Text(String(format: locManager.localized("compatibility.recommendations.count"), safeRecommendations.count))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(locManager.localized("compatibility.apply.all")) {
                            pendingRecommendationIDs = []
                            showApplyConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                ForEach(assessment.recommendations) { recommendation in
                    VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                        HStack(alignment: .firstTextBaseline, spacing: NativeSpacing.sm) {
                            Text(recommendationTitle(recommendation))
                                .font(.body.weight(.medium))
                            Spacer()
                            if recommendation.requiresReload {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(locManager.localized("compatibility.requiresReload"))
                            }
                            if recommendation.requiresConfirmation {
                                Image(systemName: "checkmark.shield")
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(locManager.localized("compatibility.requiresConfirmation"))
                            }
                        }
                        Text(recommendationDescription(recommendation))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        recommendationActions(recommendation, item: item)
                    }
                    .padding(.vertical, NativeSpacing.xs)
                    Divider()
                }

                if !assessment.appliedRecommendationRecords.isEmpty {
                    HStack {
                        Spacer()
                        Button(locManager.localized("compatibility.undo")) {
                            _ = appState.undoLatestCompatibilityRuntimeRecommendation(for: itemID)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recommendationActions(_ recommendation: CompatibilityRecommendation, item: LibraryItem) -> some View {
        switch recommendation.action {
        case .setRuntimeOverrides where !recommendation.alreadyApplied:
            Button(locManager.localized("compatibility.apply.single")) {
                pendingRecommendationIDs = [recommendation.id]
                showApplyConfirmation = true
            }
            .buttonStyle(.bordered)
        case .openInputLayout:
            Button(locManager.localized("compatibility.openControls")) {
                openSection(.controls)
            }
            .buttonStyle(.bordered)
        case .openSaveStorage:
            Button(locManager.localized("compatibility.openStorage")) {
                openSection(.storage)
            }
            .buttonStyle(.bordered)
        case .requestPermission where item.url == appState.currentFileURL:
            Button(locManager.localized("compatibility.requestPermission")) {
                _ = appState.requestPermission(scope: permissionScope(for: recommendation))
            }
            .buttonStyle(.bordered)
        case .retryLoad where item.url == appState.currentFileURL:
            Button(locManager.localized("compatibility.retry")) {
                appState.retryCurrentFile()
            }
            .buttonStyle(.bordered)
        default:
            EmptyView()
        }
    }

    private func findings(_ assessment: PersistedCompatibilityAssessment) -> some View {
        detailGroup(locManager.localized("compatibility.findings")) {
            if assessment.findings.isEmpty {
                Text(locManager.localized("compatibility.findings.none"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(assessment.findings) { finding in
                    HStack(alignment: .top, spacing: NativeSpacing.sm) {
                        Image(systemName: severitySymbol(finding.severity))
                            .foregroundStyle(severityColor(finding.severity))
                        VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                            Text(findingTitle(finding))
                                .font(.body.weight(.medium))
                            Text(finding.ruleID)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(
                                "\(finding.firstDetectedAt.formatted(date: .abbreviated, time: .shortened)) - \(finding.lastDetectedAt.formatted(date: .abbreviated, time: .shortened))"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, NativeSpacing.xs)
                }
            }
        }
    }

    private func environment(_ assessment: PersistedCompatibilityAssessment, item: LibraryItem) -> some View {
        detailGroup(locManager.localized("compatibility.environment")) {
            if let metadata = item.metadata {
                LabeledContent(locManager.localized("compatibility.environment.swfVersion"), value: String(metadata.swfVersion))
                LabeledContent(locManager.localized("compatibility.environment.actionScript"), value: metadata.isActionScript3 ? "AVM2" : "AVM1")
                LabeledContent(locManager.localized("diagnostics.report.stageDimensions"), value: "\(metadata.stageWidth) x \(metadata.stageHeight)")
                LabeledContent(locManager.localized("diagnostics.report.frameRate"), value: String(format: "%.1f", metadata.frameRate))
            }
            LabeledContent(locManager.localized("diagnostics.report.appVersion"), value: assessment.appBuildIdentifier.isEmpty ? locManager.localized("diagnostics.unavailable") : assessment.appBuildIdentifier)
            LabeledContent(locManager.localized("diagnostics.report.engineVersion"), value: assessment.engineBuildIdentifier.isEmpty ? locManager.localized("diagnostics.unavailable") : assessment.engineBuildIdentifier)
            LabeledContent(
                locManager.localized("storage.automatic.title"),
                value: locManager.localized(
                    appState.isAutomaticBackupEnabled(for: itemID)
                        ? "storage.automatic.status.enabled"
                        : "storage.automatic.status.disabled"
                )
            )
            LabeledContent(
                locManager.localized("storage.automatic.latest"),
                value: latestAutomaticBackup?.createdAt.formatted(date: .abbreviated, time: .shortened)
                    ?? locManager.localized("storage.automatic.none")
            )
        }
    }

    private func evidence(_ assessment: PersistedCompatibilityAssessment) -> some View {
        DisclosureGroup(locManager.localized("compatibility.evidence")) {
            VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                Text("\(locManager.localized("compatibility.evidence.ruleset")): \(assessment.rulesetVersion)")
                Text("\(locManager.localized("compatibility.evidence.fingerprint")): \(assessment.inputFingerprint)")
                ForEach(assessment.evidence) { evidence in
                    Text("\(evidence.code) [\(evidence.source)]")
                }
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .padding(.top, NativeSpacing.sm)

            Button {
                DiagnosticsService.shared.copyReport(
                    appState.makeCompatibilityReport().plainText { locManager.localized($0) }
                )
            } label: {
                Label(locManager.localized("diagnostics.copyReport"), systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .padding(.top, NativeSpacing.sm)
        }
    }

    private func detailGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: NativeSpacing.sm) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func applicationSummary(_ application: CompatibilityRuntimeApplication) -> String {
        var changes = [String]()
        if application.previousRuntime.quality != application.updatedRuntime.quality {
            changes.append("\(locManager.localized("menu.quality")): \(qualityName(application.previousRuntime.quality)) -> \(qualityName(application.updatedRuntime.quality))")
        }
        if application.previousRuntime.maxExecutionDuration != application.updatedRuntime.maxExecutionDuration {
            changes.append("\(locManager.localized("settings.advanced.actionscript.maxDuration")): \(Int(application.previousRuntime.maxExecutionDuration))s -> \(Int(application.updatedRuntime.maxExecutionDuration))s")
        }
        return changes.joined(separator: "\n")
    }

    private func qualityName(_ quality: RuffleQuality) -> String {
        switch quality {
        case .low: return locManager.localized("menu.quality.low")
        case .medium: return locManager.localized("menu.quality.medium")
        case .high, .high8x8, .high8x8Linear, .high16x16, .high16x16Linear:
            return locManager.localized("menu.quality.high")
        case .best: return locManager.localized("menu.quality.best")
        }
    }

    private func permissionScope(for recommendation: CompatibilityRecommendation) -> PermissionScope {
        recommendation.id.contains("filesystem") ? .filesystem : .network
    }

    private func statusTitle(_ status: CompatibilityAssessmentStatus) -> String {
        switch status {
        case .unknown: return locManager.localized("compatibility.status.unknown")
        case .compatible: return locManager.localized("compatibility.status.compatible")
        case .degraded: return locManager.localized("compatibility.status.degraded")
        case .blocked: return locManager.localized("compatibility.status.blocked")
        }
    }

    private func statusSymbol(_ status: CompatibilityAssessmentStatus) -> String {
        switch status {
        case .unknown: return "questionmark.circle"
        case .compatible: return "checkmark.circle"
        case .degraded: return "exclamationmark.triangle"
        case .blocked: return "xmark.octagon"
        }
    }

    private func statusColor(_ status: CompatibilityAssessmentStatus) -> Color {
        switch status {
        case .unknown: return .secondary
        case .compatible: return .green
        case .degraded: return .orange
        case .blocked: return .red
        }
    }

    private func severitySymbol(_ severity: CompatibilitySeverity) -> String {
        switch severity {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "exclamationmark.circle"
        case .critical: return "xmark.octagon"
        }
    }

    private func severityColor(_ severity: CompatibilitySeverity) -> Color {
        switch severity {
        case .info: return .secondary
        case .warning: return .orange
        case .error, .critical: return .red
        }
    }

    private func findingTitle(_ finding: CompatibilityFinding) -> String {
        if finding.ruleID == "healthy.observedRun.v1" {
            return locManager.localized("compatibility.finding.healthy")
        }
        if finding.ruleID.hasPrefix("permission.") { return locManager.localized("compatibility.finding.permission") }
        if finding.ruleID.hasPrefix("file.") { return locManager.localized("compatibility.finding.file") }
        if finding.ruleID.hasPrefix("load.") { return locManager.localized("compatibility.finding.load") }
        if finding.ruleID.hasPrefix("render.") { return locManager.localized("compatibility.finding.render") }
        if finding.ruleID.hasPrefix("metadata.") { return locManager.localized("compatibility.finding.metadata") }
        if finding.ruleID.hasPrefix("performance.") { return locManager.localized("compatibility.finding.performance") }
        if finding.ruleID.hasPrefix("input.") { return locManager.localized("compatibility.finding.input") }
        if finding.ruleID.hasPrefix("storage.") { return locManager.localized("compatibility.finding.storage") }
        return locManager.localized("compatibility.finding.engine")
    }

    private func recommendationTitle(_ recommendation: CompatibilityRecommendation) -> String {
        switch recommendation.action {
        case .setRuntimeOverrides: return locManager.localized("compatibility.recommendation.runtime")
        case .requestPermission: return locManager.localized("compatibility.recommendation.permission")
        case .openInputLayout: return locManager.localized("compatibility.recommendation.input")
        case .openSaveStorage: return locManager.localized("compatibility.recommendation.storage")
        case .retryLoad: return locManager.localized("compatibility.recommendation.retry")
        case .locateFile: return locManager.localized("compatibility.recommendation.locate")
        default: return recommendation.id
        }
    }

    private func recommendationDescription(_ recommendation: CompatibilityRecommendation) -> String {
        recommendation.requiresReload
            ? locManager.localized("compatibility.recommendation.reloadDescription")
            : locManager.localized("compatibility.recommendation.description")
    }
}
