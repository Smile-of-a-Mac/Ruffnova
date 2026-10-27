import Compression
import Foundation
import OSLog

/// Determines whether a SWF contains ActionScript keyboard input APIs that can
/// be driven by the app's virtual controls and physical game controllers.
struct SWFInputSupportDetector: Sendable {
    private static let maximumUncompressedMovieSize = 256 * 1_024 * 1_024
    private let logger = Logger(subsystem: "app.ruffnova.native", category: "input-detection")

    func supportsVirtualControls(at url: URL) -> Bool {
        do {
            return supportsVirtualControls(in: try Data(contentsOf: url, options: .mappedIfSafe))
        } catch {
            logger.error("Unable to read SWF input support data: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func supportsVirtualControls(in sourceData: Data) -> Bool {
        guard let movieData = movieData(from: sourceData),
              let tagOffset = firstTagOffset(in: movieData)
        else {
            return false
        }

        var offset = tagOffset
        while offset + 2 <= movieData.count {
            guard let header = movieData.uint16LE(at: offset) else { return false }
            offset += 2

            let tagCode = Int(header >> 6)
            var length = Int(header & 0x3F)
            if length == 0x3F {
                guard let longLength = movieData.uint32LE(at: offset) else { return false }
                length = Int(longLength)
                offset += 4
            }

            guard offset <= movieData.count - length else { return false }
            let payload = movieData.subdata(in: offset..<(offset + length))
            if supportsKeyboardInput(in: payload, for: tagCode) {
                return true
            }
            offset += length

            if tagCode == 0 {
                return false
            }
        }
        return false
    }

    private func movieData(from sourceData: Data) -> Data? {
        guard sourceData.count >= 8 else { return nil }

        switch sourceData.prefix(3) {
        case Data([0x46, 0x57, 0x53]):
            return sourceData
        case Data([0x43, 0x57, 0x53]):
            return decompressCWS(sourceData)
        default:
            return nil
        }
    }

    private func decompressCWS(_ sourceData: Data) -> Data? {
        guard let declaredLength = sourceData.uint32LE(at: 4) else { return nil }
        let expectedBodyLength = Int(declaredLength) - 8
        guard expectedBodyLength >= 0, expectedBodyLength <= Self.maximumUncompressedMovieSize else { return nil }

        let compressedBody = sourceData.dropFirst(8)
        guard !compressedBody.isEmpty else { return nil }

        var uncompressedBody = [UInt8](repeating: 0, count: expectedBodyLength)
        let decodedLength = uncompressedBody.withUnsafeMutableBufferPointer { destination in
            compressedBody.withUnsafeBytes { source in
                compression_decode_buffer(
                    destination.baseAddress!,
                    destination.count,
                    source.bindMemory(to: UInt8.self).baseAddress!,
                    source.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decodedLength == expectedBodyLength else { return nil }

        var movieData = Data([0x46, 0x57, 0x53, sourceData[3]])
        movieData.append(contentsOf: [
            UInt8(declaredLength & 0xFF),
            UInt8((declaredLength >> 8) & 0xFF),
            UInt8((declaredLength >> 16) & 0xFF),
            UInt8((declaredLength >> 24) & 0xFF),
        ])
        movieData.append(contentsOf: uncompressedBody)
        return movieData
    }

    private func firstTagOffset(in movieData: Data) -> Int? {
        guard movieData.count >= 9 else { return nil }
        let coordinateBitCount = Int(movieData[8] >> 3)
        let rectangleByteCount = (5 + coordinateBitCount * 4 + 7) / 8
        let tagOffset = 8 + rectangleByteCount + 4
        return tagOffset <= movieData.count ? tagOffset : nil
    }

    private func supportsKeyboardInput(in payload: Data, for tagCode: Int) -> Bool {
        switch tagCode {
        case 12: // DoAction
            return payloadContainsKeyboardInput(payload)
        case 59: // DoInitAction; the first two bytes identify the sprite.
            guard payload.count >= 2 else { return false }
            return payloadContainsKeyboardInput(payload.dropFirst(2))
        case 82: // DoABC; flags and the script name precede AVM2 bytecode.
            guard payload.count >= 5,
                  let nameTerminator = payload[4...].firstIndex(of: 0)
            else { return false }
            return payloadContainsKeyboardInput(payload[(nameTerminator + 1)...])
        default:
            return false
        }
    }

    private func payloadContainsKeyboardInput<S: DataProtocol>(_ payload: S) -> Bool {
        let data = Data(payload)
        let contains = { (text: String) in data.containsASCII(text) }

        if contains("KeyboardEvent") || contains("onKeyDown") || contains("onKeyUp") {
            return true
        }

        if contains("KEY_DOWN") || contains("KEY_UP") {
            return true
        }

        return contains("Key") && (
            contains("isDown") ||
            contains("isToggled") ||
            contains("getCode") ||
            contains("addListener")
        )
    }
}

private extension Data {
    func uint16LE(at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= count - 2 else { return nil }
        return UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func uint32LE(at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= count - 4 else { return nil }
        return UInt32(self[offset]) |
            UInt32(self[offset + 1]) << 8 |
            UInt32(self[offset + 2]) << 16 |
            UInt32(self[offset + 3]) << 24
    }

    func containsASCII(_ text: String) -> Bool {
        range(of: Data(text.utf8)) != nil
    }
}
