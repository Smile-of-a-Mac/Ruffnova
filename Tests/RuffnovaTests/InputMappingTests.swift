import XCTest
@testable import Ruffnova

final class InputMappingTests: XCTestCase {
    func testMapsMacArrowAndReturnKeysToUSBHID() {
        XCTAssertEqual(HIDKeyMapper.macVirtualKeyToHID(123), 0x50)
        XCTAssertEqual(HIDKeyMapper.macVirtualKeyToHID(36), 0x28)
    }

    func testMapsMacLettersAndDigitsToUSBHID() {
        XCTAssertEqual(HIDKeyMapper.macVirtualKeyToHID(0), 0x04)
        XCTAssertEqual(HIDKeyMapper.macVirtualKeyToHID(6), 0x1D)
        XCTAssertEqual(HIDKeyMapper.macVirtualKeyToHID(7), 0x1B)
        XCTAssertEqual(HIDKeyMapper.macVirtualKeyToHID(8), 0x06)
        XCTAssertEqual(HIDKeyMapper.macVirtualKeyToHID(18), 0x1E)
        XCTAssertEqual(HIDKeyMapper.macVirtualKeyToHID(29), 0x27)
    }

    func testUnknownPlatformKeyDoesNotBecomeAValidGameKey() {
        XCTAssertNil(HIDKeyMapper.macVirtualKeyToHID(999))
    }

    func testDefaultInputProfileUsesExpectedGameActions() throws {
        let profile = InputProfile()

        XCTAssertEqual(profile.mapping[.up], 0x52)
        XCTAssertEqual(profile.mapping[.confirm], 0x28)
        XCTAssertEqual(profile.mapping[.cancel], 0x29)
        XCTAssertEqual(profile.version, 1)
    }

    func testLegacyInputProfileWithoutVersionDecodesAsVersionOne() throws {
        struct LegacyProfile: Codable {
            let mapping: [GameAction: UInt32]
        }
        let data = try JSONEncoder().encode(LegacyProfile(mapping: [.up: 82]))
        let profile = try JSONDecoder().decode(InputProfile.self, from: data)

        XCTAssertEqual(profile.version, 1)
        XCTAssertEqual(profile.mapping[.up], 82)
    }

    @MainActor
    func testInputRouterIgnoresEventsOutsideFocusedInteractiveStage() {
        let router = InputRouter()
        var events: [(UInt32, Bool)] = []

        router.route(keyCode: 0x04, charCode: 0, isDown: true, modifiers: 0,
                     isInteractive: false, isStageFocused: true) { keyCode, _, isDown, _ in
            events.append((keyCode, isDown))
        }
        XCTAssertTrue(events.isEmpty)

        router.route(keyCode: 0x04, charCode: 0, isDown: true, modifiers: 0,
                     isInteractive: true, isStageFocused: true) { keyCode, _, isDown, _ in
            events.append((keyCode, isDown))
        }
        router.releaseAll { keyCode, _, isDown, _ in
            events.append((keyCode, isDown))
        }

        XCTAssertEqual(events.map(\.1), [true, false])
    }

    @MainActor
    func testInputRouterSendsOneDownAndOneUpForRepeatedSourceEvents() {
        let router = InputRouter()
        var events: [(UInt32, Bool)] = []

        for _ in 0..<3 {
            router.route(keyCode: 0x04, charCode: 0, isDown: true, modifiers: 0,
                         source: .virtual(.primary), isInteractive: true, isStageFocused: true) { keyCode, _, isDown, _ in
                events.append((keyCode, isDown))
            }
        }
        router.route(keyCode: 0x04, charCode: 0, isDown: false, modifiers: 0,
                     source: .virtual(.primary), isInteractive: true, isStageFocused: true) { keyCode, _, isDown, _ in
            events.append((keyCode, isDown))
        }

        XCTAssertEqual(events.map(\.1), [true, false])
    }
}
