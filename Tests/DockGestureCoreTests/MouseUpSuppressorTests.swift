import XCTest
@testable import DockGestureCore

final class MouseUpSuppressorTests: XCTestCase {
    func testConsumesOnlyMatchingMouseUpOnce() {
        var suppressor = MouseUpSuppressor()
        suppressor.beginSuppressing(.right)

        XCTAssertFalse(suppressor.consumeMouseUp(for: .left))
        XCTAssertTrue(suppressor.consumeMouseUp(for: .right))
        XCTAssertFalse(suppressor.consumeMouseUp(for: .right))
    }

    func testResetClearsSuppression() {
        var suppressor = MouseUpSuppressor()
        suppressor.beginSuppressing(.left)
        suppressor.reset()

        XCTAssertFalse(suppressor.consumeMouseUp(for: .left))
    }
}
