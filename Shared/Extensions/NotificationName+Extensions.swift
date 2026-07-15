// NotificationName+Extensions — Centralized notification name declarations.
// All app-level notifications are defined here to avoid scattering across features.

import Foundation

extension Notification.Name {
    /// Posted when an SWF file should be opened. UserInfo contains "url" key with the file URL.
    static let openSWFFile = Notification.Name("openSWFFile")

    /// Posted when the player viewport changes. UserInfo contains "width", "height", "scaleFactor".
    static let viewportChanged = Notification.Name("viewportChanged")

    /// Posted when a keyboard event is sent to the player.
    static let keyEvent = Notification.Name("keyEvent")

    /// Posted when an SWF file has been successfully loaded.
    static let swfLoaded = Notification.Name("swfLoaded")

    /// Posted to toggle the SWF info panel.
    static let toggleSWFInfo = Notification.Name("toggleSWFInfo")

    /// Posted to toggle the trace console.
    static let toggleTraceConsole = Notification.Name("toggleTraceConsole")

    /// Posted when an import folder action is requested.
    static let importFolder = Notification.Name("importFolder")

    /// Posted to focus the search field.
    static let focusSearch = Notification.Name("focusSearch")

    /// Posted to move keyboard focus to the player stage.
    static let focusPlayerStage = Notification.Name("focusPlayerStage")

    /// Posted after the app language changes.
    static let localizationChanged = Notification.Name("localizationChanged")

    /// Posted when the active file should receive a best-effort automatic backup.
    static let automaticBackupRequested = Notification.Name("automaticBackupRequested")
}
