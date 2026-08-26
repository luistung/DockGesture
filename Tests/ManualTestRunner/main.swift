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

expect(
    PermissionAvailability(accessibility: false, inputMonitoring: false)
        .missingPermissionsDescription == "缺少辅助功能和输入监控权限",
    "两项权限均缺少时应显示精确状态"
)
expect(
    PermissionAvailability(accessibility: false, inputMonitoring: true)
        .missingPermissionsDescription == "缺少辅助功能权限",
    "应精确显示缺少辅助功能权限"
)
expect(
    PermissionAvailability(accessibility: true, inputMonitoring: false)
        .missingPermissionsDescription == "缺少输入监控权限",
    "应精确显示缺少输入监控权限"
)

let missingInput = PermissionAvailability(accessibility: true, inputMonitoring: false)
let firstAutomaticGuide = PermissionGuidancePlan.make(
    availability: missingInput,
    trigger: .automatic,
    automaticGuideAlreadyShown: false
)
let laterAutomaticPoll = PermissionGuidancePlan.make(
    availability: missingInput,
    trigger: .automatic,
    automaticGuideAlreadyShown: true
)
let manualGuide = PermissionGuidancePlan.make(
    availability: missingInput,
    trigger: .manual,
    automaticGuideAlreadyShown: true
)
expect(firstAutomaticGuide.showInputMonitoringGuide, "首次缺少输入监控时应显示引导")
expect(firstAutomaticGuide.markAutomaticGuideAsShown, "首次引导应记录已显示")
expect(!laterAutomaticPoll.showInputMonitoringGuide, "轮询不得重复显示首次引导")
expect(manualGuide.showInputMonitoringGuide, "菜单手动检查应能再次显示引导")

let onlyAccessibilityMissing = PermissionGuidancePlan.make(
    availability: .init(accessibility: false, inputMonitoring: true),
    trigger: .manual,
    automaticGuideAlreadyShown: true
)
expect(onlyAccessibilityMissing.requestAccessibility, "缺少辅助功能时应请求授权")
expect(onlyAccessibilityMissing.openAccessibilitySettings, "手动检查应打开辅助功能设置")

let allPermissionsReady = PermissionGuidancePlan.make(
    availability: .init(accessibility: true, inputMonitoring: true),
    trigger: .manual,
    automaticGuideAlreadyShown: false
)
expect(allPermissionsReady.permissionsReady, "权限齐全时应报告就绪")
expect(!allPermissionsReady.showInputMonitoringGuide, "权限齐全时不得显示输入监控引导")

expect(
    DockApplicationIndicatorState.resolve(instances: []) == .none,
    "未运行应用不应显示状态标记"
)
expect(
    DockApplicationIndicatorState.resolve(instances: [
        .init(isActive: true, isHidden: false)
    ]) == .frontmost,
    "当前前台应用应显示前台标记"
)
expect(
    DockApplicationIndicatorState.resolve(instances: [
        .init(isActive: false, isHidden: true),
        .init(isActive: false, isHidden: true)
    ]) == .hidden,
    "全部实例隐藏时应显示隐藏标记"
)
expect(
    DockApplicationIndicatorState.resolve(instances: [
        .init(isActive: false, isHidden: true),
        .init(isActive: false, isHidden: false)
    ]) == .none,
    "任一后台实例可见时应保持原样"
)

let indicatorFrame = DockStateIndicatorLayout.frame(
    for: DockIndicatorRect(x: 10, y: 20, width: 50, height: 50)
)
expect(abs(indicatorFrame.width - 14) < 0.001, "50 点 Dock 图标应使用 14 点标记")
expect(indicatorFrame.midX == 59, "标记应锚定 Dock 图标右侧")
expect(indicatorFrame.midY == 69, "标记应锚定 Dock 图标上侧")

let convertedDockFrame = DockAccessibilityCoordinateConverter.appKitRect(
    from: DockIndicatorRect(x: 50, y: 900, width: 64, height: 64),
    mainDisplayHeight: 1080
)
expect(convertedDockFrame.y == 116, "辅助功能纵坐标应转换为 AppKit 坐标")

if failures == 0 {
    print("PASS: \(checks) checks")
} else {
    print("FAILED: \(failures) of \(checks) checks")
    exit(1)
}
