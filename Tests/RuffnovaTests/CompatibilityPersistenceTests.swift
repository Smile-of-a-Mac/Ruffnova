import XCTest
@testable import Ruffnova

final class CompatibilityPersistenceTests: XCTestCase {
    func testAssessmentRoundTripPreservesRuleEngineOutput() throws {
        let observedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let assessment = CompatibilityRuleEngine().evaluate(
            CompatibilityContext(
                policySignals: [.filesystemDenied],
                observedAt: observedAt,
                inputFingerprint: "input-v2",
                engineBuildIdentifier: "engine-test",
                appBuildIdentifier: "app-test"
            )
        )

        let decoded = try JSONDecoder().decode(
            PersistedCompatibilityAssessment.self,
            from: JSONEncoder().encode(assessment)
        )

        XCTAssertEqual(decoded, assessment)
    }
}
