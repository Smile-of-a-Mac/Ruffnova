import SwiftUI

final class TraceConsole: ObservableObject {
    static let shared = TraceConsole()
    @Published var messages: [TraceEntry] = []
    private let maxMessages = 1000

    struct TraceEntry: Identifiable {
        let id = UUID()
        let text: String
        let timestamp = Date()
    }

    func append(_ text: String) {
        messages.append(TraceEntry(text: text))
        if messages.count > maxMessages { messages.removeFirst(messages.count - maxMessages) }
    }

    func clear() { messages.removeAll() }
}

struct TraceConsoleView: View {
    @EnvironmentObject var locManager: LocalizationManager
    @StateObject private var console = TraceConsole.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(locManager.localized("traceConsole.title"))
                    .font(.headline)
                Spacer()
                Button(locManager.localized("traceConsole.clear")) {
                    console.clear()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
            .padding(.horizontal, NativeSpacing.xl)
            .padding(.vertical, NativeSpacing.md)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(console.messages) { entry in
                            Text(entry.text)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    .padding(NativeSpacing.sm)
                }
                .onChange(of: console.messages.count) { _ in
                    if let last = console.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 200)
    }
}
