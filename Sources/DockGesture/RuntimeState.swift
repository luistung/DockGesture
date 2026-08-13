import Foundation
import DockGestureCore

enum RuntimeState: Equatable {
    case running
    case paused
    case needsPermissions(PermissionAvailability)
    case error(String)

    var title: String {
        switch self {
        case .running:
            return "运行中"
        case .paused:
            return "已暂停"
        case .needsPermissions(let availability):
            return availability.missingPermissionsDescription ?? "需要权限"
        case .error(let message):
            return "错误：\(message)"
        }
    }

    var symbolName: String {
        switch self {
        case .running:
            return "hand.tap"
        case .paused:
            return "pause.circle"
        case .needsPermissions, .error:
            return "exclamationmark.triangle"
        }
    }
}
