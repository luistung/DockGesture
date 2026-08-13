import XCTest
@testable import DockGestureCore

final class GestureClassifierTests: XCTestCase {
    func testPlainLeftClickHidesFrontmostDockApplication() {
        let decision = GestureClassifier.classify(.init(
            button: .left,
            modifiers: [],
            isDockApplication: true,
            isTargetFrontmost: true
        ))

        XCTAssertEqual(decision, .perform(.hide))
    }

    func testPlainLeftClickPassesThroughForBackgroundApplication() {
        let decision = GestureClassifier.classify(.init(
            button: .left,
            modifiers: [],
            isDockApplication: true,
            isTargetFrontmost: false
        ))

        XCTAssertEqual(decision, .passThrough)
    }

    func testModifiedLeftClickPassesThrough() {
        for modifier: GestureModifiers in [.command, .option, .control, .shift] {
            let decision = GestureClassifier.classify(.init(
                button: .left,
                modifiers: modifier,
                isDockApplication: true,
                isTargetFrontmost: true
            ))
            XCTAssertEqual(decision, .passThrough)
        }
    }

    func testCommandRightClickTerminates() {
        let decision = GestureClassifier.classify(.init(
            button: .right,
            modifiers: .command,
            isDockApplication: true,
            isTargetFrontmost: false
        ))

        XCTAssertEqual(decision, .perform(.terminate))
    }

    func testCommandOptionRightClickForceTerminates() {
        let decision = GestureClassifier.classify(.init(
            button: .right,
            modifiers: [.command, .option],
            isDockApplication: true,
            isTargetFrontmost: false
        ))

        XCTAssertEqual(decision, .perform(.forceTerminate))
    }

    func testRightClickWithControlOrShiftPassesThrough() {
        for modifiers: GestureModifiers in [
            [.command, .control],
            [.command, .shift],
            [.command, .option, .control],
            [.command, .option, .shift]
        ] {
            let decision = GestureClassifier.classify(.init(
                button: .right,
                modifiers: modifiers,
                isDockApplication: true,
                isTargetFrontmost: false
            ))
            XCTAssertEqual(decision, .passThrough)
        }
    }

    func testNonDockTargetAlwaysPassesThrough() {
        let decisions = [
            GestureClassifier.classify(.init(
                button: .left,
                modifiers: [],
                isDockApplication: false,
                isTargetFrontmost: true
            )),
            GestureClassifier.classify(.init(
                button: .right,
                modifiers: .command,
                isDockApplication: false,
                isTargetFrontmost: false
            ))
        ]

        XCTAssertEqual(decisions, [.passThrough, .passThrough])
    }
}
