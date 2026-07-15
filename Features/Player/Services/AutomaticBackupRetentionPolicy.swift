import Foundation

struct AutomaticBackupSnapshotReference: Equatable {
    let id: UUID
    let createdAt: Date
    let totalBytes: Int64
    let kind: SharedObjectSnapshotKind
}

struct AutomaticBackupRetentionPolicy {
    static let recentSnapshotLimit = 5
    static let dailySnapshotLimit = 7
    static let weeklySnapshotLimit = 4
    static let perGameSnapshotLimit = 16
    static let defaultGlobalSoftLimitBytes: Int64 = 1_073_741_824

    private let calendar: Calendar
    private let globalSoftLimitBytes: Int64

    init(
        calendar: Calendar = .current,
        globalSoftLimitBytes: Int64 = AutomaticBackupRetentionPolicy.defaultGlobalSoftLimitBytes
    ) {
        self.calendar = calendar
        self.globalSoftLimitBytes = globalSoftLimitBytes
    }

    func retainedSnapshotIDs(
        from snapshots: [AutomaticBackupSnapshotReference],
        now: Date
    ) -> Set<UUID> {
        let automaticSnapshots = automaticSnapshotsSortedNewestFirst(snapshots)
        var retained = Set(automaticSnapshots.prefix(Self.recentSnapshotLimit).map(\.id))
        var dailyBuckets = Set<Date>()
        var weeklyBuckets = Set<WeekBucket>()

        for snapshot in automaticSnapshots.dropFirst(Self.recentSnapshotLimit) {
            guard retained.count < Self.perGameSnapshotLimit else { break }
            let day = calendar.startOfDay(for: snapshot.createdAt)
            guard dailyBuckets.count < Self.dailySnapshotLimit, dailyBuckets.insert(day).inserted else { continue }
            retained.insert(snapshot.id)
        }

        for snapshot in automaticSnapshots.dropFirst(Self.recentSnapshotLimit) {
            guard retained.count < Self.perGameSnapshotLimit, !retained.contains(snapshot.id) else { continue }
            let week = WeekBucket(date: snapshot.createdAt, calendar: calendar)
            guard weeklyBuckets.count < Self.weeklySnapshotLimit, weeklyBuckets.insert(week).inserted else { continue }
            retained.insert(snapshot.id)
        }

        return retained
    }

    func deletionCandidates(
        from snapshots: [AutomaticBackupSnapshotReference],
        now: Date
    ) -> [UUID] {
        let retained = retainedSnapshotIDs(from: snapshots, now: now)
        return automaticSnapshotsSortedNewestFirst(snapshots)
            .filter { !retained.contains($0.id) }
            .map(\.id)
    }

    func globalLimitDeletionCandidates(from snapshots: [AutomaticBackupSnapshotReference]) -> [UUID] {
        var totalBytes = snapshots.reduce(Int64(0)) { $0 + $1.totalBytes }
        guard totalBytes > globalSoftLimitBytes else { return [] }

        var deletionIDs = [UUID]()
        for snapshot in snapshots
            .filter({ $0.kind == .automatic })
            .sorted(by: { $0.createdAt < $1.createdAt }) {
            guard totalBytes > globalSoftLimitBytes else { break }
            totalBytes -= snapshot.totalBytes
            deletionIDs.append(snapshot.id)
        }
        return deletionIDs
    }

    private func automaticSnapshotsSortedNewestFirst(
        _ snapshots: [AutomaticBackupSnapshotReference]
    ) -> [AutomaticBackupSnapshotReference] {
        snapshots
            .filter { $0.kind == .automatic }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

private struct WeekBucket: Hashable {
    let year: Int
    let week: Int

    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        year = components.yearForWeekOfYear ?? 0
        week = components.weekOfYear ?? 0
    }
}
