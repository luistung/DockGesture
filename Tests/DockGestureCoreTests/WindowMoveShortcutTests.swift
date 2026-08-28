import XCTest
@testable import DockGestureCore

final class WindowMoveShortcutTests: XCTestCase {
    func testFnReturnTriggersAndSuppressesKeyUp() {
        var classifier = WindowMoveShortcutClassifier()

        XCTAssertEqual(
            classifier.classify(.init(
                eventType: .keyDown,
                keyCode: WindowMoveShortcutKey.returnKeyCode,
                modifiers: [.function],
                isAutoRepeat: false
            )),
            .triggerAndSuppress
        )
        XCTAssertEqual(
            classifier.classify(.init(
                eventType: .keyUp,
                keyCode: WindowMoveShortcutKey.returnKeyCode,
                modifiers: [],
                isAutoRepeat: false
            )),
            .suppress
        )
    }

    func testFnKeypadEnterAlsoTriggers() {
        var classifier = WindowMoveShortcutClassifier()

        XCTAssertEqual(
            classifier.classify(.init(
                eventType: .keyDown,
                keyCode: WindowMoveShortcutKey.keypadEnterKeyCode,
                modifiers: [.function, .numericPad],
                isAutoRepeat: false
            )),
            .triggerAndSuppress
        )
    }

    func testBareReturnAndKeypadEnterPassThrough() {
        for keyCode in [
            WindowMoveShortcutKey.returnKeyCode,
            WindowMoveShortcutKey.keypadEnterKeyCode
        ] {
            var classifier = WindowMoveShortcutClassifier()
            XCTAssertEqual(
                classifier.classify(.init(
                    eventType: .keyDown,
                    keyCode: keyCode,
                    modifiers: [],
                    isAutoRepeat: false
                )),
                .passThrough
            )
        }
    }

    func testConflictingModifiersPassThrough() {
        for modifier: WindowMoveShortcutModifiers in [
            .command,
            .option,
            .control,
            .shift
        ] {
            var classifier = WindowMoveShortcutClassifier()
            XCTAssertEqual(
                classifier.classify(.init(
                    eventType: .keyDown,
                    keyCode: WindowMoveShortcutKey.returnKeyCode,
                    modifiers: [.function, modifier],
                    isAutoRepeat: false
                )),
                .passThrough
            )
        }
    }

    func testCapsLockDoesNotPreventShortcut() {
        var classifier = WindowMoveShortcutClassifier()

        XCTAssertEqual(
            classifier.classify(.init(
                eventType: .keyDown,
                keyCode: WindowMoveShortcutKey.returnKeyCode,
                modifiers: [.function, .capsLock],
                isAutoRepeat: false
            )),
            .triggerAndSuppress
        )
    }

    func testAutoRepeatSuppressesWithoutTriggeringAgain() {
        var classifier = WindowMoveShortcutClassifier()
        _ = classifier.classify(.init(
            eventType: .keyDown,
            keyCode: WindowMoveShortcutKey.returnKeyCode,
            modifiers: [.function],
            isAutoRepeat: false
        ))

        XCTAssertEqual(
            classifier.classify(.init(
                eventType: .keyDown,
                keyCode: WindowMoveShortcutKey.returnKeyCode,
                modifiers: [.function],
                isAutoRepeat: true
            )),
            .suppress
        )
    }

    func testHeldReturnStaysSuppressedAfterFnIsReleased() {
        var classifier = WindowMoveShortcutClassifier()
        _ = classifier.classify(.init(
            eventType: .keyDown,
            keyCode: WindowMoveShortcutKey.returnKeyCode,
            modifiers: [.function],
            isAutoRepeat: false
        ))

        XCTAssertEqual(
            classifier.classify(.init(
                eventType: .keyDown,
                keyCode: WindowMoveShortcutKey.returnKeyCode,
                modifiers: [],
                isAutoRepeat: true
            )),
            .suppress
        )
    }

    func testUnrelatedKeyPassesThrough() {
        var classifier = WindowMoveShortcutClassifier()

        XCTAssertEqual(
            classifier.classify(.init(
                eventType: .keyDown,
                keyCode: 49,
                modifiers: [.function],
                isAutoRepeat: false
            )),
            .passThrough
        )
    }

    func testResetStopsSuppressingPendingKeyUp() {
        var classifier = WindowMoveShortcutClassifier()
        _ = classifier.classify(.init(
            eventType: .keyDown,
            keyCode: WindowMoveShortcutKey.returnKeyCode,
            modifiers: [.function],
            isAutoRepeat: false
        ))
        classifier.reset()

        XCTAssertEqual(
            classifier.classify(.init(
                eventType: .keyUp,
                keyCode: WindowMoveShortcutKey.returnKeyCode,
                modifiers: [],
                isAutoRepeat: false
            )),
            .passThrough
        )
    }
}
