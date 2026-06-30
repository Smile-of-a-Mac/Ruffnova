// IOSFilePickerService — iOS file picker using UIDocumentPickerViewController.

#if os(iOS)
import UIKit
import UniformTypeIdentifiers

@MainActor
final class IOSFilePickerService: NSObject, FilePickerService, UIDocumentPickerDelegate {
    private var pickCompletion: ((URL?) -> Void)?
    private var presentedController: UIViewController?

    func pickSWFFile(completion: @escaping (URL?) -> Void) {
        pickCompletion = completion
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType(filenameExtension: "swf")].compactMap { $0 }
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presentPicker(picker)
    }

    func pickFolder(completion: @escaping (URL?) -> Void) {
        pickCompletion = completion
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder]
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presentPicker(picker)
    }

    func saveScreenshot(data: Data, suggestedName: String, completion: @escaping (URL?) -> Void) {
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedName)
        do {
            try data.write(to: tmpURL)
            let picker = UIDocumentPickerViewController(forExporting: [tmpURL])
            presentPicker(picker)
            completion(tmpURL)
        } catch {
            completion(nil)
        }
    }

    private func presentPicker(_ picker: UIDocumentPickerViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        var topController = root
        while let presented = topController.presentedViewController {
            topController = presented
        }
        topController.present(picker, animated: true)
        presentedController = topController
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        pickCompletion?(urls.first)
        pickCompletion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pickCompletion?(nil)
        pickCompletion = nil
    }
}
#endif
