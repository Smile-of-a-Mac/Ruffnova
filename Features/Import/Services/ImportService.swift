import Foundation
import OSLog

enum ImportedContent {
    case swf(URL)
    case directory(URL)
    case zip(URL)
}

enum ImportError: Error {
    case unsupportedFormat
    case zipExtractionFailed
    case directoryScanFailed

    var messageKey: String {
        switch self {
        case .unsupportedFormat: return "error.unsupportedFormat"
        case .zipExtractionFailed: return "error.zipExtract"
        case .directoryScanFailed: return "error.directoryScan"
        }
    }
}

final class ImportService {
    static let shared = ImportService()

    private let logger = Logger(subsystem: "com.ruffnova", category: "import")
    private let fileManager = FileManager.default

    private init() {}

    func classify(_ url: URL) -> ImportedContent? {
        let ext = url.pathExtension.lowercased()
        if ext == "swf" {
            return .swf(url)
        } else if ext == "zip" {
            return .zip(url)
        } else if url.hasDirectoryPath {
            return .directory(url)
        }
        return nil
    }

    func resolveImport(for url: URL) throws -> ImportedContent {
        guard let content = classify(url) else {
            throw ImportError.unsupportedFormat
        }

        switch content {
        case .swf, .directory:
            return content
        case .zip:
            return .directory(try extractZip(url))
        }
    }

    func extractZip(_ url: URL) throws -> URL {
        #if os(macOS)
        let tmpDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", tmpDir.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ImportError.zipExtractionFailed
        }

        return tmpDir
        #else
        throw ImportError.zipExtractionFailed
        #endif
    }

    func scanForSWFFiles(in url: URL) throws -> [URL] {
        guard url.hasDirectoryPath else {
            throw ImportError.directoryScanFailed
        }

        return try collectSWFFiles(at: url)
    }

    private func collectSWFFiles(at url: URL) throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var results: [URL] = []
        for item in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                results.append(contentsOf: try collectSWFFiles(at: item))
            } else if item.pathExtension.lowercased() == "swf" {
                results.append(item)
            }
        }
        return results
    }
}
