import XCTest
@testable import Ruffnova

final class PlayerLoadStateTests: XCTestCase {
    func testCompletingCurrentRequestMarksPlayerReady() {
        var coordinator = PlayerLoadCoordinator()
        let requestID = coordinator.begin()

        XCTAssertTrue(coordinator.complete(requestID, with: .ready))
        XCTAssertEqual(coordinator.state, .ready)
    }

    func testCompletingSupersededRequestDoesNotReplaceCurrentState() {
        var coordinator = PlayerLoadCoordinator()
        let firstRequestID = coordinator.begin()
        let secondRequestID = coordinator.begin()

        XCTAssertFalse(coordinator.complete(firstRequestID, with: .failed(.engineLoadFailed)))
        XCTAssertEqual(coordinator.state, .loading(secondRequestID))
    }

    func testFailingCurrentRequestRetainsFailureForRecovery() {
        var coordinator = PlayerLoadCoordinator()
        let requestID = coordinator.begin()

        XCTAssertTrue(coordinator.complete(requestID, with: .failed(.timedOut)))
        XCTAssertEqual(coordinator.state, .failed(.timedOut))
    }

    func testCancellingCurrentRequestReturnsToIdle() {
        var coordinator = PlayerLoadCoordinator()
        let requestID = coordinator.begin()

        XCTAssertTrue(coordinator.cancel(requestID))
        XCTAssertEqual(coordinator.state, .idle)
    }
}
