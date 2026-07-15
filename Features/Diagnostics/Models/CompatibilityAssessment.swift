import Foundation

enum CompatibilityAssessmentStatus: String, Codable, CaseIterable {
    case unknown
    case compatible
    case degraded
    case blocked

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

enum CompatibilitySeverity: String, Codable, CaseIterable {
    case info
    case warning
    case error
    case critical

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .info
    }
}

struct CompatibilityEvidence: Codable, Equatable, Identifiable {
    var id: String
    var kind: String
    var code: String
    var source: String
    var observedAt: Date
    var value: String?
    var redactedTarget: String?
    var confidence: Double
    var occurrenceCount: Int
    var firstObservedAt: Date
    var lastObservedAt: Date
}

struct CompatibilityFinding: Codable, Equatable, Identifiable {
    var ruleID: String
    var severity: CompatibilitySeverity
    var titleKey: String
    var messageKey: String
    var evidenceIDs: [String]
    var recommendationIDs: [String]
    var isBlocking: Bool
    var firstDetectedAt: Date
    var lastDetectedAt: Date

    var id: String { ruleID }
}

enum CompatibilityAction: String, Codable, CaseIterable {
    case setRuntimeOverrides
    case resetRuntimeOverrides
    case reloadCurrentFile
    case retryLoad
    case openRuntimeSettings
    case openInputLayout
    case openSaveStorage
    case locateFile
    case copyReport
    case requestPermission
    case openPermissionSettings
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

struct CompatibilityRecommendation: Codable, Equatable, Identifiable {
    var id: String
    var priority: Int
    var titleKey: String
    var explanationKey: String
    var expectedEffectKey: String
    var action: CompatibilityAction
    var requiresReload: Bool
    var requiresConfirmation: Bool
    var alreadyApplied: Bool
    var rollbackAvailable: Bool
}

struct AppliedCompatibilityRecommendation: Codable, Equatable, Identifiable {
    var id: String
    var recommendationID: String
    var appliedAt: Date
    var previousRuntimeProfile: FileRuntimeProfile?
}

struct PersistedCompatibilityAssessment: Codable, Equatable {
    var schemaVersion: Int
    var rulesetVersion: String
    var generatedAt: Date
    var lastObservedAt: Date
    var status: CompatibilityAssessmentStatus
    var findings: [CompatibilityFinding]
    var recommendations: [CompatibilityRecommendation]
    var evidence: [CompatibilityEvidence]
    var inputFingerprint: String
    var engineBuildIdentifier: String
    var appBuildIdentifier: String
    var appliedRecommendationRecords: [AppliedCompatibilityRecommendation]
    var isCompleteObservation: Bool

    init(
        schemaVersion: Int = 1,
        rulesetVersion: String = "1",
        generatedAt: Date = Date(),
        lastObservedAt: Date = Date(),
        status: CompatibilityAssessmentStatus = .unknown,
        findings: [CompatibilityFinding] = [],
        recommendations: [CompatibilityRecommendation] = [],
        evidence: [CompatibilityEvidence] = [],
        inputFingerprint: String = "",
        engineBuildIdentifier: String = "",
        appBuildIdentifier: String = "",
        appliedRecommendationRecords: [AppliedCompatibilityRecommendation] = [],
        isCompleteObservation: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.rulesetVersion = rulesetVersion
        self.generatedAt = generatedAt
        self.lastObservedAt = lastObservedAt
        self.status = status
        self.findings = findings
        self.recommendations = recommendations
        self.evidence = evidence
        self.inputFingerprint = inputFingerprint
        self.engineBuildIdentifier = engineBuildIdentifier
        self.appBuildIdentifier = appBuildIdentifier
        self.appliedRecommendationRecords = appliedRecommendationRecords
        self.isCompleteObservation = isCompleteObservation
    }
}
