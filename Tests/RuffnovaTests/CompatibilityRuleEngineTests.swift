import XCTest
@testable import Ruffnova

final class CompatibilityRuleEngineTests: XCTestCase {
    private let observedAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testMissingFileIsBlockingAndSuggestsLocation() {
        let assessment = CompatibilityRuleEngine().evaluate(
            CompatibilityContext(
                availabilityStatus: .missing,
                observedAt: observedAt
            )
        )

        XCTAssertEqual(assessment.status, .blocked)
        XCTAssertEqual(assessment.findings.map(\.ruleID), ["file.missing.v1"])
        XCTAssertEqual(assessment.findings.first?.evidenceIDs, ["file.missing.v1.evidence"])
        XCTAssertEqual(assessment.recommendations.first?.action, .locateFile)
    }

    func testPermissionDenialSuggestsPermissionWithoutBlocking() {
        let assessment = CompatibilityRuleEngine().evaluate(
            CompatibilityContext(
                policySignals: [.networkDenied],
                observedAt: observedAt,
                isCompleteObservation: true
            )
        )

        XCTAssertEqual(assessment.status, .degraded)
        XCTAssertFalse(assessment.findings.contains(where: \.isBlocking))
        XCTAssertEqual(assessment.recommendations.first?.action, .requestPermission)
        XCTAssertTrue(assessment.recommendations.first?.requiresConfirmation ?? false)
    }

    func testExistingPermissionIssueUsesTheSameNonBlockingRule() {
        let assessment = CompatibilityRuleEngine().evaluate(
            CompatibilityContext(
                issues: [.networkBlocked],
                observedAt: observedAt
            )
        )

        XCTAssertEqual(assessment.status, .degraded)
        XCTAssertTrue(assessment.findings.contains { $0.ruleID == "permission.networkDenied.v1" })
    }

    func testCompleteHealthyRunIsCompatible() {
        let assessment = CompatibilityRuleEngine().evaluate(
            CompatibilityContext(
                observedAt: observedAt,
                isCompleteObservation: true
            )
        )

        XCTAssertEqual(assessment.status, .compatible)
        XCTAssertTrue(assessment.findings.contains { $0.ruleID == "healthy.observedRun.v1" })
    }

    func testAssessmentIsStableAndSortedForTheSameContext() {
        let context = CompatibilityContext(
            availabilityStatus: .available,
            loadFailure: .timedOut,
            policySignals: [.networkDenied, .unsupportedScheme],
            metadata: SWFMetadata(stageWidth: 0, stageHeight: 0),
            isInteractive: true,
            usesDefaultInputProfile: true,
            observedAt: observedAt,
            inputFingerprint: "stable-input"
        )
        let engine = CompatibilityRuleEngine()

        let first = engine.evaluate(context)
        let second = engine.evaluate(context)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.findings.map(\.ruleID), first.findings.map(\.ruleID).sorted())
        XCTAssertEqual(first.recommendations.map(\.id), first.recommendations.map(\.id).sorted())
        XCTAssertTrue(first.findings.allSatisfy { !$0.evidenceIDs.isEmpty })
        XCTAssertTrue(first.recommendations.allSatisfy { recommendation in
            first.findings.contains { $0.recommendationIDs.contains(recommendation.id) }
        })
    }

    func testTimeoutWithLowExecutionLimitRecommendsAFileOverride() {
        let assessment = CompatibilityRuleEngine().evaluate(
            CompatibilityContext(
                loadFailure: .timedOut,
                runtimeDefaults: RuntimeDefaults(maxExecutionDuration: 15),
                observedAt: observedAt
            )
        )

        XCTAssertTrue(assessment.findings.contains { $0.ruleID == "load.timeout.v1" })
        XCTAssertEqual(
            assessment.recommendations.first { $0.id == "runtime.executionLimitLow.v1.increase" }?.action,
            .setRuntimeOverrides
        )
    }

    func testStorageUsageDistinguishesNearQuotaFromQuotaExceeded() {
        let engine = CompatibilityRuleEngine()
        let nearQuota = engine.evaluate(
            CompatibilityContext(
                storageUsage: CompatibilityStorageUsage(usedBytes: 80, quotaBytes: 100),
                observedAt: observedAt
            )
        )
        let exceeded = engine.evaluate(
            CompatibilityContext(
                storageUsage: CompatibilityStorageUsage(usedBytes: 100, quotaBytes: 100),
                observedAt: observedAt
            )
        )

        XCTAssertTrue(nearQuota.findings.contains { $0.ruleID == "storage.nearQuota.v1" })
        XCTAssertFalse(nearQuota.findings.contains { $0.ruleID == "storage.quotaExceeded.v1" })
        XCTAssertTrue(exceeded.findings.contains { $0.ruleID == "storage.quotaExceeded.v1" })
    }

    func testLowFPSSignalRequiresAFullForegroundSample() {
        let engine = CompatibilityRuleEngine()
        let insufficientSample = engine.evaluate(
            CompatibilityContext(
                foregroundSampleDuration: 7.9,
                averageFPS: 10,
                expectedFrameRate: 30,
                observedAt: observedAt
            )
        )
        let sustainedSample = engine.evaluate(
            CompatibilityContext(
                foregroundSampleDuration: 8,
                averageFPS: 10,
                expectedFrameRate: 30,
                observedAt: observedAt
            )
        )

        XCTAssertFalse(insufficientSample.findings.contains { $0.ruleID == "performance.sustainedLowFPS.v1" })
        XCTAssertTrue(sustainedSample.findings.contains { $0.ruleID == "performance.sustainedLowFPS.v1" })
    }
}
