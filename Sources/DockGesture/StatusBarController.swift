import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    var onToggleEnabled: ((Bool) -> Void)?
    var onToggleLoginItem: ((Bool) -> Void)?
    var onRequestPermissions: (() -> Void)?
    var onOpenAccessibility: (() -> Void)?
    var onOpenInputMonitoring: (() -> Void)?
    var onOpenLoginItems: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: "正在启动…", action: nil, keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: "启用 Dock 手势", action: #selector(toggleEnabled), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "登录时启动", action: #selector(toggleLoginItem), keyEquivalent: "")
    private let lastActionItem = NSMenuItem(title: "最近动作：无", action: nil, keyEquivalent: "")

    private var runtimeState: RuntimeState = .paused
    private var featureEnabled = true
    private var loginItemState: LoginItemState = .disabled
    private var lastAction = "无"

    override init() {
        super.init()

        menu.delegate = self
        stateItem.isEnabled = false
        lastActionItem.isEnabled = false
        enabledItem.target = self
        loginItem.target = self

        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(enabledItem)
        menu.addItem(loginItem)
        menu.addItem(lastActionItem)
        menu.addItem(.separator())
        menu.addItem(item("检查并引导权限", #selector(requestPermissions)))
        menu.addItem(item("打开辅助功能设置", #selector(openAccessibility)))
        menu.addItem(item("打开输入监控设置", #selector(openInputMonitoring)))
        menu.addItem(item("打开登录项设置", #selector(openLoginItems)))
        menu.addItem(.separator())
        menu.addItem(item("退出 DockGesture", #selector(quit)))

        statusItem.menu = menu
        refresh()
    }

    func update(
        runtimeState: RuntimeState,
        featureEnabled: Bool,
        loginItemState: LoginItemState,
        lastAction: String
    ) {
        self.runtimeState = runtimeState
        self.featureEnabled = featureEnabled
        self.loginItemState = loginItemState
        self.lastAction = lastAction
        refresh()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func refresh() {
        stateItem.title = "状态：\(runtimeState.title)"
        enabledItem.state = featureEnabled ? .on : .off
        loginItem.state = loginItemState.isEnabled ? .on : .off
        if loginItemState == .requiresApproval {
            loginItem.title = "登录时启动（等待系统批准）"
        } else {
            loginItem.title = "登录时启动"
        }
        lastActionItem.title = "最近动作：\(lastAction)"

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: runtimeState.symbolName,
                accessibilityDescription: "DockGesture：\(runtimeState.title)"
            )
            if button.image == nil {
                button.title = "DG"
            } else {
                button.title = ""
            }
        }
    }

    @objc private func toggleEnabled() {
        onToggleEnabled?(!featureEnabled)
    }

    @objc private func toggleLoginItem() {
        onToggleLoginItem?(!loginItemState.isEnabled)
    }

    @objc private func requestPermissions() {
        onRequestPermissions?()
    }

    @objc private func openAccessibility() {
        onOpenAccessibility?()
    }

    @objc private func openInputMonitoring() {
        onOpenInputMonitoring?()
    }

    @objc private func openLoginItems() {
        onOpenLoginItems?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
