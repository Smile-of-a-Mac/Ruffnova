// PlaybackMetrics — High-frequency playback state observed only by player chrome.
// Keeping these values out of AppState prevents frame/time updates from
// invalidating every view that observes the app-wide state object.

import Combine
import Foundation

@MainActor
final class PlaybackMetrics: ObservableObject {
    @Published var currentFrame: UInt32 = 0
    @Published var totalFrames: UInt32 = 0
    @Published var frameRate: Float = 30.0
    @Published var seekPosition: Double = 0

    var formattedCurrentTime: String {
        formattedTime(for: currentFrame)
    }

    var formattedTotalTime: String {
        formattedTime(for: totalFrames)
    }

    func reset() {
        currentFrame = 0
        totalFrames = 0
        frameRate = 30.0
        seekPosition = 0
    }

    private func formattedTime(for frame: UInt32) -> String {
        let seconds = frameRate > 0 ? Double(frame) / Double(frameRate) : 0
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
