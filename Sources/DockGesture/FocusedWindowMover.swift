import AppKit
import CoreGraphics
import DockGestureCore

@MainActor
final class FocusedWindowMover {
    private struct ScreenSnapshot {
        let name: String
        let display: WindowMoveDisplay
    }

    private let accessor: FocusedWindowAccessor

    init(accessor: FocusedWindowAccessor = FocusedWindowAccessor()) {
        self.accessor = accessor
    }

    func moveToNextDisplay() -> String {
        let screens = screenSnapshots()
        guard screens.count >= 2 else {
            return "只有一台显示器，无需移动"
        }

        let window: FocusedWindowSnapshot
        switch accessor.readFocusedWindow() {
        case .success(let snapshot):
            window = snapshot
        case .failure(let failure):
            return message(for: failure)
        }

        let windowFrame = WindowMoveRect(
            x: Double(window.frame.minX),
            y: Double(window.frame.minY),
            width: Double(window.frame.width),
            height: Double(window.frame.height)
        )
        let planningResult = DisplayCyclePlanner.plan(
            window: windowFrame,
            displays: screens.map(\.display)
        )

        switch planningResult {
        case .insufficientDisplays:
            return "只有一台显示器，无需移动"
        case .fullScreenWindow:
            return unsupportedWindowMessage
        case .move(let plan):
            guard window.positionIsSettable else {
                return unsupportedWindowMessage
            }
            if plan.requiresResize && !window.sizeIsSettable {
                return "目标屏幕空间不足，且此窗口不允许调整尺寸"
            }
            return apply(plan: plan, to: window, screens: screens)
        }
    }

    private var unsupportedWindowMessage: String {
        "当前窗口不支持跨屏移动（可能处于全屏或平铺状态）"
    }

    private func apply(
        plan: DisplayCycleMovePlan,
        to window: FocusedWindowSnapshot,
        screens: [ScreenSnapshot]
    ) -> String {
        let target = plan.targetWindowFrame
        if plan.requiresResize {
            let sizeError = accessor.setSize(
                CGSize(width: target.width, height: target.height),
                of: window.element
            )
            guard sizeError == .success else {
                return "设置窗口尺寸失败"
            }
        }

        let positionError = accessor.setPosition(
            CGPoint(x: target.x, y: target.y),
            of: window.element
        )
        guard positionError == .success else {
            if plan.requiresResize {
                _ = accessor.setSize(window.frame.size, of: window.element)
            }
            return "设置窗口位置失败"
        }

        let windowName = normalizedName(window.title, fallback: "当前窗口")
        let screenName = normalizedName(
            screens[plan.targetDisplayIndex].name,
            fallback: "下一台显示器"
        )
        return "已将“\(windowName)”移动到“\(screenName)”"
    }

    private func screenSnapshots() -> [ScreenSnapshot] {
        let mainDisplayHeight = Double(CGDisplayBounds(CGMainDisplayID()).height)
        return NSScreen.screens.map { screen in
            ScreenSnapshot(
                name: screen.localizedName,
                display: WindowMoveDisplay(
                    fullFrame: accessibilityRect(
                        from: screen.frame,
                        mainDisplayHeight: mainDisplayHeight
                    ),
                    visibleFrame: accessibilityRect(
                        from: screen.visibleFrame,
                        mainDisplayHeight: mainDisplayHeight
                    )
                )
            )
        }
    }

    private func accessibilityRect(
        from appKitRect: CGRect,
        mainDisplayHeight: Double
    ) -> WindowMoveRect {
        WindowMoveRect(
            x: Double(appKitRect.minX),
            y: mainDisplayHeight - Double(appKitRect.maxY),
            width: Double(appKitRect.width),
            height: Double(appKitRect.height)
        )
    }

    private func message(for failure: FocusedWindowAccessFailure) -> String {
        switch failure {
        case .noFrontmostApplication, .noFocusedWindow:
            return "当前应用没有可移动的前台窗口"
        case .invalidPosition:
            return "读取窗口位置失败"
        case .invalidSize:
            return "读取窗口尺寸失败"
        }
    }

    private func normalizedName(_ value: String?, fallback: String) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return value
    }
}
