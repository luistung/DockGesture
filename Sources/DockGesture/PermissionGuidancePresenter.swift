import AppKit

enum InputMonitoringGuideResponse {
    case openSettings
    case later
}

@MainActor
final class PermissionGuidancePresenter {
    func showInputMonitoringGuide() -> InputMonitoringGuideResponse {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "还需要开启“输入监控”权限"
        alert.informativeText = """
        DockGesture 需要读取你在 Dock 上的鼠标点击和 Command、Option 修饰键。

        接下来请在“系统设置 → 隐私与安全性 → 输入监控”中开启 DockGesture。如果列表里没有 DockGesture，请点击“+”，从“应用程序”文件夹添加它。

        完成后回到 DockGesture；状态通常会自动更新。如果仍未生效，请退出并重新打开应用。系统随后如询问“辅助功能”权限，也请允许。
        """
        alert.addButton(withTitle: "打开输入监控设置")
        alert.addButton(withTitle: "稍后")

        return alert.runModal() == .alertFirstButtonReturn
            ? .openSettings
            : .later
    }
}
