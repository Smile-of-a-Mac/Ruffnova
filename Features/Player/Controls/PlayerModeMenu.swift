import SwiftUI

struct PlayerModeMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    var body: some View {
        Menu {
            ForEach(PlayerMode.allCases) { mode in
                Button(locManager.localized(mode.localizedKey)) {
                    appState.setPlayerMode(mode)
                }
            }
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        #endif
        .fixedSize()
        .accessibilityLabel(locManager.localized("player.mode"))
    }

    private var iconName: String {
        switch appState.playerMode {
        case .normal: return "rectangle"
        case .cinema: return "rectangle.inset.filled"
        case .game: return "gamecontroller"
        }
    }
}
