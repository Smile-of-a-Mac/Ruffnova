import Foundation

enum InputPreset: String, Codable, CaseIterable, Identifiable {
    case classic
    case compact
    case leftHanded
    case minimal

    var id: String { rawValue }

    var layoutSet: TouchLayoutSet {
        TouchLayoutSet(
            portrait: controls(for: .portrait),
            landscape: controls(for: .landscape)
        )
    }

    func controls(for orientation: TouchLayoutOrientation) -> [TouchControlInstance] {
        let isLandscape = orientation == .landscape
        switch self {
        case .classic:
            return classicControls(isLandscape: isLandscape)
        case .compact:
            return compactControls(isLandscape: isLandscape)
        case .leftHanded:
            return leftHandedControls(isLandscape: isLandscape)
        case .minimal:
            return minimalControls(isLandscape: isLandscape)
        }
    }

    private func classicControls(isLandscape: Bool) -> [TouchControlInstance] {
        let dpadCenter = isLandscape ? NormalizedPoint(x: 0.16, y: 0.78) : NormalizedPoint(x: 0.19, y: 0.78)
        return [
            directionalPad(id: "20000000-0000-0000-0000-000000000001", center: dpadCenter, size: isLandscape ? 0.22 : 0.28),
            button(id: "20000000-0000-0000-0000-000000000002", action: .primary, center: NormalizedPoint(x: 0.84, y: 0.76)),
            button(id: "20000000-0000-0000-0000-000000000003", action: .secondary, center: NormalizedPoint(x: 0.68, y: 0.76)),
            button(id: "20000000-0000-0000-0000-000000000004", action: .confirm, center: NormalizedPoint(x: 0.84, y: 0.50)),
            button(id: "20000000-0000-0000-0000-000000000005", action: .cancel, center: NormalizedPoint(x: 0.68, y: 0.50)),
        ]
    }

    private func compactControls(isLandscape: Bool) -> [TouchControlInstance] {
        let dpadCenter = isLandscape ? NormalizedPoint(x: 0.14, y: 0.83) : NormalizedPoint(x: 0.16, y: 0.82)
        let primaryCenter = isLandscape ? NormalizedPoint(x: 0.87, y: 0.82) : NormalizedPoint(x: 0.84, y: 0.78)
        return [
            directionalPad(id: "20000000-0000-0000-0000-000000000011", center: dpadCenter, size: isLandscape ? 0.18 : 0.22),
            button(id: "20000000-0000-0000-0000-000000000012", action: .primary, center: primaryCenter, size: 0.11),
            button(id: "20000000-0000-0000-0000-000000000013", action: .secondary, center: offset(primaryCenter, x: -0.16, y: 0), size: 0.11),
        ]
    }

    private func leftHandedControls(isLandscape: Bool) -> [TouchControlInstance] {
        let dpadCenter = isLandscape ? NormalizedPoint(x: 0.84, y: 0.78) : NormalizedPoint(x: 0.81, y: 0.78)
        return [
            directionalPad(id: "20000000-0000-0000-0000-000000000021", center: dpadCenter, size: isLandscape ? 0.22 : 0.28),
            button(id: "20000000-0000-0000-0000-000000000022", action: .primary, center: NormalizedPoint(x: 0.16, y: 0.76)),
            button(id: "20000000-0000-0000-0000-000000000023", action: .secondary, center: NormalizedPoint(x: 0.32, y: 0.76)),
            button(id: "20000000-0000-0000-0000-000000000024", action: .confirm, center: NormalizedPoint(x: 0.16, y: 0.50)),
            button(id: "20000000-0000-0000-0000-000000000025", action: .cancel, center: NormalizedPoint(x: 0.32, y: 0.50)),
        ]
    }

    private func minimalControls(isLandscape: Bool) -> [TouchControlInstance] {
        let dpadCenter = isLandscape ? NormalizedPoint(x: 0.15, y: 0.82) : NormalizedPoint(x: 0.18, y: 0.82)
        let primaryCenter = isLandscape ? NormalizedPoint(x: 0.85, y: 0.82) : NormalizedPoint(x: 0.82, y: 0.80)
        return [
            directionalPad(id: "20000000-0000-0000-0000-000000000031", center: dpadCenter, size: isLandscape ? 0.18 : 0.22),
            button(id: "20000000-0000-0000-0000-000000000032", action: .primary, center: primaryCenter),
        ]
    }

    private func directionalPad(id: String, center: NormalizedPoint, size: Double) -> TouchControlInstance {
        TouchControlInstance(
            id: UUID(uuidString: id)!,
            kind: .directionalPad,
            actions: [.up, .down, .left, .right],
            center: center,
            size: NormalizedSize(width: size, height: size),
            opacity: 0.82
        )
    }

    private func button(id: String, action: GameAction, center: NormalizedPoint, size: Double = 0.14) -> TouchControlInstance {
        TouchControlInstance(
            id: UUID(uuidString: id)!,
            kind: .button,
            actions: [action],
            center: center,
            size: NormalizedSize(width: size, height: size),
            opacity: 0.82
        )
    }

    private func offset(_ point: NormalizedPoint, x: Double, y: Double) -> NormalizedPoint {
        NormalizedPoint(x: point.x + x, y: point.y + y)
    }
}
