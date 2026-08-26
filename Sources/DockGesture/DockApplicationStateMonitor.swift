import AppKit

@MainActor
final class DockApplicationStateMonitor: NSObject {
    var onChange: (() -> Void)?

    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ] {
            workspaceCenter.addObserver(
                self,
                selector: #selector(environmentDidChange),
                name: name,
                object: nil
            )
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(environmentDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func environmentDidChange() {
        onChange?()
    }
}
