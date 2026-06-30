// MacFilePickerService — macOS file picker using NSOpenPanel.

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

@MainActor
final class MacFilePickerService: FilePickerService {
    func pickSWFFile(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "swf")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.runModal()
        completion(panel.url)
    }

    func pickFolder(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.runModal()
        completion(panel.url)
    }

    func saveScreenshot(data: Data, suggestedName: String, completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedName
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
                completion(url)
            } else {
                completion(nil)
            }
        }
    }
}
#endif
