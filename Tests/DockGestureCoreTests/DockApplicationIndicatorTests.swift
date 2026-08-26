import XCTest
@testable import DockGestureCore

final class DockApplicationIndicatorTests: XCTestCase {
    func testNoRunningInstancesHasNoIndicator() {
        XCTAssertEqual(DockApplicationIndicatorState.resolve(instances: []), .none)
    }

    func testFrontmostInstanceHasPriority() {
        XCTAssertEqual(
            DockApplicationIndicatorState.resolve(instances: [
                .init(isActive: false, isHidden: true),
                .init(isActive: true, isHidden: false)
            ]),
            .frontmost
        )
    }

    func testAnyVisibleBackgroundInstanceSuppressesHiddenIndicator() {
        XCTAssertEqual(
            DockApplicationIndicatorState.resolve(instances: [
                .init(isActive: false, isHidden: true),
                .init(isActive: false, isHidden: false)
            ]),
            .none
        )
    }

    func testAllHiddenInstancesUseHiddenIndicator() {
        XCTAssertEqual(
            DockApplicationIndicatorState.resolve(instances: [
                .init(isActive: false, isHidden: true),
                .init(isActive: false, isHidden: true)
            ]),
            .hidden
        )
    }

    func testIndicatorDiameterIsClampedAndScaled() {
        XCTAssertEqual(
            DockStateIndicatorLayout.diameter(
                for: DockIndicatorRect(x: 0, y: 0, width: 20, height: 20)
            ),
            10
        )
        XCTAssertEqual(
            DockStateIndicatorLayout.diameter(
                for: DockIndicatorRect(x: 0, y: 0, width: 50, height: 50)
            ),
            14,
            accuracy: 0.001
        )
        XCTAssertEqual(
            DockStateIndicatorLayout.diameter(
                for: DockIndicatorRect(x: 0, y: 0, width: 100, height: 100)
            ),
            18
        )
    }

    func testIndicatorIsAnchoredAtIconTopRight() {
        let iconFrame = DockIndicatorRect(x: 10, y: 20, width: 50, height: 50)
        let indicatorFrame = DockStateIndicatorLayout.frame(for: iconFrame)

        XCTAssertEqual(indicatorFrame.width, 14, accuracy: 0.001)
        XCTAssertEqual(indicatorFrame.height, 14, accuracy: 0.001)
        XCTAssertEqual(indicatorFrame.midX, iconFrame.maxX - 1)
        XCTAssertEqual(indicatorFrame.midY, iconFrame.maxY - 1)
    }

    func testAccessibilityCoordinatesFlipAroundMainDisplayHeight() {
        let accessibilityRect = DockIndicatorRect(
            x: 50,
            y: 900,
            width: 64,
            height: 64
        )

        XCTAssertEqual(
            DockAccessibilityCoordinateConverter.appKitRect(
                from: accessibilityRect,
                mainDisplayHeight: 1080
            ),
            DockIndicatorRect(x: 50, y: 116, width: 64, height: 64)
        )
    }
}
