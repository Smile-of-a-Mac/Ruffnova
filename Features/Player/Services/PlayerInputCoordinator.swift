import Foundation

@MainActor
final class PlayerInputCoordinator {
    private let overlayHideDelay: TimeInterval = 2.5
    private var hideOverlayTask: DispatchWorkItem?
    private var overlayHideGeneration = 0

    deinit {
        hideOverlayTask?.cancel()
    }

    func pointerMoved(isPlaying: Bool, mode: PlayerMode, setOverlayVisible: @escaping (Bool) -> Void) {
        guard mode == .game || mode == .cinema else {
            setOverlayVisible(true)
            return
        }

        setOverlayVisible(true)
        scheduleOverlayHide(isPlaying: isPlaying, setOverlayVisible: setOverlayVisible)
    }

    func cancelOverlayHide() {
        overlayHideGeneration += 1
        hideOverlayTask?.cancel()
        hideOverlayTask = nil
    }

    func playbackPaused(setOverlayVisible: @escaping (Bool) -> Void) {
        cancelOverlayHide()
        setOverlayVisible(true)
    }

    func handleEscape(isStageMaximized: Bool, mode: PlayerMode, exitStage: () -> Void, setMode: (PlayerMode) -> Void) {
        if isStageMaximized {
            exitStage()
        } else if mode == .game || mode == .cinema {
            setMode(.normal)
        }
    }

    func handleStageDoubleClick(mode: PlayerMode, toggleStage: () -> Void) {
        guard mode == .game || mode == .cinema else { return }
        toggleStage()
    }

    private func scheduleOverlayHide(isPlaying: Bool, setOverlayVisible: @escaping (Bool) -> Void) {
        cancelOverlayHide()
        guard isPlaying else { return }

        let generation = overlayHideGeneration
        let task = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.overlayHideGeneration == generation else { return }
                setOverlayVisible(false)
            }
        }
        hideOverlayTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + overlayHideDelay, execute: task)
    }
}
