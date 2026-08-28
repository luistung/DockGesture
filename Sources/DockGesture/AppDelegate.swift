import AppKit
import DockGestureCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum DefaultsKey {
        static let featureEnabled = "featureEnabled"
        static let didShowInputMonitoringGuide = "didShowInputMonitoringGuide"
    }

    private let permissionController = PermissionController()
    private let loginItemController = LoginItemController()
    private let actionController = AppActionController()
    private let focusedWindowMover = FocusedWindowMover()
    private let dockItemResolver = DockItemResolver()
    private lazy var eventTap = DockEventTap(resolver: dockItemResolver)
    private lazy var stateIndicatorController = DockStateIndicatorController(
        resolver: dockItemResolver
    )
    private let guidancePresenter = PermissionGuidancePresenter()

    private var statusBarController: StatusBarController?
    private var permissionTimer: Timer?
    private var runtimeState: RuntimeState = .paused
    private var lastAction = "无"

    private var featureEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.featureEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.featureEnabled) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.register(defaults: [DefaultsKey.featureEnabled: true])

        let statusBarController = StatusBarController()
        self.statusBarController = statusBarController
        wireControllers(statusBarController)

        permissionTimer = Timer.scheduledTimer(
            timeInterval: 2,
            target: self,
            selector: #selector(recheckPermissions),
            userInfo: nil,
            repeats: true
        )

        handlePermissionGuidance(trigger: .automatic)
        reevaluateRuntime()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        stateIndicatorController.stop()
        eventTap.stop()
    }

    private func wireControllers(_ statusBar: StatusBarController) {
        actionController.onResult = { [weak self] result in
            guard let self else { return }
            self.lastAction = result
            self.refreshMenu()
        }

        eventTap.onAction = { [weak self] action, resolved in
            self?.actionController.perform(action, on: resolved)
        }
        eventTap.onWindowMoveShortcut = { [weak self] in
            guard let self else { return }
            self.lastAction = self.focusedWindowMover.moveToNextDisplay()
            self.refreshMenu()
        }
        eventTap.onFailure = { [weak self] message in
            self?.runtimeState = .error(message)
            self?.refreshMenu()
        }

        statusBar.onToggleEnabled = { [weak self] enabled in
            guard let self else { return }
            self.featureEnabled = enabled
            self.reevaluateRuntime()
        }
        statusBar.onToggleLoginItem = { [weak self] enabled in
            self?.setLoginItemEnabled(enabled)
        }
        statusBar.onRequestPermissions = { [weak self] in
            self?.handlePermissionGuidance(trigger: .manual)
            self?.reevaluateRuntime()
        }
        statusBar.onOpenAccessibility = { [weak self] in
            self?.permissionController.openAccessibilitySettings()
        }
        statusBar.onOpenInputMonitoring = { [weak self] in
            self?.permissionController.openInputMonitoringSettings()
        }
        statusBar.onOpenLoginItems = { [weak self] in
            self?.loginItemController.openSettings()
        }
        statusBar.onQuit = {
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }

    @objc private func recheckPermissions() {
        reevaluateRuntime()
    }

    private func reevaluateRuntime() {
        guard featureEnabled else {
            stateIndicatorController.stop()
            eventTap.stop()
            runtimeState = .paused
            refreshMenu()
            return
        }

        let permissionStatus = permissionController.currentStatus
        guard permissionStatus.isReady else {
            stateIndicatorController.stop()
            eventTap.stop()
            runtimeState = .needsPermissions(permissionStatus)
            refreshMenu()
            return
        }

        if eventTap.start() {
            stateIndicatorController.start()
            runtimeState = .running
        } else {
            stateIndicatorController.stop()
            runtimeState = .error("无法启动输入事件监听")
        }
        refreshMenu()
    }

    private func handlePermissionGuidance(trigger: PermissionGuidanceTrigger) {
        let status = permissionController.currentStatus
        let plan = PermissionGuidancePlan.make(
            availability: status,
            trigger: trigger,
            automaticGuideAlreadyShown: UserDefaults.standard.bool(
                forKey: DefaultsKey.didShowInputMonitoringGuide
            )
        )

        if plan.markAutomaticGuideAsShown {
            UserDefaults.standard.set(
                true,
                forKey: DefaultsKey.didShowInputMonitoringGuide
            )
        }

        if plan.showInputMonitoringGuide {
            switch guidancePresenter.showInputMonitoringGuide() {
            case .openSettings:
                permissionController.requestInputMonitoringPermission()
                let opened = permissionController.openInputMonitoringSettings()
                lastAction = opened
                    ? "已打开输入监控设置"
                    : "请手动打开隐私与安全性 → 输入监控"
            case .later:
                lastAction = "输入监控权限尚未开启"
            }
        }

        if plan.requestAccessibility {
            if plan.showInputMonitoringGuide {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.permissionController.requestAccessibilityPermission()
                }
            } else {
                permissionController.requestAccessibilityPermission()
            }
        }

        if plan.openAccessibilitySettings {
            let opened = permissionController.openAccessibilitySettings()
            lastAction = opened
                ? "已打开辅助功能设置"
                : "请手动打开隐私与安全性 → 辅助功能"
        }

        if plan.permissionsReady {
            lastAction = "所需权限均已授予"
        }

        refreshMenu()
    }

    private func setLoginItemEnabled(_ enabled: Bool) {
        do {
            try loginItemController.setEnabled(enabled)
            lastAction = enabled ? "已请求登录时启动" : "已关闭登录时启动"
        } catch {
            lastAction = "登录项设置失败：\(error.localizedDescription)"
            if loginItemController.state == .requiresApproval {
                loginItemController.openSettings()
            }
        }
        refreshMenu()
    }

    private func refreshMenu() {
        statusBarController?.update(
            runtimeState: runtimeState,
            featureEnabled: featureEnabled,
            loginItemState: loginItemController.state,
            lastAction: lastAction
        )
    }
}
