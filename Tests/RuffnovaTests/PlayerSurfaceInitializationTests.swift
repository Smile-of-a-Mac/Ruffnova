import XCTest
@testable import Ruffnova

final class PlayerSurfaceInitializationTests: XCTestCase {
    func testRequiresAnAttachedWindowBeforeCreatingTheRendererSurface() {
        XCTAssertFalse(RuffleSurfaceInitialization.isReady(
            hasWindow: false, width: 640, height: 480, drawableWidth: 1280, drawableHeight: 960
        ))
        XCTAssertFalse(RuffleSurfaceInitialization.isReady(
            hasWindow: true, width: 640, height: 480, drawableWidth: 0, drawableHeight: 0
        ))
        XCTAssertTrue(RuffleSurfaceInitialization.isReady(
            hasWindow: true, width: 640, height: 480, drawableWidth: 1280, drawableHeight: 960
        ))
    }

    func testFirstMovieUsesThePlayerCreatedWithItsInitialConfiguration() {
        XCTAssertFalse(RufflePlayerLifecycle.shouldRecreateBeforeLoad(
            hasLoadedMovie: false,
            configurationChanged: false
        ))
        XCTAssertTrue(RufflePlayerLifecycle.shouldRecreateBeforeLoad(
            hasLoadedMovie: true,
            configurationChanged: false
        ))
        XCTAssertTrue(RufflePlayerLifecycle.shouldRecreateBeforeLoad(
            hasLoadedMovie: false,
            configurationChanged: true
        ))
    }

    func testFailedRendererCreationRemainsRetryable() {
        XCTAssertFalse(RufflePlayerLifecycle.shouldCommitSurfaceInitialization(rendererCreated: false))
        XCTAssertTrue(RufflePlayerLifecycle.shouldCommitSurfaceInitialization(rendererCreated: true))
    }
}
