import SwiftUI

struct CollectionsListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locManager: LocalizationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeSpacing.xxxl) {
                VStack(alignment: .leading, spacing: NativeSpacing.sm) {
                    Text(locManager.localized("sidebar.collections"))
                        .font(.largeTitle)
                    Text(locManager.localized("library.noCollections.subtitle"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                LazyVStack(spacing: NativeSpacing.md) {
                    ForEach(appState.collections) { collection in
                        HStack(spacing: NativeSpacing.md) {
                            Image(systemName: "folder")
                                .font(.title3)
                                .foregroundStyle(.tertiary)
                                .frame(width: 36, height: 36)
                                .background(GlassMaterial.ultraLight, in: Circle())
                            VStack(alignment: .leading, spacing: NativeSpacing.xs) {
                                Text(collection.name)
                                    .font(.callout)
                                Text(String(format: locManager.localized("library.fileCount"), collection.files.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, NativeSpacing.sm)
                        .padding(.horizontal, NativeSpacing.md)
                        .accessibilityLabel(collection.name)
                        .contextMenu {
                            Button(locManager.localized("collection.delete")) {
                                appState.deleteCollection(collection.id)
                            }
                        }
                    }
                }
            }
            .padding(NativeSpacing.section)
        }
        .accessibilityLabel(locManager.localized("sidebar.collections"))
    }
}
