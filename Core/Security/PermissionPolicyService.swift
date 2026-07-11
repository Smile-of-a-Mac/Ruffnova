import Foundation
import OSLog

enum PermissionScope: String, Codable, CaseIterable, Identifiable {
    case network
    case filesystem

    var id: String { rawValue }
}

enum PermissionGlobalDefault: String, Codable, CaseIterable, Identifiable {
    case alwaysAsk
    case allow
    case deny

    var id: String { rawValue }
}

enum PermissionDecision: String, Codable, CaseIterable, Identifiable {
    case alwaysAsk
    case allowOnce
    case allowForFile
    case denyForFile
    case useGlobalDefault

    var id: String { rawValue }
}

enum PermissionPolicyEvaluation: Equatable {
    case allowed
    case denied
    case requiresPrompt
}

struct PermissionOverride: Identifiable, Codable, Equatable {
    let id: UUID
    var fileIdentifier: String
    var fileName: String
    var scope: PermissionScope
    var decision: PermissionDecision
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fileIdentifier: String,
        fileName: String,
        scope: PermissionScope,
        decision: PermissionDecision,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.fileIdentifier = fileIdentifier
        self.fileName = fileName
        self.scope = scope
        self.decision = decision
        self.updatedAt = updatedAt
    }
}

struct PermissionRequestContext: Identifiable, Equatable {
    let id: UUID
    var fileURL: URL?
    var scope: PermissionScope
    var requestedResource: String?

    init(id: UUID = UUID(), fileURL: URL?, scope: PermissionScope, requestedResource: String? = nil) {
        self.id = id
        self.fileURL = fileURL
        self.scope = scope
        self.requestedResource = requestedResource
    }
}

private struct PermissionSessionAllowance: Hashable {
    var fileIdentifier: String
    var scope: PermissionScope
}

@MainActor
final class PermissionPolicyService: ObservableObject {
    static let shared = PermissionPolicyService()

    @Published private(set) var overrides: [PermissionOverride] = []

    private let storageURL: URL
    private let defaults: UserDefaults
    private let schemaVersion = 1
    private let logger = Logger(subsystem: "com.ruffnova", category: "permissions")
    private var sessionAllowances: Set<PermissionSessionAllowance> = []

    convenience init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("RuffleFlashPlayer")
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.init(
            storageURL: directory.appendingPathComponent("permissionPolicies.json"),
            defaults: .standard
        )
    }

    init(storageURL: URL, defaults: UserDefaults) {
        self.storageURL = storageURL
        self.defaults = defaults
        load()
    }

    func globalDefault(for scope: PermissionScope) -> PermissionGlobalDefault {
        switch defaults.string(forKey: defaultsKey(for: scope)) {
        case "allow":
            return .allow
        case "deny":
            return .deny
        default:
            return .alwaysAsk
        }
    }

    func setGlobalDefault(_ value: PermissionGlobalDefault, for scope: PermissionScope) {
        let storedValue: String
        switch value {
        case .alwaysAsk:
            storedValue = "prompt"
        case .allow:
            storedValue = "allow"
        case .deny:
            storedValue = "deny"
        }
        defaults.set(storedValue, forKey: defaultsKey(for: scope))
    }

    func override(for fileURL: URL?, scope: PermissionScope) -> PermissionOverride? {
        guard let identifier = fileIdentifier(for: fileURL) else { return nil }
        return overrides.first { $0.fileIdentifier == identifier && $0.scope == scope }
    }

    func evaluation(for fileURL: URL?, scope: PermissionScope) -> PermissionPolicyEvaluation {
        if let identifier = fileIdentifier(for: fileURL),
           sessionAllowances.contains(PermissionSessionAllowance(fileIdentifier: identifier, scope: scope)) {
            return .allowed
        }

        if let override = override(for: fileURL, scope: scope) {
            switch override.decision {
            case .allowForFile:
                return .allowed
            case .denyForFile:
                return .denied
            case .alwaysAsk, .allowOnce, .useGlobalDefault:
                break
            }
        }

        switch globalDefault(for: scope) {
        case .alwaysAsk:
            return .requiresPrompt
        case .allow:
            return .allowed
        case .deny:
            return .denied
        }
    }

    @discardableResult
    func apply(_ decision: PermissionDecision, for fileURL: URL?, scope: PermissionScope) -> PermissionPolicyEvaluation {
        switch decision {
        case .allowOnce:
            if let identifier = fileIdentifier(for: fileURL) {
                sessionAllowances.insert(PermissionSessionAllowance(fileIdentifier: identifier, scope: scope))
            }
            return .allowed
        case .allowForFile:
            setOverride(.allowForFile, for: fileURL, scope: scope)
            return .allowed
        case .denyForFile:
            setOverride(.denyForFile, for: fileURL, scope: scope)
            return .denied
        case .alwaysAsk:
            setGlobalDefault(.alwaysAsk, for: scope)
            clearOverride(for: fileURL, scope: scope)
            return .requiresPrompt
        case .useGlobalDefault:
            clearOverride(for: fileURL, scope: scope)
            return evaluation(for: fileURL, scope: scope)
        }
    }

    func clearOverride(for fileURL: URL?, scope: PermissionScope) {
        guard let identifier = fileIdentifier(for: fileURL) else { return }
        overrides.removeAll { $0.fileIdentifier == identifier && $0.scope == scope }
        save()
    }

    func clearSessionAllowances(for fileURL: URL?) {
        guard let identifier = fileIdentifier(for: fileURL) else { return }
        sessionAllowances = Set(sessionAllowances.filter { $0.fileIdentifier != identifier })
    }

    func clearOverride(_ id: UUID) {
        overrides.removeAll { $0.id == id }
        save()
    }

    func clearAllOverrides() {
        overrides.removeAll()
        save()
    }

    func policySummary(for fileURL: URL?) -> [String] {
        PermissionScope.allCases.map { scope in
            let decision = override(for: fileURL, scope: scope)?.decision.rawValue
                ?? globalDefault(for: scope).rawValue
            return "\(scope.rawValue): \(decision)"
        }
    }

    private func setOverride(_ decision: PermissionDecision, for fileURL: URL?, scope: PermissionScope) {
        guard let identifier = fileIdentifier(for: fileURL) else { return }
        let fileName = fileURL?.lastPathComponent ?? "-"
        if let index = overrides.firstIndex(where: { $0.fileIdentifier == identifier && $0.scope == scope }) {
            overrides[index].decision = decision
            overrides[index].fileName = fileName
            overrides[index].updatedAt = Date()
        } else {
            overrides.append(PermissionOverride(
                fileIdentifier: identifier,
                fileName: fileName,
                scope: scope,
                decision: decision
            ))
        }
        save()
    }

    private func fileIdentifier(for fileURL: URL?) -> String? {
        guard let fileURL else { return nil }
        return fileURL.isFileURL ? fileURL.standardizedFileURL.path : fileURL.absoluteString
    }

    private func defaultsKey(for scope: PermissionScope) -> String {
        switch scope {
        case .network:
            return "networkAccess"
        case .filesystem:
            return "filesystemAccess"
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        do {
            overrides = try JSONDecoder().decode(PermissionPolicyStore.self, from: data).overrides
        } catch {
            logger.error("Failed to load permission policies: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let store = PermissionPolicyStore(schemaVersion: schemaVersion, overrides: overrides)
            let data = try JSONEncoder().encode(store)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save permission policies: \(error.localizedDescription)")
        }
    }
}

private struct PermissionPolicyStore: Codable {
    var schemaVersion: Int
    var overrides: [PermissionOverride]
}
