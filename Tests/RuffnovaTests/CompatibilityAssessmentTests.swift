import XCTest
@testable import Ruffnova

final class CompatibilityAssessmentTests: XCTestCase {
    func testUnknownPersistedEnumValuesFallBackToSafeCases() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "status": "future-status",
            "severity": "future-severity",
            "action": "future-action",
        ])

        struct FutureValues: Decodable {
            let status: CompatibilityAssessmentStatus
            let severity: CompatibilitySeverity
            let action: CompatibilityAction
        }

        let values = try JSONDecoder().decode(FutureValues.self, from: data)

        XCTAssertEqual(values.status, .unknown)
        XCTAssertEqual(values.severity, .info)
        XCTAssertEqual(values.action, .unknown)
    }
}
