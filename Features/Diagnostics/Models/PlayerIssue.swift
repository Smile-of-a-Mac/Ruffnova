import Foundation

enum PlayerIssue: LocalizedError {
    case fileInaccessible
    case fileMissing
    case fileDamaged
    case ruffleLoadFailure
    case unsupportedAPI
    case networkBlocked
    case filesystemBlocked
    case renderInitFailure
    case scriptTimeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .fileInaccessible:
            return "File could not be accessed"
        case .fileMissing:
            return "File not found"
        case .fileDamaged:
            return "File appears to be damaged"
        case .ruffleLoadFailure:
            return "Ruffle failed to load the SWF"
        case .unsupportedAPI:
            return "SWF uses an unsupported API"
        case .networkBlocked:
            return "Network access was blocked"
        case .filesystemBlocked:
            return "Filesystem access was blocked"
        case .renderInitFailure:
            return "Failed to initialize renderer"
        case .scriptTimeout:
            return "Script execution timed out"
        case .unknown(let detail):
            return detail
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileInaccessible, .fileMissing:
            return "Check that the file exists and you have permission to access it"
        case .fileDamaged:
            return "Try re-downloading or using a different SWF file"
        case .ruffleLoadFailure:
            return "The SWF may use features Ruffle does not yet support"
        case .unsupportedAPI:
            return "This SWF uses ActionScript or APIs that are not yet implemented"
        case .networkBlocked:
            return "You can change network permissions in Settings"
        case .filesystemBlocked:
            return "You can change filesystem permissions in Settings"
        case .renderInitFailure:
            return "Try restarting the app or switching render backends"
        case .scriptTimeout:
            return "Try increasing the max execution duration in Settings"
        case .unknown:
            return nil
        }
    }
}
