import Compression
import XCTest
@testable import Ruffnova

final class SWFInputSupportDetectorTests: XCTestCase {
    private let detector = SWFInputSupportDetector()

    func testDetectsActionScriptTwoKeyPolling() {
        let swf = makeSWF(script: "Key\0isDown\0")

        XCTAssertTrue(detector.supportsVirtualControls(in: swf))
    }

    func testDetectsActionScriptThreeKeyboardEvents() {
        let swf = makeSWF(script: "KeyboardEvent\0KEY_DOWN\0")

        XCTAssertTrue(detector.supportsVirtualControls(in: swf))
    }

    func testDetectsKeyboardInputInCompressedSWF() {
        let compressedSWF = compress(makeSWF(script: "Key\0isDown\0"))

        XCTAssertTrue(detector.supportsVirtualControls(in: compressedSWF))
    }

    func testDoesNotClassifyMouseOnlyContentAsSupportingVirtualControls() {
        let swf = makeSWF(script: "Mouse\0onPress\0onRelease\0_xmouse\0_ymouse\0")

        XCTAssertFalse(detector.supportsVirtualControls(in: swf))
    }

    func testDoesNotClassifyInvalidDataAsSupportingVirtualControls() {
        XCTAssertFalse(detector.supportsVirtualControls(in: Data("not a SWF".utf8)))
    }

    private func makeSWF(script: String) -> Data {
        var data = Data([0x46, 0x57, 0x53, 9, 0, 0, 0, 0])
        data.append(contentsOf: [0x08, 0x00, 0x00, 0x00, 0x01, 0x00])

        let scriptData = Data(script.utf8)
        let tagHeader = UInt16((12 << 6) | scriptData.count)
        data.append(UInt8(tagHeader & 0xFF))
        data.append(UInt8(tagHeader >> 8))
        data.append(scriptData)
        data.append(contentsOf: [0x00, 0x00])

        let length = UInt32(data.count)
        data.replaceSubrange(4..<8, with: [
            UInt8(length & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 24) & 0xFF),
        ])
        return data
    }

    private func compress(_ swf: Data) -> Data {
        let uncompressedBody = swf.dropFirst(8)
        var compressedBody = [UInt8](repeating: 0, count: uncompressedBody.count + 64)
        let compressedLength = compressedBody.withUnsafeMutableBufferPointer { destination in
            uncompressedBody.withUnsafeBytes { source in
                compression_encode_buffer(
                    destination.baseAddress!,
                    destination.count,
                    source.bindMemory(to: UInt8.self).baseAddress!,
                    source.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        XCTAssertGreaterThan(compressedLength, 0)

        var compressedSWF = Data([0x43, 0x57, 0x53])
        compressedSWF.append(swf[3])
        compressedSWF.append(swf[4..<8])
        compressedSWF.append(contentsOf: compressedBody.prefix(compressedLength))
        return compressedSWF
    }
}
