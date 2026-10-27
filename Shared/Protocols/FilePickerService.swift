// FilePickerService — Platform-independent file import abstraction.
// macOS uses NSOpenPanel, iOS uses UIDocumentPickerViewController.

import Foundation

@MainActor
protocol FilePickerService {
    func pickSWFFile(message: String?, title: String?) async -> URL?
    func pickFolder(message: String?, prompt: String?) async -> URL?
}
