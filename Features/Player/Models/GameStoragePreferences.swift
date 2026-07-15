import Foundation

struct GameStoragePreferences: Codable, Equatable {
    var automaticBackupEnabled: Bool?

    init(automaticBackupEnabled: Bool? = nil) {
        self.automaticBackupEnabled = automaticBackupEnabled
    }
}
