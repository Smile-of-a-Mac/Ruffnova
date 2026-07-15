import Foundation

struct CompatibilityRuntimeApplication: Equatable {
    var updatedProfile: FileRuntimeProfile
    var recommendationIDs: [String]
    var previousRuntime: RuntimeDefaults
    var updatedRuntime: RuntimeDefaults
}

struct CompatibilityActionService {
    func safeRuntimeApplication(
        for assessment: PersistedCompatibilityAssessment,
        currentProfile: FileRuntimeProfile,
        defaults: RuntimeDefaults,
        limitedTo recommendationIDs: Set<String>? = nil
    ) -> CompatibilityRuntimeApplication? {
        var profile = currentProfile
        var appliedIDs = [String]()

        for recommendation in assessment.recommendations where recommendation.action == .setRuntimeOverrides && !recommendation.alreadyApplied {
            if let recommendationIDs, !recommendationIDs.contains(recommendation.id) {
                continue
            }
            switch recommendation.id {
            case "runtime.executionLimitLow.v1.increase":
                let currentDuration = profile.maxExecutionDuration ?? defaults.maxExecutionDuration
                guard currentDuration < 30 else { continue }
                profile.maxExecutionDuration = 30
                appliedIDs.append(recommendation.id)
            case "performance.sustainedLowFPS.v1.reduceQuality":
                let currentQuality = profile.qualityRawValue ?? defaults.quality.rawValue
                let reducedQuality = max(RuffleQuality.low.rawValue, currentQuality - 1)
                guard reducedQuality != currentQuality else { continue }
                profile.qualityRawValue = reducedQuality
                appliedIDs.append(recommendation.id)
            default:
                continue
            }
        }

        guard !appliedIDs.isEmpty else { return nil }
        return CompatibilityRuntimeApplication(
            updatedProfile: profile,
            recommendationIDs: appliedIDs.sorted(),
            previousRuntime: currentProfile.resolved(using: defaults),
            updatedRuntime: profile.resolved(using: defaults)
        )
    }
}
