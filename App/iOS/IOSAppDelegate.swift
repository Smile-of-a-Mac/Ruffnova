// IOSAppDelegate — Handles iOS application lifecycle.

#if os(iOS)
import UIKit

enum IOSOrientationController {
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait

    @MainActor
    static func update(to orientations: UIInterfaceOrientationMask) {
        supportedOrientations = orientations
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
    }
}

final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        IOSOrientationController.supportedOrientations
    }
}
#endif
