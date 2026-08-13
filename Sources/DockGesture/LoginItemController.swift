import AppKit
import ServiceManagement

enum LoginItemState {
    case enabled
    case disabled
    case requiresApproval
    case notFound

    var isEnabled: Bool {
        self == .enabled
    }
}

final class LoginItemController {
    var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        case .notRegistered:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
