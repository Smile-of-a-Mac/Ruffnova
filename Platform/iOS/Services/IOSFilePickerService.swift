// IOSFilePickerService — iOS file picker using UIDocumentPickerViewController.

#if os(iOS)
import UIKit
import UniformTypeIdentifiers

@MainActor
final class IOSFilePickerService: NSObject, FilePickerService, UIDocumentPickerDelegate {
    private var continuation: CheckedContinuation<URL?, Never>?

    func pickSWFFile(message: String?, title: String?) async -> URL? {
        await present(
            forOpeningContentTypes: [UTType(filenameExtension: "swf")].compactMap { $0 }
        )
    }

    func pickFolder(message: String?, prompt: String?) async -> URL? {
        await present(forOpeningContentTypes: [.folder])
    }

    private func present(forOpeningContentTypes types: [UTType]) async -> URL? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
            picker.delegate = self
            picker.allowsMultipleSelection = false

            guard presentPicker(picker) else {
                self.continuation = nil
                continuation.resume(returning: nil)
                return
            }
        }
    }

    private func presentPicker(_ picker: UIDocumentPickerViewController) -> Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController
        else { return false }

        var topController = root
        while let presented = topController.presentedViewController {
            topController = presented
        }
        topController.present(picker, animated: true)
        return true
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finish(with: urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(with: nil)
    }

    private func finish(with url: URL?) {
        continuation?.resume(returning: url)
        continuation = nil
    }
}
#endif
