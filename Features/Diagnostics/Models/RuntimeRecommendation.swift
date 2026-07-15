import Foundation

enum CompatibilityLoadFailure: Equatable {
    case engineLoadFailed
    case timedOut
}

enum CompatibilityPolicySignal: String, CaseIterable, Hashable {
    case filesystemDenied
    case networkDenied
    case networkUnsupported
    case unsupportedScheme
    case navigationDenied
    case socketDenied
}

struct CompatibilityStorageUsage: Equatable {
    var usedBytes: Int64
    var quotaBytes: Int64

    var usageFraction: Double {
        guard quotaBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(quotaBytes)
    }
}

struct CompatibilityContext: Equatable {
    var availabilityStatus: AvailabilityStatus
    var isFileReadable: Bool
    var loadFailure: CompatibilityLoadFailure?
    var issues: [PlayerIssue]
    var policySignals: [CompatibilityPolicySignal]
    var metadata: SWFMetadata?
    var isInteractive: Bool
    var usesDefaultInputProfile: Bool
    var storageUsage: CompatibilityStorageUsage?
    var foregroundSampleDuration: TimeInterval
    var averageFPS: Double?
    var expectedFrameRate: Double?
    var runtimeProfile: FileRuntimeProfile
    var runtimeDefaults: RuntimeDefaults
    var observedAt: Date
    var inputFingerprint: String
    var engineBuildIdentifier: String
    var appBuildIdentifier: String
    var isCompleteObservation: Bool

    init(
        availabilityStatus: AvailabilityStatus = .available,
        isFileReadable: Bool = true,
        loadFailure: CompatibilityLoadFailure? = nil,
        issues: [PlayerIssue] = [],
        policySignals: [CompatibilityPolicySignal] = [],
        metadata: SWFMetadata? = nil,
        isInteractive: Bool = false,
        usesDefaultInputProfile: Bool = false,
        storageUsage: CompatibilityStorageUsage? = nil,
        foregroundSampleDuration: TimeInterval = 0,
        averageFPS: Double? = nil,
        expectedFrameRate: Double? = nil,
        runtimeProfile: FileRuntimeProfile = FileRuntimeProfile(),
        runtimeDefaults: RuntimeDefaults = RuntimeDefaults(),
        observedAt: Date = Date(),
        inputFingerprint: String = "",
        engineBuildIdentifier: String = "",
        appBuildIdentifier: String = "",
        isCompleteObservation: Bool = false
    ) {
        self.availabilityStatus = availabilityStatus
        self.isFileReadable = isFileReadable
        self.loadFailure = loadFailure
        self.issues = issues
        self.policySignals = policySignals
        self.metadata = metadata
        self.isInteractive = isInteractive
        self.usesDefaultInputProfile = usesDefaultInputProfile
        self.storageUsage = storageUsage
        self.foregroundSampleDuration = foregroundSampleDuration
        self.averageFPS = averageFPS
        self.expectedFrameRate = expectedFrameRate
        self.runtimeProfile = runtimeProfile
        self.runtimeDefaults = runtimeDefaults
        self.observedAt = observedAt
        self.inputFingerprint = inputFingerprint
        self.engineBuildIdentifier = engineBuildIdentifier
        self.appBuildIdentifier = appBuildIdentifier
        self.isCompleteObservation = isCompleteObservation
    }
}

struct RuntimeProfilePatch: Equatable {
    var qualityRawValue: Int32?
    var maxExecutionDuration: TimeInterval?

    init(qualityRawValue: Int32? = nil, maxExecutionDuration: TimeInterval? = nil) {
        self.qualityRawValue = qualityRawValue
        self.maxExecutionDuration = maxExecutionDuration
    }

    var isEmpty: Bool {
        qualityRawValue == nil && maxExecutionDuration == nil
    }
}
