import Foundation

enum TouchLayoutOrientation: String, Codable, CaseIterable, Hashable, Identifiable {
    case portrait
    case landscape

    var id: String { rawValue }
}

extension TouchLayoutSet {
    var isEmpty: Bool {
        portrait.isEmpty && landscape.isEmpty
    }

    func controls(for orientation: TouchLayoutOrientation) -> [TouchControlInstance] {
        switch orientation {
        case .portrait:
            portrait
        case .landscape:
            landscape
        }
    }

    mutating func setControls(_ controls: [TouchControlInstance], for orientation: TouchLayoutOrientation) {
        switch orientation {
        case .portrait:
            portrait = controls
        case .landscape:
            landscape = controls
        }
    }

    func resolvedControls(for orientation: TouchLayoutOrientation) -> [TouchControlInstance] {
        guard !isEmpty else { return InputPreset.classic.controls(for: orientation) }
        return controls(for: orientation)
    }
}

enum TouchLayoutMetrics {
    static let minimumTouchTarget: CGFloat = 44

    static func frame(for control: TouchControlInstance, in canvasSize: CGSize) -> CGRect {
        let size = renderedSize(for: control, in: canvasSize)
        let center = CGPoint(
            x: CGFloat(control.center.x) * canvasSize.width,
            y: CGFloat(control.center.y) * canvasSize.height
        )
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func renderedSize(for control: TouchControlInstance, in canvasSize: CGSize) -> CGSize {
        let minimum = minimumRenderedSize(for: control.kind)
        let requested = CGSize(
            width: CGFloat(control.size.width) * canvasSize.width,
            height: CGFloat(control.size.height) * canvasSize.height
        )
        return CGSize(
            width: min(max(minimum.width, requested.width), canvasSize.width),
            height: min(max(minimum.height, requested.height), canvasSize.height)
        )
    }

    static func clamped(_ control: TouchControlInstance, in canvasSize: CGSize) -> TouchControlInstance {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return control }
        let size = renderedSize(for: control, in: canvasSize)
        let halfWidth = size.width / canvasSize.width / 2
        let halfHeight = size.height / canvasSize.height / 2
        let center = NormalizedPoint(
            x: min(max(control.center.x, Double(halfWidth)), Double(1 - halfWidth)),
            y: min(max(control.center.y, Double(halfHeight)), Double(1 - halfHeight))
        )
        let normalizedSize = NormalizedSize(
            width: Double(size.width / canvasSize.width),
            height: Double(size.height / canvasSize.height)
        )
        var clamped = control
        clamped.center = center
        clamped.size = normalizedSize
        return clamped
    }

    static func overlappingControlIDs(
        in controls: [TouchControlInstance],
        canvasSize: CGSize
    ) -> Set<UUID> {
        let visible = controls.filter(\.isEnabled)
        var ids = Set<UUID>()
        for firstIndex in visible.indices {
            for secondIndex in visible.indices where secondIndex > firstIndex {
                if frame(for: visible[firstIndex], in: canvasSize)
                    .intersects(frame(for: visible[secondIndex], in: canvasSize)) {
                    ids.insert(visible[firstIndex].id)
                    ids.insert(visible[secondIndex].id)
                }
            }
        }
        return ids
    }

    private static func minimumRenderedSize(for kind: TouchControlKind) -> CGSize {
        switch kind {
        case .button:
            CGSize(width: minimumTouchTarget, height: minimumTouchTarget)
        case .directionalPad:
            CGSize(width: minimumTouchTarget * 2, height: minimumTouchTarget * 2)
        case .unknown:
            CGSize(width: minimumTouchTarget, height: minimumTouchTarget)
        }
    }
}
