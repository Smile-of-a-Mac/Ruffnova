import Foundation

enum PlayerIssue: Error, Equatable, Identifiable {
    case fileInaccessible
    case fileMissing
    case fileDamaged
    case ruffleLoadFailure
    case unsupportedAPI
    case networkBlocked
    case filesystemBlocked
    case libraryMigrationFailed
    case renderInitFailure
    case scriptTimeout
    case unknown(String)

    var id: String {
        switch self {
        case .fileInaccessible:
            return "fileInaccessible"
        case .fileMissing:
            return "fileMissing"
        case .fileDamaged:
            return "fileDamaged"
        case .ruffleLoadFailure:
            return "ruffleLoadFailure"
        case .unsupportedAPI:
            return "unsupportedAPI"
        case .networkBlocked:
            return "networkBlocked"
        case .filesystemBlocked:
            return "filesystemBlocked"
        case .libraryMigrationFailed:
            return "libraryMigrationFailed"
        case .renderInitFailure:
            return "renderInitFailure"
        case .scriptTimeout:
            return "scriptTimeout"
        case .unknown(let detail):
            return "unknown-\(detail)"
        }
    }

    var messageKey: String? {
        switch self {
        case .fileInaccessible:
            return "diagnostics.issue.fileInaccessible"
        case .fileMissing:
            return "diagnostics.issue.fileMissing"
        case .fileDamaged:
            return "diagnostics.issue.fileDamaged"
        case .ruffleLoadFailure:
            return "diagnostics.issue.ruffleLoadFailure"
        case .unsupportedAPI:
            return "diagnostics.issue.unsupportedAPI"
        case .networkBlocked:
            return "diagnostics.issue.networkBlocked"
        case .filesystemBlocked:
            return "diagnostics.issue.filesystemBlocked"
        case .libraryMigrationFailed:
            return "diagnostics.issue.libraryMigrationFailed"
        case .renderInitFailure:
            return "diagnostics.issue.renderInitFailure"
        case .scriptTimeout:
            return "diagnostics.issue.scriptTimeout"
        case .unknown:
            return nil
        }
    }

    var fallbackMessage: String? {
        if case .unknown(let detail) = self { return detail }
        return nil
    }

    func displayMessage(localize: (String) -> String) -> String {
        if let messageKey {
            return localize(messageKey)
        }
        return fallbackMessage ?? localize("diagnostics.issue.unknown")
    }

    var recoverySuggestionKey: String? {
        switch self {
        case .fileInaccessible, .fileMissing:
            return "diagnostics.recovery.checkFileAccess"
        case .fileDamaged:
            return "diagnostics.recovery.fileDamaged"
        case .ruffleLoadFailure:
            return "diagnostics.recovery.ruffleLoadFailure"
        case .unsupportedAPI:
            return "diagnostics.recovery.unsupportedAPI"
        case .networkBlocked:
            return "diagnostics.recovery.networkBlocked"
        case .filesystemBlocked:
            return "diagnostics.recovery.filesystemBlocked"
        case .libraryMigrationFailed:
            return "diagnostics.recovery.libraryMigrationFailed"
        case .renderInitFailure:
            return "diagnostics.recovery.renderInitFailure"
        case .scriptTimeout:
            return "diagnostics.recovery.scriptTimeout"
        case .unknown:
            return nil
        }
    }
}
