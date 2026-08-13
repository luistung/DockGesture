import AppKit
import ApplicationServices
import CoreGraphics
import DockGestureCore

final class PermissionController {
    var currentStatus: PermissionAvailability {
        PermissionAvailability(
            accessibility: AXIsProcessTrusted(),
            inputMonitoring: CGPreflightListenEventAccess()
        )
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func requestInputMonitoringPermission() {
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        openSettings(anchor: "Privacy_Accessibility")
    }

    @discardableResult
    func openInputMonitoringSettings() -> Bool {
        openSettings(anchor: "Privacy_ListenEvent")
    }

    private func openSettings(anchor: String) -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
