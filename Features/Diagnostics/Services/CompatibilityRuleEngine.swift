import Foundation

struct CompatibilityRuleEngine {
    static let rulesetVersion = "1"

    func evaluate(_ context: CompatibilityContext) -> PersistedCompatibilityAssessment {
        var findings = [CompatibilityFinding]()
        var recommendations = [CompatibilityRecommendation]()
        var evidence = [CompatibilityEvidence]()

        evaluateFileRules(context, findings: &findings, recommendations: &recommendations, evidence: &evidence)
        evaluateLoadRules(context, findings: &findings, recommendations: &recommendations, evidence: &evidence)
        evaluatePolicyRules(context, findings: &findings, recommendations: &recommendations, evidence: &evidence)
        evaluateMetadataRules(context, findings: &findings, evidence: &evidence)
        evaluatePerformanceRules(context, findings: &findings, recommendations: &recommendations, evidence: &evidence)
        evaluateInputAndStorageRules(context, findings: &findings, recommendations: &recommendations, evidence: &evidence)

        if context.isCompleteObservation,
           !findings.contains(where: { $0.severity != .info }) {
            appendFinding(
                ruleID: "healthy.observedRun.v1",
                severity: .info,
                isBlocking: false,
                context: context,
                findings: &findings,
                evidence: &evidence
            )
        }

        findings.sort { $0.ruleID < $1.ruleID }
        recommendations.sort { $0.id < $1.id }
        evidence.sort { $0.id < $1.id }

        return PersistedCompatibilityAssessment(
            rulesetVersion: Self.rulesetVersion,
            generatedAt: context.observedAt,
            lastObservedAt: context.observedAt,
            status: assessmentStatus(for: findings, isComplete: context.isCompleteObservation),
            findings: findings,
            recommendations: recommendations,
            evidence: evidence,
            inputFingerprint: context.inputFingerprint,
            engineBuildIdentifier: context.engineBuildIdentifier,
            appBuildIdentifier: context.appBuildIdentifier,
            isCompleteObservation: context.isCompleteObservation
        )
    }

    private func evaluateFileRules(
        _ context: CompatibilityContext,
        findings: inout [CompatibilityFinding],
        recommendations: inout [CompatibilityRecommendation],
        evidence: inout [CompatibilityEvidence]
    ) {
        if context.availabilityStatus == .missing {
            appendFinding(
                ruleID: "file.missing.v1",
                severity: .critical,
                isBlocking: true,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "file.missing.v1.locate",
                    action: .locateFile,
                    priority: 1,
                    requiresConfirmation: false
                )
            ) { recommendations.append($0) }
        } else if !context.isFileReadable || context.issues.contains(.fileInaccessible) {
            appendFinding(
                ruleID: "file.inaccessible.v1",
                severity: .critical,
                isBlocking: true,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "file.inaccessible.v1.locate",
                    action: .locateFile,
                    priority: 1,
                    requiresConfirmation: false
                )
            ) { recommendations.append($0) }
        }
    }

    private func evaluateLoadRules(
        _ context: CompatibilityContext,
        findings: inout [CompatibilityFinding],
        recommendations: inout [CompatibilityRecommendation],
        evidence: inout [CompatibilityEvidence]
    ) {
        if context.loadFailure == .engineLoadFailed || context.issues.contains(.ruffleLoadFailure) {
            appendFinding(
                ruleID: "load.failed.v1",
                severity: .critical,
                isBlocking: true,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "load.failed.v1.retry",
                    action: .retryLoad,
                    priority: 1,
                    requiresConfirmation: false
                )
            ) { recommendations.append($0) }
        }

        if context.issues.contains(.fileDamaged) {
            appendFinding(
                ruleID: "file.damaged.v1",
                severity: .critical,
                isBlocking: true,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "file.damaged.v1.retry",
                    action: .retryLoad,
                    priority: 1,
                    requiresConfirmation: false
                )
            ) { recommendations.append($0) }
        }

        if context.loadFailure == .timedOut || context.issues.contains(.scriptTimeout) {
            appendFinding(
                ruleID: "load.timeout.v1",
                severity: .error,
                isBlocking: false,
                context: context,
                findings: &findings,
                evidence: &evidence
            )
            let currentLimit = context.runtimeProfile.maxExecutionDuration ?? context.runtimeDefaults.maxExecutionDuration
            if currentLimit < 30 {
                appendRecommendation(
                    recommendation(
                        id: "runtime.executionLimitLow.v1.increase",
                        action: .setRuntimeOverrides,
                        priority: 2,
                        requiresConfirmation: true,
                        requiresReload: true,
                        rollbackAvailable: true
                    ),
                    to: "load.timeout.v1",
                    findings: &findings,
                    recommendations: &recommendations
                )
            }
        }

        if context.issues.contains(.renderInitFailure) {
            appendFinding(
                ruleID: "render.initializationFailed.v1",
                severity: .critical,
                isBlocking: true,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "render.initializationFailed.v1.retry",
                    action: .retryLoad,
                    priority: 1,
                    requiresConfirmation: false
                )
            ) { recommendations.append($0) }
        }

        if context.issues.contains(.unsupportedAPI) {
            appendFinding(ruleID: "engine.unsupportedAPI.v1", severity: .warning, isBlocking: false, context: context, findings: &findings, evidence: &evidence)
        }
    }

    private func evaluatePolicyRules(
        _ context: CompatibilityContext,
        findings: inout [CompatibilityFinding],
        recommendations: inout [CompatibilityRecommendation],
        evidence: inout [CompatibilityEvidence]
    ) {
        let signals = Set(context.policySignals)
        if signals.contains(.networkDenied) || context.issues.contains(.networkBlocked) {
            appendFinding(
                ruleID: "permission.networkDenied.v1",
                severity: .warning,
                isBlocking: false,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "permission.networkDenied.v1.request",
                    action: .requestPermission,
                    priority: 2,
                    requiresConfirmation: true
                )
            ) { recommendations.append($0) }
        }
        if signals.contains(.filesystemDenied) || context.issues.contains(.filesystemBlocked) {
            appendFinding(
                ruleID: "permission.filesystemDenied.v1",
                severity: .warning,
                isBlocking: false,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "permission.filesystemDenied.v1.request",
                    action: .requestPermission,
                    priority: 2,
                    requiresConfirmation: true
                )
            ) { recommendations.append($0) }
        }
        if signals.contains(.networkUnsupported) {
            appendFinding(ruleID: "engine.networkUnsupported.v1", severity: .warning, isBlocking: false, context: context, findings: &findings, evidence: &evidence)
        }
        if signals.contains(.unsupportedScheme) {
            appendFinding(ruleID: "engine.unsupportedScheme.v1", severity: .warning, isBlocking: false, context: context, findings: &findings, evidence: &evidence)
        }
        if signals.contains(.navigationDenied) {
            appendFinding(ruleID: "engine.navigationUnsupported.v1", severity: .warning, isBlocking: false, context: context, findings: &findings, evidence: &evidence)
        }
        if signals.contains(.socketDenied) {
            appendFinding(ruleID: "engine.socketUnsupported.v1", severity: .warning, isBlocking: false, context: context, findings: &findings, evidence: &evidence)
        }
    }

    private func evaluateMetadataRules(
        _ context: CompatibilityContext,
        findings: inout [CompatibilityFinding],
        evidence: inout [CompatibilityEvidence]
    ) {
        guard context.isCompleteObservation else { return }
        guard let metadata = context.metadata else {
            appendFinding(ruleID: "metadata.unavailable.v1", severity: .info, isBlocking: false, context: context, findings: &findings, evidence: &evidence)
            return
        }
        if !metadata.hasStageSize {
            appendFinding(ruleID: "metadata.invalidStage.v1", severity: .warning, isBlocking: false, context: context, findings: &findings, evidence: &evidence)
        }
        if metadata.isActionScript3 {
            appendFinding(ruleID: "metadata.as3Observed.v1", severity: .info, isBlocking: false, context: context, findings: &findings, evidence: &evidence)
        }
    }

    private func evaluatePerformanceRules(
        _ context: CompatibilityContext,
        findings: inout [CompatibilityFinding],
        recommendations: inout [CompatibilityRecommendation],
        evidence: inout [CompatibilityEvidence]
    ) {
        guard context.foregroundSampleDuration >= 8,
              let averageFPS = context.averageFPS,
              let expectedFrameRate = context.expectedFrameRate,
              averageFPS < max(15, expectedFrameRate * 0.6)
        else { return }

        appendFinding(
            ruleID: "performance.sustainedLowFPS.v1",
            severity: .warning,
            isBlocking: false,
            context: context,
            findings: &findings,
            evidence: &evidence,
            recommendation: recommendation(
                id: "performance.sustainedLowFPS.v1.reduceQuality",
                action: .setRuntimeOverrides,
                priority: 3,
                requiresConfirmation: true,
                requiresReload: true,
                rollbackAvailable: true
            )
        ) { recommendations.append($0) }
    }

    private func evaluateInputAndStorageRules(
        _ context: CompatibilityContext,
        findings: inout [CompatibilityFinding],
        recommendations: inout [CompatibilityRecommendation],
        evidence: inout [CompatibilityEvidence]
    ) {
        if context.isInteractive && context.usesDefaultInputProfile {
            appendFinding(
                ruleID: "input.interactiveDefaultLayout.v1",
                severity: .info,
                isBlocking: false,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "input.interactiveDefaultLayout.v1.open",
                    action: .openInputLayout,
                    priority: 5,
                    requiresConfirmation: false
                )
            ) { recommendations.append($0) }
        }

        guard let storageUsage = context.storageUsage else { return }
        if storageUsage.usageFraction >= 1 {
            appendFinding(
                ruleID: "storage.quotaExceeded.v1",
                severity: .error,
                isBlocking: false,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "storage.quotaExceeded.v1.open",
                    action: .openSaveStorage,
                    priority: 2,
                    requiresConfirmation: false
                )
            ) { recommendations.append($0) }
        } else if storageUsage.usageFraction >= 0.8 {
            appendFinding(
                ruleID: "storage.nearQuota.v1",
                severity: .warning,
                isBlocking: false,
                context: context,
                findings: &findings,
                evidence: &evidence,
                recommendation: recommendation(
                    id: "storage.nearQuota.v1.open",
                    action: .openSaveStorage,
                    priority: 4,
                    requiresConfirmation: false
                )
            ) { recommendations.append($0) }
        }
    }

    private func appendFinding(
        ruleID: String,
        severity: CompatibilitySeverity,
        isBlocking: Bool,
        context: CompatibilityContext,
        findings: inout [CompatibilityFinding],
        evidence: inout [CompatibilityEvidence],
        recommendation: CompatibilityRecommendation? = nil,
        appendRecommendation: (CompatibilityRecommendation) -> Void = { _ in }
    ) {
        let evidenceID = "\(ruleID).evidence"
        evidence.append(
            CompatibilityEvidence(
                id: evidenceID,
                kind: "rule",
                code: ruleID,
                source: "compatibility-rule-engine",
                observedAt: context.observedAt,
                value: nil,
                redactedTarget: nil,
                confidence: 1,
                occurrenceCount: 1,
                firstObservedAt: context.observedAt,
                lastObservedAt: context.observedAt
            )
        )
        findings.append(
            CompatibilityFinding(
                ruleID: ruleID,
                severity: severity,
                titleKey: "compatibility.finding.\(ruleID).title",
                messageKey: "compatibility.finding.\(ruleID).message",
                evidenceIDs: [evidenceID],
                recommendationIDs: recommendation.map { [$0.id] } ?? [],
                isBlocking: isBlocking,
                firstDetectedAt: context.observedAt,
                lastDetectedAt: context.observedAt
            )
        )
        if let recommendation {
            appendRecommendation(recommendation)
        }
    }

    private func appendRecommendation(
        _ recommendation: CompatibilityRecommendation,
        to ruleID: String,
        findings: inout [CompatibilityFinding],
        recommendations: inout [CompatibilityRecommendation]
    ) {
        guard let index = findings.firstIndex(where: { $0.ruleID == ruleID }) else { return }
        findings[index].recommendationIDs.append(recommendation.id)
        recommendations.append(recommendation)
    }

    private func recommendation(
        id: String,
        action: CompatibilityAction,
        priority: Int,
        requiresConfirmation: Bool,
        requiresReload: Bool = false,
        rollbackAvailable: Bool = false
    ) -> CompatibilityRecommendation {
        CompatibilityRecommendation(
            id: id,
            priority: priority,
            titleKey: "compatibility.recommendation.\(id).title",
            explanationKey: "compatibility.recommendation.\(id).explanation",
            expectedEffectKey: "compatibility.recommendation.\(id).effect",
            action: action,
            requiresReload: requiresReload,
            requiresConfirmation: requiresConfirmation,
            alreadyApplied: false,
            rollbackAvailable: rollbackAvailable
        )
    }

    private func assessmentStatus(
        for findings: [CompatibilityFinding],
        isComplete: Bool
    ) -> CompatibilityAssessmentStatus {
        if findings.contains(where: \.isBlocking) {
            return .blocked
        }
        if findings.contains(where: { $0.severity == .warning || $0.severity == .error || $0.severity == .critical }) {
            return .degraded
        }
        return isComplete ? .compatible : .unknown
    }
}
