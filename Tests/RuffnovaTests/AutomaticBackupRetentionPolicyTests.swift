import XCTest
@testable import Ruffnova

final class AutomaticBackupRetentionPolicyTests: XCTestCase {
    private let calendar = Calendar(identifier: .iso8601)
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testKeepsRecentDailyAndWeeklyAutomaticSnapshotsWithinPerGameLimit() {
        let snapshots = [
            snapshot(daysAgo: 0, hour: 1),
            snapshot(daysAgo: 0, hour: 2),
            snapshot(daysAgo: 0, hour: 3),
            snapshot(daysAgo: 0, hour: 4),
            snapshot(daysAgo: 0, hour: 5),
            snapshot(daysAgo: 1),
            snapshot(daysAgo: 2),
            snapshot(daysAgo: 3),
            snapshot(daysAgo: 4),
            snapshot(daysAgo: 5),
            snapshot(daysAgo: 6),
            snapshot(daysAgo: 7),
            snapshot(daysAgo: 14),
            snapshot(daysAgo: 21),
            snapshot(daysAgo: 28),
            snapshot(daysAgo: 35),
            snapshot(daysAgo: 42),
            snapshot(daysAgo: 49),
            snapshot(daysAgo: 56),
            snapshot(daysAgo: 63),
        ]

        let retained = AutomaticBackupRetentionPolicy(calendar: calendar)
            .retainedSnapshotIDs(from: snapshots, now: now)

        XCTAssertEqual(retained.count, 16)
        XCTAssertTrue(retained.isSuperset(of: Set(snapshots.prefix(5).map(\.id))))
        XCTAssertFalse(retained.contains(snapshots.last!.id))
    }

    func testNeverSelectsNamedOrSafetySnapshotsForDeletion() {
        let automatic = snapshot(daysAgo: 90)
        let named = AutomaticBackupSnapshotReference(
            id: UUID(),
            createdAt: now.addingTimeInterval(-90 * 86_400),
            totalBytes: 10,
            kind: .namedSlot
        )
        let safety = AutomaticBackupSnapshotReference(
            id: UUID(),
            createdAt: now.addingTimeInterval(-91 * 86_400),
            totalBytes: 10,
            kind: .safety
        )

        let deletionIDs = AutomaticBackupRetentionPolicy(calendar: calendar)
            .deletionCandidates(from: [automatic, named, safety], now: now)

        XCTAssertFalse(deletionIDs.contains(named.id))
        XCTAssertFalse(deletionIDs.contains(safety.id))
    }

    func testGlobalLimitEvictsOldestAutomaticSnapshotsOnly() {
        let oldAutomatic = snapshot(daysAgo: 10, totalBytes: 600)
        let newAutomatic = snapshot(daysAgo: 1, totalBytes: 600)
        let named = AutomaticBackupSnapshotReference(
            id: UUID(),
            createdAt: now,
            totalBytes: 1_000,
            kind: .namedSlot
        )

        let deletionIDs = AutomaticBackupRetentionPolicy(calendar: calendar, globalSoftLimitBytes: 1_000)
            .globalLimitDeletionCandidates(from: [oldAutomatic, newAutomatic, named])

        XCTAssertEqual(deletionIDs, [oldAutomatic.id, newAutomatic.id])
    }

    private func snapshot(daysAgo: Int, hour: Int = 0, totalBytes: Int64 = 10) -> AutomaticBackupSnapshotReference {
        AutomaticBackupSnapshotReference(
            id: UUID(),
            createdAt: now.addingTimeInterval(-Double(daysAgo * 86_400) + Double(hour * 3_600)),
            totalBytes: totalBytes,
            kind: .automatic
        )
    }
}
