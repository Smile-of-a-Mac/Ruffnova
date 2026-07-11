import Foundation

enum GameAction: String, Codable, CaseIterable, Identifiable {
    case up
    case down
    case left
    case right
    case confirm
    case cancel
    case primary
    case secondary

    var id: String { rawValue }
}

struct InputProfile: Codable, Equatable {
    var version: Int
    var mapping: [GameAction: UInt32]

    init(version: Int = 1, mapping: [GameAction: UInt32] = Self.defaultMapping) {
        self.version = version
        self.mapping = mapping
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case mapping
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        mapping = try container.decodeIfPresent([GameAction: UInt32].self, forKey: .mapping) ?? Self.defaultMapping
    }

    static let defaultMapping: [GameAction: UInt32] = [
        .up: 0x52,
        .down: 0x51,
        .left: 0x50,
        .right: 0x4F,
        .confirm: 0x28,
        .cancel: 0x29,
        .primary: 0x04,
        .secondary: 0x16,
    ]
}

enum HIDKeyMapper {
    static func macVirtualKeyToHID(_ keyCode: UInt16) -> UInt32? {
        let mapping: [UInt16: UInt32] = [
            0: 0x04, 1: 0x16, 2: 0x07, 3: 0x09, 4: 0x0B, 5: 0x0A, 6: 0x1D, 7: 0x1B,
            8: 0x06, 9: 0x19, 11: 0x05, 12: 0x14, 13: 0x1A, 14: 0x08, 15: 0x15,
            16: 0x1C, 17: 0x17, 18: 0x1E, 19: 0x1F, 20: 0x20, 21: 0x21, 22: 0x23,
            23: 0x22, 24: 0x2E, 25: 0x26, 26: 0x24, 27: 0x2D, 28: 0x25, 29: 0x27,
            30: 0x30, 31: 0x12, 32: 0x18, 33: 0x2F, 34: 0x0C, 35: 0x13, 36: 0x28,
            37: 0x0F, 38: 0x0D, 39: 0x34, 40: 0x0E, 41: 0x33, 42: 0x31, 43: 0x36,
            44: 0x38, 45: 0x11, 46: 0x10, 47: 0x37, 48: 0x2B, 49: 0x2C, 50: 0x35,
            51: 0x2A, 53: 0x29, 54: 0xE7, 55: 0xE3, 56: 0xE1, 57: 0x39,
            58: 0xE2, 59: 0xE0, 60: 0xE5, 61: 0xE6, 62: 0xE4,
            65: 0x63, 67: 0x55, 69: 0x57, 75: 0x54, 76: 0x58, 77: 0x56,
            81: 0x67, 82: 0x62, 83: 0x59, 84: 0x5A, 85: 0x5B, 86: 0x5C,
            87: 0x5D, 88: 0x5E, 89: 0x5F, 91: 0x60, 92: 0x61,
            96: 0x3E, 97: 0x3F, 98: 0x40, 99: 0x3C, 100: 0x41, 101: 0x42,
            103: 0x44, 109: 0x43, 111: 0x45,
            123: 0x50, 124: 0x4F, 125: 0x51, 126: 0x52,
        ]
        return mapping[keyCode]
    }

    static func hidUsage(_ keyCode: UInt16) -> UInt32? {
        keyCode == 0 ? nil : UInt32(keyCode)
    }
}
