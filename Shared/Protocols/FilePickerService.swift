// FilePickerService — Platform-independent file import abstraction.
// macOS uses NSOpenPanel, iOS uses UIDocumentPickerViewController.

import Foundation

@MainActor
protocol FilePickerService {
    func pickSWFFile(completion: @escaping (URL?) -> Void)
    func pickFolder(completion: @escaping (URL?) -> Void)
    func saveScreenshot(data: Data, suggestedName: String, completion: @escaping (URL?) -> Void)
}
