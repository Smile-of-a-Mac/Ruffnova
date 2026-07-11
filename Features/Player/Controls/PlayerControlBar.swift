import SwiftUI
#if os(iOS)
import MediaPlayer
#endif

struct PlayerControlBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var locManager: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        #if os(iOS)
        iosControlBar
        #else
        if appState.isStageMaximized && appState.swfContentType == .interactive {
            interactiveGlassPills
        } else if appState.swfContentType == .interactive {
            interactiveNativeControls
        } else {
            animationBar
        }
        #endif
    }

    // MARK: - iOS: Modern player controls

    #if os(iOS)
    @ViewBuilder
    private var iosControlBar: some View {
        ZStack {
            if appState.swfContentType == .interactive {
                iosInteractiveControlBar
            } else {
                iosAnimationControlBar
            }

            IOSSystemVolumeView(appState: appState)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
    }

    private var iosInteractiveControlBar: some View {
        HStack(spacing: NativeSpacing.md) {
            iosPlayButton(size: 44, iconSize: 17)

            Button(action: { appState.toggleVirtualControls() }) {
                Image(systemName: appState.showVirtualControls ? "gamecontroller.fill" : "gamecontroller")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(appState.showVirtualControls ? Color.accentColor : Color.secondary)
                    .frame(width: 44, height: 44)
                    .nativeLiquidGlass(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(locManager.localized("player.virtualControls"))
            .accessibilityValue(locManager.localized(appState.showVirtualControls ? "player.virtualControls.hide" : "player.virtualControls.show"))

            Button(action: { appState.toggleMute() }) {
                Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .nativeLiquidGlass(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(locManager.localized(appState.isMuted ? "player.unmute" : "player.mute"))

            Slider(value: Binding(
                get: { Double(appState.systemVolume) },
                set: { appState.setSystemVolume(Float($0)) }
            ), in: 0...1)
            .tint(.secondary)
            .accessibilityLabel(locManager.localized("player.volume"))
            .accessibilityValue("\(Int(appState.volume * 100))%")
        }
        .padding(.horizontal, NativeSpacing.sm)
        .padding(.vertical, NativeSpacing.sm)
        .frame(maxWidth: .infinity)
        .nativeLiquidGlass(in: RoundedRectangle(cornerRadius: NativeRadius.xl, style: .continuous))
    }

    private var iosAnimationControlBar: some View {
        VStack(spacing: NativeSpacing.sm) {
            iosTimeline

            HStack(alignment: .center, spacing: NativeSpacing.sm) {
                iosTransportButton("backward.end.fill", labelKey: "menu.rewind", size: 14) {
                    appState.rewind()
                }

                iosTransportButton("backward.frame.fill", labelKey: "menu.stepBackward", size: 14) {
                    appState.stepBackward()
                }

                iosPlayButton(size: 46, iconSize: 18)

                iosTransportButton("forward.frame.fill", labelKey: "menu.stepForward", size: 14) {
                    appState.stepForward()
                }

                iosTransportButton("forward.end.fill", labelKey: "player.seekToEnd", size: 14) {
                    appState.seekToEnd()
                }

                Spacer(minLength: NativeSpacing.xs)

                iosLoopButton
                iosSpeedMenu
                iosMuteButton
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, NativeSpacing.sm)
        .padding(.vertical, NativeSpacing.sm)
        .nativeLiquidGlass(in: RoundedRectangle(cornerRadius: NativeRadius.xl, style: .continuous))
    }

    private func iosPlayButton(size: CGFloat, iconSize: CGFloat) -> some View {
        Button(action: { appState.togglePlayPause() }) {
            Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.accentColor, in: Circle())
                .shadow(color: Color.accentColor.opacity(0.28), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locManager.localized(appState.isPlaying ? "menu.pause" : "menu.play"))
    }

    private var iosTimeline: some View {
        HStack(spacing: NativeSpacing.sm) {
            Text(appState.formattedCurrentTime)
                .frame(width: 38, alignment: .leading)

            Slider(value: $appState.seekPosition,
                   in: 0...max(appState.totalFrames > 0 ? Double(appState.totalFrames) : 1, 1)
            ) { editing in
                if !editing { appState.seekToFrame(UInt32(appState.seekPosition)) }
            }
            .tint(.primary)
            .accessibilityLabel(locManager.localized("player.timeline"))
            .accessibilityValue("\(appState.formattedCurrentTime) / \(appState.formattedTotalTime)")

            Text(appState.formattedTotalTime)
                .frame(width: 38, alignment: .trailing)
        }
        .font(.caption2.monospacedDigit().weight(.medium))
        .foregroundStyle(.secondary)
    }

    private func iosTransportButton(_ systemName: String, labelKey: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .nativeLiquidGlass(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locManager.localized(labelKey))
    }

    private var iosLoopButton: some View {
        Button(action: { appState.toggleLoop() }) {
            Image(systemName: appState.isLooping ? "repeat.1" : "repeat")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(appState.isLooping ? Color.accentColor : Color.secondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .nativeLiquidGlass(in: Circle())
        .accessibilityLabel(locManager.localized("menu.loop"))
        .accessibilityValue(locManager.localized(appState.isLooping ? "player.loop.on" : "player.loop.off"))
    }

    private var iosSpeedMenu: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0], id: \.self) { speed in
                Button(String(format: "%.2fx", speed)) { appState.setSpeed(Float(speed)) }
            }
        } label: {
            Text(String(format: "%.2fx", appState.playbackSpeed))
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 46, height: 44)
                .nativeLiquidGlass(in: Capsule())
        }
        .accessibilityLabel(locManager.localized("menu.speed"))
        .accessibilityValue(String(format: "%.2fx", appState.playbackSpeed))
    }

    private var iosMuteButton: some View {
        Button(action: { appState.toggleMute() }) {
            Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .nativeLiquidGlass(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locManager.localized(appState.isMuted ? "player.unmute" : "player.mute"))
    }
    #endif

    // MARK: - macOS Shared Play Button

    private var macPlayButton: some View {
        Button(action: { appState.togglePlayPause() }) {
            Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: Circle())
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locManager.localized(appState.isPlaying ? "menu.pause" : "menu.play"))
    }

    // MARK: - Interactive: Native controls

    private var interactiveNativeControls: some View {
        HStack(spacing: NativeSpacing.md) {
            macPlayButton

            HStack(spacing: NativeSpacing.sm) {
                Button(action: { appState.toggleMute() }) {
                    Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(locManager.localized(appState.isMuted ? "player.unmute" : "player.mute"))

            Slider(value: Binding(
                get: { Double(appState.volume) },
                set: { appState.setVolume(Float($0)) }
            ), in: 0...1)
                .tint(.secondary)
            }
            .frame(maxWidth: 160)
        }
    }

    // MARK: - Interactive: Liquid Glass fullscreen controls

    private var interactiveGlassPills: some View {
        HStack(spacing: NativeSpacing.md) {
            macPlayButton

            HStack(spacing: NativeSpacing.sm) {
                Button(action: { appState.toggleMute() }) {
                    Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(locManager.localized(appState.isMuted ? "player.unmute" : "player.mute"))

                Slider(value: Binding(
                    get: { Double(appState.volume) },
                    set: { appState.setVolume(Float($0)) }
                ), in: 0...1)
                .frame(width: 50)
                .tint(.secondary)
            }
            .padding(.horizontal, NativeSpacing.sm)
            .padding(.vertical, NativeSpacing.xs)
            .liquidGlassCapsule()
        }
    }

    // MARK: - Animation: Full timeline bar

    private var animationBar: some View {
        VStack(spacing: NativeSpacing.sm) {
            modernSeekBar

            HStack(spacing: 0) {
                HStack(spacing: NativeSpacing.xs) {
                    macPlayButton
                    modernSkipButtons
                }

                Spacer()

                modernTimeDisplay

                Spacer()

                HStack(spacing: NativeSpacing.sm) {
                    modernLoopButton
                    modernSpeedButton
                    modernVolumeControl
                }
            }
        }
    }

    private var modernSeekBar: some View {
        Slider(value: $appState.seekPosition,
               in: 0...max(appState.totalFrames > 0 ? Double(appState.totalFrames) : 1, 1)
        ) { editing in
            if !editing { appState.seekToFrame(UInt32(appState.seekPosition)) }
        }
        .tint(.primary)
    }

    private var modernSkipButtons: some View {
        HStack(spacing: 2) {
            Button(action: { appState.stepBackward() }) {
                Image(systemName: "gobackward.5")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(locManager.localized("menu.stepBackward"))

            Button(action: { appState.stepForward() }) {
                Image(systemName: "goforward.5")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(locManager.localized("menu.stepForward"))
        }
    }

    private var modernTimeDisplay: some View {
        HStack(spacing: 4) {
            Text(appState.formattedCurrentTime)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
            Text("/")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
            Text(appState.formattedTotalTime)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var modernLoopButton: some View {
        Button(action: { appState.toggleLoop() }) {
            Image(systemName: appState.isLooping ? "repeat.1" : "repeat")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(appState.isLooping ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locManager.localized("menu.loop"))
        .accessibilityValue(locManager.localized(appState.isLooping ? "player.loop.on" : "player.loop.off"))
    }

    private var modernSpeedButton: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0], id: \.self) { s in
                Button(String(format: "%.2fx", s)) { appState.setSpeed(Float(s)) }
            }
        } label: {
            Text(String(format: "%.2fx", appState.playbackSpeed))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(locManager.localized("menu.speed"))
        .accessibilityValue(String(format: "%.2fx", appState.playbackSpeed))
    }

    private var modernVolumeControl: some View {
        HStack(spacing: 4) {
            Button(action: { appState.toggleMute() }) {
                Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(locManager.localized(appState.isMuted ? "player.unmute" : "player.mute"))

            Slider(value: Binding(
                get: { Double(appState.volume) },
                set: { appState.setVolume(Float($0)) }
            ), in: 0...1)
            .frame(width: 56)
            .tint(.secondary)
        }
    }
}

#if os(iOS)
private struct IOSSystemVolumeView: UIViewRepresentable {
    let appState: AppState

    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsVolumeSlider = true

        DispatchQueue.main.async {
            let slider = volumeView.subviews.compactMap { $0 as? UISlider }.first
            appState.attachSystemVolumeSlider(slider)
        }
        return volumeView
    }

    func updateUIView(_ volumeView: MPVolumeView, context: Context) {
        let slider = volumeView.subviews.compactMap { $0 as? UISlider }.first
        appState.attachSystemVolumeSlider(slider)
    }

}
#endif

#Preview("Controls") {
    PlayerControlBar()
        .environmentObject(AppState())
        .padding(40).frame(width: 600)
}
