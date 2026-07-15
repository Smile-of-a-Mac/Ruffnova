import XCTest
@testable import Ruffnova

final class CompatibilityActionServiceTests: XCTestCase {
    func testAppliesOnlySafeRuntimeRecommendationsAndPreservesOtherOverrides() {
        let assessment = PersistedCompatibilityAssessment(
            recommendations: [
                recommendation(id: "runtime.executionLimitLow.v1.increase", action: .setRuntimeOverrides),
                recommendation(id: "performance.sustainedLowFPS.v1.reduceQuality", action: .setRuntimeOverrides),
                recommendation(id: "permission.networkDenied.v1.request", action: .requestPermission),
            ]
        )
        let profile = FileRuntimeProfile(letterbox: "off", autoplay: false)

        let application = CompatibilityActionService().safeRuntimeApplication(
            for: assessment,
            currentProfile: profile,
            defaults: RuntimeDefaults(quality: .high, maxExecutionDuration: 15)
        )

        XCTAssertEqual(application?.updatedProfile.qualityRawValue, RuffleQuality.medium.rawValue)
        XCTAssertEqual(application?.updatedProfile.maxExecutionDuration, 30)
        XCTAssertEqual(application?.updatedProfile.letterbox, "off")
        XCTAssertEqual(application?.updatedProfile.autoplay, false)
        XCTAssertEqual(application?.previousRuntime.quality, .high)
        XCTAssertEqual(application?.updatedRuntime.quality, .medium)
        XCTAssertEqual(
            application?.recommendationIDs,
            ["performance.sustainedLowFPS.v1.reduceQuality", "runtime.executionLimitLow.v1.increase"]
        )
    }

    func testDoesNotCreateAnApplicationForNonRuntimeRecommendations() {
        let assessment = PersistedCompatibilityAssessment(
            recommendations: [recommendation(id: "permission.networkDenied.v1.request", action: .requestPermission)]
        )

        XCTAssertNil(
            CompatibilityActionService().safeRuntimeApplication(
                for: assessment,
                currentProfile: FileRuntimeProfile(),
                defaults: RuntimeDefaults()
            )
        )
    }

    private func recommendation(id: String, action: CompatibilityAction) -> CompatibilityRecommendation {
        CompatibilityRecommendation(
            id: id,
            priority: 1,
            titleKey: "title",
            explanationKey: "explanation",
            expectedEffectKey: "effect",
            action: action,
            requiresReload: true,
            requiresConfirmation: true,
            alreadyApplied: false,
            rollbackAvailable: true
        )
    }
}
