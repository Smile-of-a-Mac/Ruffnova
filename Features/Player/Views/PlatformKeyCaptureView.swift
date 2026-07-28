#if os(iOS)
import SwiftUI

struct PlatformKeyCaptureView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let capture: (UInt32, UInt32) -> Void

    private var matchingKeys: [HIDKeyOption] {
        guard !searchText.isEmpty else { return HIDKeyOption.common }
        return HIDKeyOption.common.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || String(format: "0x%02X", $0.hidUsage).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(matchingKeys) { key in
                Button(key.name) {
                    capture(key.hidUsage, 0)
                    dismiss()
                }
            }
            .searchable(text: $searchText, prompt: locManager.localized("input.editor.keySearch"))
            .navigationTitle(locManager.localized("input.editor.chooseKey"))
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyEvent)) { notification in
            guard let userInfo = notification.userInfo,
                  let keyCode = userInfo["keyCode"] as? UInt32,
                  let isDown = userInfo["isDown"] as? Bool,
                  let modifiers = userInfo["modifiers"] as? UInt,
                  isDown else { return }
            capture(keyCode, UInt32(modifiers))
            dismiss()
        }
    }
}

private struct HIDKeyOption: Identifiable {
    let hidUsage: UInt32
    let name: String

    var id: UInt32 { hidUsage }

    static let common: [HIDKeyOption] = [
        HIDKeyOption(hidUsage: 0x04, name: "A"),
        HIDKeyOption(hidUsage: 0x05, name: "B"),
        HIDKeyOption(hidUsage: 0x06, name: "C"),
        HIDKeyOption(hidUsage: 0x07, name: "D"),
        HIDKeyOption(hidUsage: 0x08, name: "E"),
        HIDKeyOption(hidUsage: 0x09, name: "F"),
        HIDKeyOption(hidUsage: 0x0A, name: "G"),
        HIDKeyOption(hidUsage: 0x0B, name: "H"),
        HIDKeyOption(hidUsage: 0x0C, name: "I"),
        HIDKeyOption(hidUsage: 0x0D, name: "J"),
        HIDKeyOption(hidUsage: 0x0E, name: "K"),
        HIDKeyOption(hidUsage: 0x0F, name: "L"),
        HIDKeyOption(hidUsage: 0x10, name: "M"),
        HIDKeyOption(hidUsage: 0x11, name: "N"),
        HIDKeyOption(hidUsage: 0x12, name: "O"),
        HIDKeyOption(hidUsage: 0x13, name: "P"),
        HIDKeyOption(hidUsage: 0x14, name: "Q"),
        HIDKeyOption(hidUsage: 0x15, name: "R"),
        HIDKeyOption(hidUsage: 0x16, name: "S"),
        HIDKeyOption(hidUsage: 0x17, name: "T"),
        HIDKeyOption(hidUsage: 0x18, name: "U"),
        HIDKeyOption(hidUsage: 0x19, name: "V"),
        HIDKeyOption(hidUsage: 0x1A, name: "W"),
        HIDKeyOption(hidUsage: 0x1B, name: "X"),
        HIDKeyOption(hidUsage: 0x1C, name: "Y"),
        HIDKeyOption(hidUsage: 0x1D, name: "Z"),
        HIDKeyOption(hidUsage: 0x28, name: "Return"),
        HIDKeyOption(hidUsage: 0x29, name: "Escape"),
        HIDKeyOption(hidUsage: 0x2C, name: "Space"),
        HIDKeyOption(hidUsage: 0x4F, name: "Right Arrow"),
        HIDKeyOption(hidUsage: 0x50, name: "Left Arrow"),
        HIDKeyOption(hidUsage: 0x51, name: "Down Arrow"),
        HIDKeyOption(hidUsage: 0x52, name: "Up Arrow"),
    ]
}
#endif
