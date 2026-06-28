import SwiftUI

struct PlayerControlBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isStageMaximized && appState.swfContentType == .interactive {
            interactiveGlassPills
        } else if appState.swfContentType == .interactive {
            interactiveNativeControls
        } else {
            animationBar
        }
    }

    // MARK: - Interactive: Native controls

    private var interactiveNativeControls: some View {
        HStack(spacing: NativeSpacing.md) {
            Button(action: { appState.togglePlayPause() }) {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
            }
            .controlSize(.small)

            Slider(value: Binding(
                get: { Double(appState.volume) },
                set: { appState.setVolume(Float($0)) }
            ), in: 0...1)
            .frame(width: 80)
            .controlSize(.small)

            Button(action: { appState.toggleMute() }) {
                Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .controlSize(.small)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Interactive: Liquid Glass fullscreen controls

    private var interactiveGlassPills: some View {
        HStack(spacing: NativeSpacing.xl) {
            Button(action: { appState.togglePlayPause() }) {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .modifier(LiquidGlassModifier(shape: Circle(), material: GlassMaterial.ultraLight))

            HStack(spacing: NativeSpacing.sm) {
                Button(action: { appState.toggleMute() }) {
                    Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Slider(value: Binding(
                    get: { Double(appState.volume) },
                    set: { appState.setVolume(Float($0)) }
                ), in: 0...1)
                .frame(width: 56)
                .tint(.secondary)
            }
            .padding(.horizontal, NativeSpacing.md)
            .padding(.vertical, NativeSpacing.sm)
            .liquidGlassCapsule()
        }
    }

    // MARK: - Animation: Full timeline bar

    private var animationBar: some View {
        HStack(spacing: NativeSpacing.lg) {
            Button(action: { appState.togglePlayPause() }) {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .modifier(LiquidGlassModifier(shape: Circle(), material: GlassMaterial.ultraLight))

            HStack(spacing: NativeSpacing.sm) {
                Button(action: { appState.rewind() }) {
                    Image(systemName: "backward.end.fill").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Button(action: { appState.stepBackward() }) {
                    Image(systemName: "backward.frame.fill").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Button(action: { appState.stepForward() }) {
                    Image(systemName: "forward.frame.fill").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Button(action: { appState.seekToEnd() }) {
                    Image(systemName: "forward.end.fill").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
            }

            HStack(spacing: NativeSpacing.md) {
                Text(appState.formattedCurrentTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
                Slider(value: $appState.seekPosition,
                       in: 0...max(appState.totalFrames > 0 ? Double(appState.totalFrames) : 1, 1)
                ) { editing in
                    if !editing { appState.seekToFrame(UInt32(appState.seekPosition)) }
                }
                Text(appState.formattedTotalTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            Spacer()

            Button(action: { appState.toggleLoop() }) {
                Image(systemName: appState.isLooping ? "repeat.1" : "repeat")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(appState.isLooping ? Color.accentColor : .secondary)

            Menu {
                ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0], id: \.self) { s in
                    Button(String(format: "%.2fx", s)) { appState.setSpeed(Float(s)) }
                }
            } label: {
                Text(String(format: "%.2fx", appState.playbackSpeed))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44).menuStyle(.borderlessButton)

            HStack(spacing: NativeSpacing.xs) {
                Button(action: { appState.toggleMute() }) {
                    Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(appState.volume) },
                       set: { appState.setVolume(Float($0)) }), in: 0...1)
                .frame(width: 60)
            }
        }
        .padding(.horizontal, NativeSpacing.lg)
        .padding(.vertical, NativeSpacing.sm)
        .liquidGlassCapsule(material: GlassMaterial.light)
        .onHover { hovering in
            hovering ? appState.keepControlBarVisible() : appState.showControlBarTemporarily()
        }
    }
}

#Preview("Controls") {
    PlayerControlBar()
        .environmentObject(AppState())
        .padding(40).frame(width: 600)
}
