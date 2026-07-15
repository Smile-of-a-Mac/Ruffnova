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
        XCTAssertEqual(profile.version, 2)
    }

    func testLegacyInputProfileWithoutVersionDecodesAsVersionTwo() throws {
        struct LegacyProfile: Codable {
            let mapping: [GameAction: UInt32]
        }
        let data = try JSONEncoder().encode(LegacyProfile(mapping: [.up: 82]))
        let profile = try JSONDecoder().decode(InputProfile.self, from: data)

        XCTAssertEqual(profile.version, 2)
        XCTAssertEqual(profile.mapping[.up], 82)
    }

    func testLegacyInputProfileVersionOneIsNormalizedToVersionTwo() throws {
        struct LegacyProfile: Codable {
            let version: Int
            let mapping: [GameAction: UInt32]
        }
        let data = try JSONEncoder().encode(LegacyProfile(version: 1, mapping: [.primary: 4]))

        let profile = try JSONDecoder().decode(InputProfile.self, from: data)

        XCTAssertEqual(profile.version, 2)
        XCTAssertEqual(profile.mapping[.primary], 4)
    }

    func testLegacyControllerBindingDefaultsToEnabled() throws {
        let data = Data("""
        [{"element":"a","action":"primary","pressThreshold":0.5,"releaseThreshold":0.4}]
        """.utf8)

        let bindings = try JSONDecoder().decode([ControllerBinding].self, from: data)

        XCTAssertEqual(bindings.count, 1)
        XCTAssertTrue(bindings[0].isEnabled)
    }

    @MainActor
    func testInputRouterIgnoresEventsOutsideFocusedInteractiveStage() {
        let router = InputRouter()
        var events: [(UInt32, Bool)] = []

        router.route(keyCode: 0x04, charCode: 0, isDown: true, modifiers: 0,
                     source: .keyboard(physicalHID: 0x04, modifiers: 0),
                     isInteractive: false, isStageFocused: true) { keyCode, _, isDown, _ in
            events.append((keyCode, isDown))
        }
        XCTAssertTrue(events.isEmpty)

        router.route(keyCode: 0x04, charCode: 0, isDown: true, modifiers: 0,
                     source: .keyboard(physicalHID: 0x04, modifiers: 0),
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
        let instanceID = InputProfileResolver.stableVirtualControlID(for: .primary)

        for _ in 0..<3 {
            router.route(keyCode: 0x04, charCode: 0, isDown: true, modifiers: 0,
                         source: .virtual(controlInstanceID: instanceID, action: .primary),
                         isInteractive: true, isStageFocused: true) { keyCode, _, isDown, _ in
                events.append((keyCode, isDown))
            }
        }
        router.route(keyCode: 0x04, charCode: 0, isDown: false, modifiers: 0,
                     source: .virtual(controlInstanceID: instanceID, action: .primary),
                     isInteractive: true, isStageFocused: true) { keyCode, _, isDown, _ in
            events.append((keyCode, isDown))
        }

        XCTAssertEqual(events.map(\.1), [true, false])
    }

    func testResolverMapsKeyboardBindingToConfiguredOutput() {
        let profile = InputProfile()
        let resolver = InputProfileResolver()
        let result = resolver.resolveKeyboard(physicalHID: 0x52, charCode: 0, modifiers: 0, profile: profile)

        XCTAssertEqual(result.keyCode, 0x52)
        XCTAssertEqual(result.source, .keyboard(physicalHID: 0x52, modifiers: 0))
    }

    func testResolverPassesThroughUnmappedKeyboardKey() {
        let profile = InputProfile()
        let resolver = InputProfileResolver()
        let unmappedHID: UInt32 = 0x3A // F1
        let result = resolver.resolveKeyboard(physicalHID: unmappedHID, charCode: 0, modifiers: 0, profile: profile)

        XCTAssertEqual(result.keyCode, unmappedHID)
        XCTAssertEqual(result.source, .keyboard(physicalHID: unmappedHID, modifiers: 0))
    }

    func testResolverUsesDefaultControllerBindingsWhenProfileHasNone() {
        let profile = InputProfile()
        let resolver = InputProfileResolver()
        let controllerID = UUID()
        let result = resolver.resolveController(element: .a, controllerID: controllerID, profile: profile)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keyCode, profile.mapping[.primary])
        XCTAssertEqual(result?.source, .controller(controllerID: controllerID, element: .a))
    }

    func testCustomControllerBindingOverridesOnlyItsElement() {
        var profile = InputProfile()
        profile.controllerBindings = [ControllerBinding(element: .a, action: .confirm)]
        let resolver = InputProfileResolver()

        let remapped = resolver.resolveController(element: .a, controllerID: UUID(), profile: profile)
        let defaulted = resolver.resolveController(element: .b, controllerID: UUID(), profile: profile)

        XCTAssertEqual(remapped?.keyCode, profile.mapping[.confirm])
        XCTAssertEqual(defaulted?.keyCode, profile.mapping[.secondary])
    }

    func testResolverReturnsNilForUnknownControllerElement() {
        let profile = InputProfile()
        let resolver = InputProfileResolver()
        let result = resolver.resolveController(element: .unknown, controllerID: UUID(), profile: profile)

        XCTAssertNil(result)
    }

    @MainActor
    func testTwoDifferentKeyboardKeysMappedToSameOutputAreTrackedIndependently() {
        // Bind both 0x04 (A) and 0x16 (S) to .primary which outputs 0x04
        var profile = InputProfile()
        profile.keyboardBindings = [
            KeyboardBinding(trigger: KeyboardTrigger(hidUsage: 0x04), action: .primary),
            KeyboardBinding(trigger: KeyboardTrigger(hidUsage: 0x16), action: .primary),
        ]
        let resolver = InputProfileResolver()
        let router = InputRouter()
        var events: [(UInt32, Bool)] = []
        let sendEvent: (UInt32, UInt32, Bool, UInt32) -> Void = { kc, _, dn, _ in events.append((kc, dn)) }

        let ra = resolver.resolveKeyboard(physicalHID: 0x04, charCode: 0, modifiers: 0, profile: profile)
        let rb = resolver.resolveKeyboard(physicalHID: 0x16, charCode: 0, modifiers: 0, profile: profile)

        // Press both keys
        router.route(keyCode: ra.keyCode, charCode: 0, isDown: true, modifiers: 0, source: ra.source, isInteractive: true, isStageFocused: true, send: sendEvent)
        router.route(keyCode: rb.keyCode, charCode: 0, isDown: true, modifiers: 0, source: rb.source, isInteractive: true, isStageFocused: true, send: sendEvent)
        // Release first key — should NOT send key-up yet (second still held)
        router.route(keyCode: ra.keyCode, charCode: 0, isDown: false, modifiers: 0, source: ra.source, isInteractive: true, isStageFocused: true, send: sendEvent)
        // Release second key — NOW sends key-up
        router.route(keyCode: rb.keyCode, charCode: 0, isDown: false, modifiers: 0, source: rb.source, isInteractive: true, isStageFocused: true, send: sendEvent)

        XCTAssertEqual(events.map(\.1), [true, false])
        XCTAssertEqual(events.map(\.0), [0x04, 0x04])
    }

    func testResolverDetectsConflictingKeyboardBindings() {
        var profile = InputProfile()
        profile.keyboardBindings = [
            KeyboardBinding(trigger: KeyboardTrigger(hidUsage: 0x04), action: .primary),
            KeyboardBinding(trigger: KeyboardTrigger(hidUsage: 0x04), action: .secondary),
        ]
        let resolver = InputProfileResolver()
        let conflicts = resolver.conflictingKeyboardBindings(in: profile)

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(Set([conflicts[0].0.action, conflicts[0].1.action]), Set([.primary, .secondary]))
    }

    func testStableVirtualControlIDsAreDistinctPerAction() {
        let ids = GameAction.allCases.map { InputProfileResolver.stableVirtualControlID(for: $0) }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    @MainActor
    func testTwoTouchControlInstancesForTheSameActionReleaseIndependently() {
        let router = InputRouter()
        var events: [(UInt32, Bool)] = []
        let first = UUID()
        let second = UUID()
        let send: (UInt32, UInt32, Bool, UInt32) -> Void = { keyCode, _, isDown, _ in
            events.append((keyCode, isDown))
        }

        for (id, isDown) in [(first, true), (second, true), (first, false), (second, false)] {
            router.route(
                keyCode: 0x04,
                charCode: 0,
                isDown: isDown,
                modifiers: 0,
                source: .virtual(controlInstanceID: id, action: .primary),
                isInteractive: true,
                isStageFocused: true,
                send: send
            )
        }

        XCTAssertEqual(events.map(\.0), [0x04, 0x04])
        XCTAssertEqual(events.map(\.1), [true, false])
    }
}
