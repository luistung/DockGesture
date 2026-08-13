import AppKit
import ApplicationServices
import CoreGraphics

struct PermissionStatus: Equatable {
    let accessibility: Bool
    let inputMonitoring: Bool

    var isReady: Bool {
        accessibility && inputMonitoring
    }
}

final class PermissionController {
    var currentStatus: PermissionStatus {
        PermissionStatus(
            accessibility: AXIsProcessTrusted(),
            inputMonitoring: CGPreflightListenEventAccess()
        )
    }

    func requestPermissions() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
    }

    func openAccessibilitySettings() {
        openSettings(anchor: "Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSettings(anchor: "Privacy_ListenEvent")
    }

    private func openSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
