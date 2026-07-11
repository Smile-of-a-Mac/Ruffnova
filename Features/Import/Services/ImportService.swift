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

struct ImportPreview: Equatable {
    let newURLs: [URL]
    let duplicateURLs: [URL]

    init(candidates: [URL], existingURLs: [URL]) {
        let existing = Set(existingURLs.map(Self.identity))
        var seen = Set<String>()
        var newURLs: [URL] = []
        var duplicateURLs: [URL] = []

        for url in candidates {
            let identity = Self.identity(url)
            guard seen.insert(identity).inserted, !existing.contains(identity) else {
                duplicateURLs.append(url)
                continue
            }
            newURLs.append(url)
        }

        self.newURLs = newURLs
        self.duplicateURLs = duplicateURLs
    }

    static func identity(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}

struct ImportResult: Equatable {
    var addedURLs: [URL]
    var duplicateURLs: [URL]
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

    func scanForSWFFiles(in url: URL, recursively: Bool = true) throws -> [URL] {
        guard url.hasDirectoryPath else {
            throw ImportError.directoryScanFailed
        }

        return try collectSWFFiles(at: url, recursively: recursively)
    }

    private func collectSWFFiles(at url: URL, recursively: Bool) throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var results: [URL] = []
        for item in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue, recursively {
                results.append(contentsOf: try collectSWFFiles(at: item, recursively: true))
            } else if item.pathExtension.lowercased() == "swf" {
                results.append(item)
            }
        }
        return results.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}
