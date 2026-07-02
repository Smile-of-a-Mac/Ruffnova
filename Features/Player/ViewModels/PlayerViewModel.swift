import Foundation

@MainActor
final class PlayerViewModel {
    var showControlBar: Bool = true
    var isStageMaximized: Bool = false
    var isFullscreen: Bool = false

    private var hideControlBarTask: DispatchWorkItem?

    deinit {
        hideControlBarTask?.cancel()
    }

    func showControlBarTemporarily(isPlaying: Bool) {
        showControlBar = true
        scheduleControlBarHide(isPlaying: isPlaying)
    }

    func keepControlBarVisible() {
        showControlBar = true
        hideControlBarTask?.cancel()
    }

    func controlBarOnPause() {
        hideControlBarTask?.cancel()
        showControlBar = true
    }

    private func scheduleControlBarHide(isPlaying: Bool) {
        hideControlBarTask?.cancel()
        guard isPlaying else { return }
        let task = DispatchWorkItem { [weak self] in
            Task { @MainActor in
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
