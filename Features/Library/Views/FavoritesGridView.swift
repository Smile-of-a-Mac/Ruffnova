import SwiftUI

struct FavoritesGridView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: NativeSpacing.xxxl)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
                VStack(alignment: .leading, spacing: NativeSpacing.sm) {
                    Text(locManager.localized("sidebar.favorites"))
                        .font(.largeTitle)
                    Text(locManager.localized("library.noFavorites.subtitle"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: NativeSpacing.xl) {
                    ForEach(appState.favoriteEntries) { bookmark in
                        Button { appState.openFile(bookmark.url) } label: {
                            VStack(alignment: .leading, spacing: NativeSpacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: NativeRadius.md, style: .continuous)
                                        .fill(GlassMaterial.ultraLight)
                                    Image(systemName: "star")
                                        .font(.system(size: 28, weight: .light))
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(height: 112)

                                Text(bookmark.name)
                                    .font(.callout)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(bookmark.name)
                        .contextMenu {
                            Button(locManager.localized("favorites.remove")) {
                                appState.toggleFavorite(for: bookmark.url)
                            }
                        }
                    }
                }
            }
            .padding(NativeSpacing.section)
        }
        .accessibilityLabel(locManager.localized("sidebar.favorites"))
    }
}
