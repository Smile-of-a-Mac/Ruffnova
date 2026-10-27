import XCTest
@testable import Ruffnova

@MainActor
final class TouchControlLayoutTests: XCTestCase {
    func testClassicPresetProvidesIndependentPortraitAndLandscapeLayouts() {
        let layouts = InputPreset.classic.layoutSet

        XCTAssertFalse(layouts.portrait.isEmpty)
        XCTAssertFalse(layouts.landscape.isEmpty)
        XCTAssertNotEqual(layouts.portrait, layouts.landscape)
    }

    func testClampingKeepsButtonInsideCanvasAtMinimumHitSize() {
        let control = TouchControlInstance(
            kind: .button,
            actions: [.primary],
            center: NormalizedPoint(x: 1.2, y: -0.2),
            size: NormalizedSize(width: 0.01, height: 0.01)
        )

        let clamped = TouchLayoutMetrics.clamped(control, in: CGSize(width: 200, height: 100))
        let frame = TouchLayoutMetrics.frame(for: clamped, in: CGSize(width: 200, height: 100))

        XCTAssertGreaterThanOrEqual(frame.minX, 0)
        XCTAssertGreaterThanOrEqual(frame.minY, 0)
        XCTAssertLessThanOrEqual(frame.maxX, 200)
        XCTAssertLessThanOrEqual(frame.maxY, 100)
        XCTAssertGreaterThanOrEqual(frame.width, 44)
        XCTAssertGreaterThanOrEqual(frame.height, 44)
    }

    func testDirectionalPadGuaranteesFourMinimumTouchTargets() {
        let control = TouchControlInstance(
            kind: .directionalPad,
            actions: [.up, .down, .left, .right],
            size: NormalizedSize(width: 0.1, height: 0.1)
        )

        let frame = TouchLayoutMetrics.frame(for: control, in: CGSize(width: 320, height: 320))

        XCTAssertGreaterThanOrEqual(frame.width, 88)
        XCTAssertGreaterThanOrEqual(frame.height, 88)
    }

    func testSquareControlStaysSquareOnPortraitReferenceCanvas() {
        let control = TouchControlInstance(
            kind: .button,
            actions: [.primary],
            size: NormalizedSize(width: 0.14, height: 0.14)
        )

        let frame = TouchLayoutMetrics.frame(for: control, in: CGSize(width: 320, height: 520))

        XCTAssertEqual(frame.width, frame.height, accuracy: 0.001)
    }

    func testCanvasLocationIsNormalizedAgainstTheWholeCanvas() {
        let point = TouchLayoutMetrics.normalizedPoint(
            for: CGPoint(x: 240, y: 390),
            in: CGSize(width: 320, height: 520)
        )

        XCTAssertEqual(point.x, 0.75, accuracy: 0.001)
        XCTAssertEqual(point.y, 0.75, accuracy: 0.001)
    }

    func testReferenceCanvasesMatchTheirLayoutOrientations() {
        XCTAssertEqual(
            TouchLayoutMetrics.referenceCanvas(for: .portrait),
            CGSize(width: 320, height: 520)
        )
        XCTAssertEqual(
            TouchLayoutMetrics.referenceCanvas(for: .landscape),
            CGSize(width: 520, height: 320)
        )
    }

    func testOverlapDetectionOnlyIncludesVisibleControls() {
        let first = TouchControlInstance(kind: .button, actions: [.primary])
        let second = TouchControlInstance(kind: .button, actions: [.secondary])
        let hidden = TouchControlInstance(kind: .button, actions: [.confirm], isEnabled: false)

        let overlaps = TouchLayoutMetrics.overlappingControlIDs(
            in: [first, second, hidden],
            canvasSize: CGSize(width: 300, height: 300)
        )

        XCTAssertEqual(overlaps, Set([first.id, second.id]))
    }

    func testDefaultPresetsDoNotOverlapTheirControls() {
        for preset in InputPreset.allCases {
            for orientation in TouchLayoutOrientation.allCases {
                let controls = preset.controls(for: orientation)
                let overlaps = TouchLayoutMetrics.overlappingControlIDs(
                    in: controls,
                    canvasSize: TouchLayoutMetrics.referenceCanvas(for: orientation)
                )

                XCTAssertTrue(
                    overlaps.isEmpty,
                    "\(preset.rawValue) \(orientation.rawValue) controls overlap: \(overlaps)"
                )
            }
        }
    }

    func testEditorChangesOnlyTheSelectedOrientationUntilSaved() {
        let editor = TouchLayoutEditorViewModel(layoutSet: InputPreset.classic.layoutSet)
        let originalLandscape = editor.layoutSet.landscape
        let control = try! XCTUnwrap(editor.controls.first)

        editor.move(controlID: control.id, to: NormalizedPoint(x: 0.7, y: 0.3), canvasSize: CGSize(width: 300, height: 600))

        XCTAssertNotEqual(editor.layoutSet.portrait, InputPreset.classic.layoutSet.portrait)
        XCTAssertEqual(editor.layoutSet.landscape, originalLandscape)
    }
}
