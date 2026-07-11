import Foundation

enum PlayerLoadFailure: Equatable {
    case engineLoadFailed
    case timedOut
}

enum PlayerLoadState: Equatable {
    case idle
    case loading(UUID)
    case ready
    case failed(PlayerLoadFailure)
}

struct PlayerLoadCoordinator {
    private(set) var state: PlayerLoadState = .idle

    mutating func begin() -> UUID {
        let requestID = UUID()
        state = .loading(requestID)
        return requestID
    }

    mutating func complete(_ requestID: UUID, with result: PlayerLoadState) -> Bool {
        guard case .loading(requestID) = state else { return false }
        state = result
        return true
    }

    mutating func cancel(_ requestID: UUID) -> Bool {
        complete(requestID, with: .idle)
    }
}
