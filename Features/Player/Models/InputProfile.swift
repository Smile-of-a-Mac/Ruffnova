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
    var actionOutputs: [GameAction: GameKeyOutput]
    var keyboardBindings: [KeyboardBinding]
    var controllerBindings: [ControllerBinding]
    var touchLayouts: TouchLayoutSet

    init(version: Int = 2, mapping: [GameAction: UInt32] = Self.defaultMapping) {
        self.version = version
        self.actionOutputs = Self.outputs(from: mapping)
        self.keyboardBindings = Self.defaultKeyboardBindings
        self.controllerBindings = []
        self.touchLayouts = TouchLayoutSet()
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case mapping
        case actionOutputs
        case keyboardBindings
        case controllerBindings
        case touchLayouts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        if let actionOutputs = try container.decodeIfPresent([GameAction: GameKeyOutput].self, forKey: .actionOutputs) {
            version = max(decodedVersion, 2)
            self.actionOutputs = actionOutputs
            keyboardBindings = try container.decodeIfPresent([KeyboardBinding].self, forKey: .keyboardBindings) ?? Self.defaultKeyboardBindings
            controllerBindings = try container.decodeIfPresent([ControllerBinding].self, forKey: .controllerBindings) ?? []
            touchLayouts = try container.decodeIfPresent(TouchLayoutSet.self, forKey: .touchLayouts) ?? TouchLayoutSet()
        } else {
            version = 2
            let mapping = try container.decodeIfPresent([GameAction: UInt32].self, forKey: .mapping) ?? Self.defaultMapping
            self.actionOutputs = Self.outputs(from: mapping)
            keyboardBindings = Self.defaultKeyboardBindings
            controllerBindings = []
            touchLayouts = TouchLayoutSet()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if version < 2 {
            try container.encode(version, forKey: .version)
            try container.encode(mapping, forKey: .mapping)
            return
        }

        try container.encode(2, forKey: .version)
        try container.encode(actionOutputs, forKey: .actionOutputs)
        try container.encode(keyboardBindings, forKey: .keyboardBindings)
        try container.encode(controllerBindings, forKey: .controllerBindings)
        try container.encode(touchLayouts, forKey: .touchLayouts)
    }

    var mapping: [GameAction: UInt32] {
        get { actionOutputs.mapValues(\.keyCode) }
        set { actionOutputs = Self.outputs(from: newValue) }
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

    private static let defaultKeyboardBindings: [KeyboardBinding] = GameAction.allCases.compactMap { action in
        guard let hidUsage = defaultMapping[action] else { return nil }
        return KeyboardBinding(
            trigger: KeyboardTrigger(hidUsage: hidUsage),
            action: action
        )
    }

    private static func outputs(from mapping: [GameAction: UInt32]) -> [GameAction: GameKeyOutput] {
        mapping.mapValues { GameKeyOutput(keyCode: $0) }
    }
}

struct GameKeyOutput: Codable, Equatable {
    var keyCode: UInt32
    var charCode: UInt32
    var modifiers: UInt32

    init(keyCode: UInt32, charCode: UInt32 = 0, modifiers: UInt32 = 0) {
        self.keyCode = keyCode
        self.charCode = charCode
        self.modifiers = modifiers
    }
}

struct KeyboardTrigger: Codable, Equatable {
    var hidUsage: UInt32
    var requiredModifiers: UInt32

    init(hidUsage: UInt32, requiredModifiers: UInt32 = 0) {
        self.hidUsage = hidUsage
        self.requiredModifiers = requiredModifiers
    }
}

struct KeyboardBinding: Codable, Equatable, Identifiable {
    var trigger: KeyboardTrigger
    var action: GameAction
    var isEnabled: Bool

    var id: String {
        "\(trigger.hidUsage)-\(trigger.requiredModifiers)-\(action.rawValue)"
    }

    init(trigger: KeyboardTrigger, action: GameAction, isEnabled: Bool = true) {
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
    }
}

enum ControllerElement: String, Codable, CaseIterable {
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case a
    case b
    case x
    case y
    case menu
    case options
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case leftThumbstickButton
    case rightThumbstickButton
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

struct ControllerBinding: Codable, Equatable, Identifiable {
    var element: ControllerElement
    var action: GameAction
    var pressThreshold: Float
    var releaseThreshold: Float
    var isEnabled: Bool

    var id: String { "\(element.rawValue)-\(action.rawValue)" }

    init(
        element: ControllerElement,
        action: GameAction,
        pressThreshold: Float = 0.5,
        releaseThreshold: Float = 0.4,
        isEnabled: Bool = true
    ) {
        self.element = element
        self.action = action
        self.pressThreshold = pressThreshold
        self.releaseThreshold = releaseThreshold
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case element
        case action
        case pressThreshold
        case releaseThreshold
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        element = try container.decode(ControllerElement.self, forKey: .element)
        action = try container.decode(GameAction.self, forKey: .action)
        pressThreshold = try container.decodeIfPresent(Float.self, forKey: .pressThreshold) ?? 0.5
        releaseThreshold = try container.decodeIfPresent(Float.self, forKey: .releaseThreshold) ?? 0.4
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(element, forKey: .element)
        try container.encode(action, forKey: .action)
        try container.encode(pressThreshold, forKey: .pressThreshold)
        try container.encode(releaseThreshold, forKey: .releaseThreshold)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

enum TouchControlKind: String, Codable, CaseIterable {
    case button
    case directionalPad
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

struct NormalizedPoint: Codable, Equatable {
    var x: Double
    var y: Double

    init(x: Double = 0.5, y: Double = 0.5) {
        self.x = x
        self.y = y
    }
}

struct NormalizedSize: Codable, Equatable {
    var width: Double
    var height: Double

    init(width: Double = 0.1, height: Double = 0.1) {
        self.width = width
        self.height = height
    }
}

struct TouchControlInstance: Codable, Equatable, Identifiable {
    var id: UUID
    var kind: TouchControlKind
    var actions: [GameAction]
    var center: NormalizedPoint
    var size: NormalizedSize
    var opacity: Double
    var isEnabled: Bool
    var zIndex: Int

    init(
        id: UUID = UUID(),
        kind: TouchControlKind,
        actions: [GameAction],
        center: NormalizedPoint = NormalizedPoint(),
        size: NormalizedSize = NormalizedSize(),
        opacity: Double = 1,
        isEnabled: Bool = true,
        zIndex: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.actions = actions
        self.center = center
        self.size = size
        self.opacity = opacity
        self.isEnabled = isEnabled
        self.zIndex = zIndex
    }
}

struct TouchLayoutSet: Codable, Equatable {
    var portrait: [TouchControlInstance]
    var landscape: [TouchControlInstance]

    init(portrait: [TouchControlInstance] = [], landscape: [TouchControlInstance] = []) {
        self.portrait = portrait
        self.landscape = landscape
    }
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
