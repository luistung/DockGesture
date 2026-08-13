import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum DefaultsKey {
        static let featureEnabled = "featureEnabled"
        static let didRequestPermissions = "didRequestPermissions"
    }

    private let permissionController = PermissionController()
    private let loginItemController = LoginItemController()
    private let actionController = AppActionController()
    private let eventTap = DockEventTap(resolver: DockItemResolver())

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

        if !UserDefaults.standard.bool(forKey: DefaultsKey.didRequestPermissions) {
            UserDefaults.standard.set(true, forKey: DefaultsKey.didRequestPermissions)
            permissionController.requestPermissions()
        }

        reevaluateRuntime()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
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
            self?.permissionController.requestPermissions()
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
            eventTap.stop()
            runtimeState = .paused
            refreshMenu()
            return
        }

        guard permissionController.currentStatus.isReady else {
            eventTap.stop()
            runtimeState = .needsPermissions
            refreshMenu()
            return
        }

        runtimeState = eventTap.start()
            ? .running
            : .error("无法启动鼠标事件监听")
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
