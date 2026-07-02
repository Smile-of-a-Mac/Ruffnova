import Foundation

@MainActor
final class PlayerViewModel {
    var onControlBarVisibilityChanged: ((Bool) -> Void)?

    private(set) var showControlBar: Bool = true {
        didSet {
            guard oldValue != showControlBar else { return }
            onControlBarVisibilityChanged?(showControlBar)
        }
    }

    var isStageMaximized: Bool = false
    var isFullscreen: Bool = false

    private var hideControlBarTask: DispatchWorkItem?
    private var controlBarHideGeneration = 0

    deinit {
        hideControlBarTask?.cancel()
    }

    func showControlBarTemporarily(isPlaying: Bool) {
        showControlBar = true
        scheduleControlBarHide(isPlaying: isPlaying)
    }

    func keepControlBarVisible() {
        showControlBar = true
        cancelControlBarHide()
    }

    func controlBarOnPause() {
        cancelControlBarHide()
        showControlBar = true
    }

    private func cancelControlBarHide() {
        controlBarHideGeneration += 1
        hideControlBarTask?.cancel()
        hideControlBarTask = nil
    }

    private func scheduleControlBarHide(isPlaying: Bool) {
        cancelControlBarHide()
        guard isPlaying else { return }
        let generation = controlBarHideGeneration
        let task = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.controlBarHideGeneration == generation else { return }
                self?.showControlBar = false
            }
        }
        hideControlBarTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }

    func toggleStageMaximized() {
        isStageMaximized.toggle()
    }

    func exitStageMaximized() {
        isStageMaximized = false
    }

    func toggleFullscreen() {
        isFullscreen.toggle()
    }
}
