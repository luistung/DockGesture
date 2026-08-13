import XCTest
@testable import DockGestureCore

final class ApplicationActionExecutorTests: XCTestCase {
    func testTerminateFailureDoesNotEscalateToForceTerminate() {
        let target = TargetStub(terminateResult: false)

        let result = ApplicationActionExecutor.perform(.terminate, on: target)

        XCTAssertFalse(result)
        XCTAssertEqual(target.calls, [.terminate])
    }

    func testForceTerminateCallsOnlyForceTerminate() {
        let target = TargetStub()

        let result = ApplicationActionExecutor.perform(.forceTerminate, on: target)

        XCTAssertTrue(result)
        XCTAssertEqual(target.calls, [.forceTerminate])
    }

    func testHideCallsOnlyHide() {
        let target = TargetStub()

        let result = ApplicationActionExecutor.perform(.hide, on: target)

        XCTAssertTrue(result)
        XCTAssertEqual(target.calls, [.hide])
    }
}

private final class TargetStub: ApplicationActionTarget {
    enum Call: Equatable {
        case hide
        case terminate
        case forceTerminate
    }

    var calls: [Call] = []
    let hideResult: Bool
    let terminateResult: Bool
    let forceTerminateResult: Bool

    init(
        hideResult: Bool = true,
        terminateResult: Bool = true,
        forceTerminateResult: Bool = true
    ) {
        self.hideResult = hideResult
        self.terminateResult = terminateResult
        self.forceTerminateResult = forceTerminateResult
    }

    func hide() -> Bool {
        calls.append(.hide)
        return hideResult
    }

    func terminate() -> Bool {
        calls.append(.terminate)
        return terminateResult
    }

    func forceTerminate() -> Bool {
        calls.append(.forceTerminate)
        return forceTerminateResult
    }
}
