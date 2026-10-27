// MacFilePickerService — macOS file picker using NSOpenPanel.

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

@MainActor
final class MacFilePickerService: FilePickerService {
    func pickSWFFile(message: String?, title: String?) async -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "swf")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let title { panel.title = title }
        if let message { panel.message = message }
        return await present(panel)
    }

    func pickFolder(message: String?, prompt: String?) async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let prompt { panel.prompt = prompt }
        if let message { panel.message = message }
        return await present(panel)
    }

    private func present(_ panel: NSOpenPanel) async -> URL? {
        await withCheckedContinuation { continuation in
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }
}
#endif
