import XCTest
@testable import DockGestureCore

final class DisplayCyclePlannerTests: XCTestCase {
    private let left = WindowMoveDisplay(
        fullFrame: .init(x: 0, y: 0, width: 1000, height: 800),
        visibleFrame: .init(x: 0, y: 20, width: 1000, height: 760)
    )
    private let right = WindowMoveDisplay(
        fullFrame: .init(x: 1000, y: 0, width: 1200, height: 900),
        visibleFrame: .init(x: 1000, y: 20, width: 1200, height: 860)
    )

    func testRequiresAtLeastTwoDisplays() {
        XCTAssertEqual(
            DisplayCyclePlanner.plan(
                window: .init(x: 100, y: 100, width: 400, height: 300),
                displays: [left]
            ),
            .insufficientDisplays
        )
    }

    func testCyclesToNextDisplayAndWraps() {
        let leftToRight = DisplayCyclePlanner.plan(
            window: .init(x: 100, y: 100, width: 400, height: 300),
            displays: [left, right]
        )
        let rightToLeft = DisplayCyclePlanner.plan(
            window: .init(x: 1200, y: 100, width: 400, height: 300),
            displays: [left, right]
        )

        XCTAssertEqual(leftToRight.movePlan?.sourceDisplayIndex, 0)
        XCTAssertEqual(leftToRight.movePlan?.targetDisplayIndex, 1)
        XCTAssertEqual(rightToLeft.movePlan?.sourceDisplayIndex, 1)
        XCTAssertEqual(rightToLeft.movePlan?.targetDisplayIndex, 0)
    }

    func testThreeDisplaysCycleInListOrder() {
        let third = WindowMoveDisplay(
            fullFrame: .init(x: 2200, y: 0, width: 800, height: 700),
            visibleFrame: .init(x: 2200, y: 20, width: 800, height: 660)
        )

        let result = DisplayCyclePlanner.plan(
            window: .init(x: 2300, y: 100, width: 300, height: 200),
            displays: [left, right, third]
        )

        XCTAssertEqual(result.movePlan?.sourceDisplayIndex, 2)
        XCTAssertEqual(result.movePlan?.targetDisplayIndex, 0)
    }

    func testChoosesSourceByLargestIntersection() {
        let result = DisplayCyclePlanner.plan(
            window: .init(x: 850, y: 100, width: 500, height: 300),
            displays: [left, right]
        )

        XCTAssertEqual(result.movePlan?.sourceDisplayIndex, 1)
    }

    func testPreservesRelativePositionOnDifferentDisplaySize() {
        let result = DisplayCyclePlanner.plan(
            window: .init(x: 600, y: 404, width: 200, height: 200),
            displays: [left, right]
        )

        guard let frame = result.movePlan?.targetWindowFrame else {
            return XCTFail("Expected move plan")
        }
        XCTAssertEqual(frame.x, 1750, accuracy: 0.001)
        XCTAssertEqual(frame.y, 472.571, accuracy: 0.001)
        XCTAssertEqual(frame.width, 200)
        XCTAssertEqual(frame.height, 200)
    }

    func testShrinksOversizedWindowAndKeepsItVisible() {
        let small = WindowMoveDisplay(
            fullFrame: .init(x: 1000, y: 0, width: 500, height: 400),
            visibleFrame: .init(x: 1000, y: 20, width: 500, height: 360)
        )
        let result = DisplayCyclePlanner.plan(
            window: .init(x: 50, y: 50, width: 900, height: 700),
            displays: [left, small]
        )

        guard let plan = result.movePlan else {
            return XCTFail("Expected move plan")
        }
        XCTAssertEqual(plan.targetWindowFrame, small.visibleFrame)
        XCTAssertTrue(plan.requiresResize)
    }

    func testDoesNotResizeWindowThatFitsTarget() {
        let result = DisplayCyclePlanner.plan(
            window: .init(x: 100, y: 100, width: 400, height: 300),
            displays: [left, right]
        )

        XCTAssertFalse(result.movePlan?.requiresResize ?? true)
        XCTAssertEqual(result.movePlan?.targetWindowFrame.width, 400)
        XCTAssertEqual(result.movePlan?.targetWindowFrame.height, 300)
    }

    func testFullScreenShapedWindowIsRejected() {
        XCTAssertEqual(
            DisplayCyclePlanner.plan(window: left.fullFrame, displays: [left, right]),
            .fullScreenWindow
        )
    }
}
