import Foundation
#if RUST_FFI_AVAILABLE
import CRuffleFFI
#endif

struct GameStorageEntry: Identifiable, Equatable {
    let name: String
    let size: Int

    var id: String { name }
}

struct GameStorageUsage: Equatable {
    let usedBytes: Int64
    let quotaBytes: Int64
}

enum GameStorageError: Error, Equatable {
    case invalidEntry
    case unavailable
    case verificationFailed
}

final class GameStorageService {
    static let shared = GameStorageService()

    private let paths: SharedObjectStoragePaths

    init(paths: SharedObjectStoragePaths = SharedObjectStoragePaths()) {
        self.paths = paths
    }

    func entries(for libraryID: UUID) throws -> [GameStorageEntry] {
        var list = RuffleStringList(data: nil, len: 0)
        let result = call(libraryID) { root, id in
            ruffle_storage_list(root, id, &list)
        }
        guard result == RUFFLE_RESULT_OK else { throw GameStorageError.unavailable }
        defer { ruffle_string_list_free(list) }

        return (0..<Int(list.len)).compactMap { index in
            guard let item = list.data?.advanced(by: index).pointee.data else { return nil }
            let name = String(bytes: UnsafeRawBufferPointer(
                start: item,
                count: Int(list.data!.advanced(by: index).pointee.len)
            ), encoding: .utf8)
            guard let name else { return nil }
            let entrySize = (try? size(of: name, for: libraryID)) ?? 0
            return GameStorageEntry(name: name, size: Int(entrySize))
        }
    }

    func usage(for libraryID: UUID) throws -> GameStorageUsage {
        var used: UInt64 = 0
        var quota: UInt64 = 0
        let result = call(libraryID) { root, id in ruffle_storage_get_usage(root, id, &used, &quota) }
        guard result == RUFFLE_RESULT_OK else { throw GameStorageError.unavailable }
        return GameStorageUsage(usedBytes: Int64(used), quotaBytes: Int64(quota))
    }

    func size(of name: String, for libraryID: UUID) throws -> Int64 {
        var size: UInt64 = 0
        let result = call(libraryID, name: name) { root, id, name in ruffle_storage_get_size(root, id, name, &size) }
        guard result == RUFFLE_RESULT_OK else { throw GameStorageError.unavailable }
        return Int64(size)
    }

    func read(_ name: String, for libraryID: UUID) throws -> Data {
        var bytes = RuffleBytes(data: nil, len: 0)
        let result = call(libraryID, name: name) { root, id, name in
            ruffle_storage_read(root, id, name, &bytes)
        }
        guard result == RUFFLE_RESULT_OK else { throw GameStorageError.unavailable }
        defer { ruffle_bytes_free(bytes) }
        return Data(bytes: bytes.data!, count: Int(bytes.len))
    }

    func replace(_ data: Data, named name: String, for libraryID: UUID) throws {
        let result = call(libraryID, name: name) { root, id, name in
            data.withUnsafeBytes { buffer in
                ruffle_storage_replace(root, id, name, buffer.bindMemory(to: UInt8.self).baseAddress, UInt32(buffer.count))
            }
        }
        guard result == RUFFLE_RESULT_OK else { throw GameStorageError.invalidEntry }
    }

    func importData(_ data: Data, named name: String, for libraryID: UUID) throws {
        let previous = try? read(name, for: libraryID)
        do {
            try replace(data, named: name, for: libraryID)
            guard try read(name, for: libraryID) == data else { throw GameStorageError.verificationFailed }
        } catch {
            if let previous { try? replace(previous, named: name, for: libraryID) }
            else { try? delete(name, for: libraryID) }
            throw error
        }
    }

    func delete(_ name: String, for libraryID: UUID) throws {
        let result = call(libraryID, name: name) { root, id, name in
            ruffle_storage_delete(root, id, name)
        }
        guard result == RUFFLE_RESULT_OK else { throw GameStorageError.invalidEntry }
    }

    private func call(_ libraryID: UUID, _ body: (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32) -> Int32 {
        paths.rootURL.path.withCString { root in
            libraryID.uuidString.withCString { id in body(root, id) }
        }
    }

    private func call(_ libraryID: UUID, name: String, _ body: (UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32) -> Int32 {
        paths.rootURL.path.withCString { root in
            libraryID.uuidString.withCString { id in
                name.withCString { name in body(root, id, name) }
            }
        }
    }
}
