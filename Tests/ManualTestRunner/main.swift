import DockGestureCore
import Darwin

private var failures = 0
private var checks = 0

@MainActor
private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    checks += 1
    guard !condition() else { return }
    failures += 1
    print("FAIL: \(message) [\(file):\(line)]")
}

private func decision(
    button: MouseButton,
    modifiers: GestureModifiers = [],
    isDockApplication: Bool = true,
    isFrontmost: Bool = false
) -> GestureDecision {
    GestureClassifier.classify(.init(
        button: button,
        modifiers: modifiers,
        isDockApplication: isDockApplication,
        isTargetFrontmost: isFrontmost
    ))
}

expect(
    decision(button: .left, isFrontmost: true) == .perform(.hide),
    "普通左键应隐藏前台 Dock 应用"
)
expect(
    decision(button: .left, isFrontmost: false) == .passThrough,
    "普通左键应放行后台 Dock 应用"
)

for modifier: GestureModifiers in [.command, .option, .control, .shift] {
    expect(
        decision(button: .left, modifiers: modifier, isFrontmost: true) == .passThrough,
        "带有效修饰键的左键应放行"
    )
}

expect(
    decision(button: .right, modifiers: .command) == .perform(.terminate),
    "Command + 右键应正常退出"
)
expect(
    decision(button: .right, modifiers: [.command, .option]) == .perform(.forceTerminate),
    "Command + Option + 右键应强制退出"
)

for modifiers: GestureModifiers in [
    [.command, .control],
    [.command, .shift],
    [.command, .option, .control],
    [.command, .option, .shift]
] {
    expect(
        decision(button: .right, modifiers: modifiers) == .passThrough,
        "带 Control 或 Shift 的右键应放行"
    )
}

expect(
    decision(button: .left, isDockApplication: false, isFrontmost: true) == .passThrough,
    "非 Dock 应用目标的左键应放行"
)
expect(
    decision(button: .right, modifiers: .command, isDockApplication: false) == .passThrough,
    "非 Dock 应用目标的右键应放行"
)

var suppressor = MouseUpSuppressor()
suppressor.beginSuppressing(.right)
expect(!suppressor.consumeMouseUp(for: .left), "不应吞掉不同按钮的 mouse-up")
expect(suppressor.consumeMouseUp(for: .right), "应吞掉匹配按钮的 mouse-up")
expect(!suppressor.consumeMouseUp(for: .right), "匹配 mouse-up 只能吞掉一次")
suppressor.beginSuppressing(.left)
suppressor.reset()
expect(!suppressor.consumeMouseUp(for: .left), "reset 应清空 mouse-up 抑制状态")

private final class TargetStub: ApplicationActionTarget {
    enum Call: Equatable {
        case hide
        case terminate
        case forceTerminate
    }

    var calls: [Call] = []
    var terminateResult = true

    func hide() -> Bool {
        calls.append(.hide)
        return true
    }

    func terminate() -> Bool {
        calls.append(.terminate)
        return terminateResult
    }

    func forceTerminate() -> Bool {
        calls.append(.forceTerminate)
        return true
    }
}

private let terminateTarget = TargetStub()
terminateTarget.terminateResult = false
expect(
    !ApplicationActionExecutor.perform(.terminate, on: terminateTarget),
    "正常退出失败应返回失败"
)
expect(
    terminateTarget.calls == [.terminate],
    "正常退出失败绝不能升级为强制退出"
)

private let forceTarget = TargetStub()
expect(
    ApplicationActionExecutor.perform(.forceTerminate, on: forceTarget),
    "强制退出请求应返回目标结果"
)
expect(forceTarget.calls == [.forceTerminate], "强制退出只能调用 forceTerminate")

if failures == 0 {
    print("PASS: \(checks) checks")
} else {
    print("FAILED: \(failures) of \(checks) checks")
    exit(1)
}
