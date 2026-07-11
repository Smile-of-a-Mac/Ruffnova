import XCTest
@testable import Ruffnova

@MainActor
final class PermissionPolicyServiceTests: XCTestCase {
    func testGlobalDefaultsUseExistingSettingsKeys() throws {
        let defaults = try makeDefaults()
        let service = PermissionPolicyService(storageURL: temporaryStorageURL(), defaults: defaults)

        XCTAssertEqual(service.globalDefault(for: .network), .alwaysAsk)

        service.setGlobalDefault(.allow, for: .network)
        service.setGlobalDefault(.deny, for: .filesystem)

        XCTAssertEqual(defaults.string(forKey: "networkAccess"), "allow")
        XCTAssertEqual(defaults.string(forKey: "filesystemAccess"), "deny")
        XCTAssertEqual(service.evaluation(for: nil, scope: .network), .allowed)
        XCTAssertEqual(service.evaluation(for: nil, scope: .filesystem), .denied)
    }

    func testPerFileOverridesPersistAndCanBeCleared() throws {
        let defaults = try makeDefaults()
        let storageURL = temporaryStorageURL()
        let fileURL = URL(fileURLWithPath: "/tmp/game.swf")
        let service = PermissionPolicyService(storageURL: storageURL, defaults: defaults)

        service.setGlobalDefault(.allow, for: .network)
        service.apply(.denyForFile, for: fileURL, scope: .network)

        XCTAssertEqual(service.evaluation(for: fileURL, scope: .network), .denied)

        let reloaded = PermissionPolicyService(storageURL: storageURL, defaults: defaults)
        XCTAssertEqual(reloaded.evaluation(for: fileURL, scope: .network), .denied)
        XCTAssertEqual(reloaded.overrides.count, 1)

        reloaded.clearAllOverrides()

        XCTAssertEqual(reloaded.evaluation(for: fileURL, scope: .network), .allowed)
        XCTAssertTrue(reloaded.overrides.isEmpty)
    }

    func testAllowOnceDoesNotPersistOverride() throws {
        let defaults = try makeDefaults()
        let service = PermissionPolicyService(storageURL: temporaryStorageURL(), defaults: defaults)
        let fileURL = URL(fileURLWithPath: "/tmp/one.swf")

        let result = service.apply(.allowOnce, for: fileURL, scope: .filesystem)

        XCTAssertEqual(result, .allowed)
        XCTAssertEqual(service.evaluation(for: fileURL, scope: .filesystem), .allowed)
        XCTAssertTrue(service.overrides.isEmpty)

        service.clearSessionAllowances(for: fileURL)

        XCTAssertEqual(service.evaluation(for: fileURL, scope: .filesystem), .requiresPrompt)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PermissionPolicyServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func temporaryStorageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("permissionPolicies.json")
    }
}
