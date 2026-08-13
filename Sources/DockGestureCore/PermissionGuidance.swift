public struct PermissionAvailability: Equatable, Sendable {
    public let accessibility: Bool
    public let inputMonitoring: Bool

    public init(accessibility: Bool, inputMonitoring: Bool) {
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
    }

    public var isReady: Bool {
        accessibility && inputMonitoring
    }

    public var missingPermissionsDescription: String? {
        switch (accessibility, inputMonitoring) {
        case (false, false):
            return "缺少辅助功能和输入监控权限"
        case (false, true):
            return "缺少辅助功能权限"
        case (true, false):
            return "缺少输入监控权限"
        case (true, true):
            return nil
        }
    }
}

public enum PermissionGuidanceTrigger: Equatable, Sendable {
    case automatic
    case manual
}

public struct PermissionGuidancePlan: Equatable, Sendable {
    public let showInputMonitoringGuide: Bool
    public let markAutomaticGuideAsShown: Bool
    public let requestAccessibility: Bool
    public let openAccessibilitySettings: Bool
    public let permissionsReady: Bool

    public static func make(
        availability: PermissionAvailability,
        trigger: PermissionGuidanceTrigger,
        automaticGuideAlreadyShown: Bool
    ) -> PermissionGuidancePlan {
        let shouldShowInputGuide: Bool
        let shouldMarkAutomaticGuide: Bool

        switch trigger {
        case .automatic:
            shouldShowInputGuide = !availability.inputMonitoring && !automaticGuideAlreadyShown
            shouldMarkAutomaticGuide = shouldShowInputGuide
        case .manual:
            shouldShowInputGuide = !availability.inputMonitoring
            shouldMarkAutomaticGuide = false
        }

        return PermissionGuidancePlan(
            showInputMonitoringGuide: shouldShowInputGuide,
            markAutomaticGuideAsShown: shouldMarkAutomaticGuide,
            requestAccessibility: !availability.accessibility,
            openAccessibilitySettings: trigger == .manual
                && !availability.accessibility
                && availability.inputMonitoring,
            permissionsReady: availability.isReady
        )
    }
}
