public struct DockRunningApplicationState: Equatable, Sendable {
    public let isActive: Bool
    public let isHidden: Bool

    public init(isActive: Bool, isHidden: Bool) {
        self.isActive = isActive
        self.isHidden = isHidden
    }
}

public enum DockApplicationIndicatorState: Equatable, Sendable {
    case none
    case frontmost
    case hidden

    public static func resolve(
        instances: [DockRunningApplicationState]
    ) -> DockApplicationIndicatorState {
        guard !instances.isEmpty else {
            return .none
        }
        if instances.contains(where: \.isActive) {
            return .frontmost
        }
        if instances.contains(where: { !$0.isHidden }) {
            return .none
        }
        return .hidden
    }
}

public struct DockIndicatorRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
}

public enum DockStateIndicatorLayout {
    public static func diameter(for iconFrame: DockIndicatorRect) -> Double {
        let iconSize = min(iconFrame.width, iconFrame.height)
        return min(18, max(10, iconSize * 0.28))
    }

    public static func frame(for iconFrame: DockIndicatorRect) -> DockIndicatorRect {
        let diameter = diameter(for: iconFrame)
        let centerX = iconFrame.maxX - 1
        let centerY = iconFrame.maxY - 1
        return DockIndicatorRect(
            x: centerX - diameter / 2,
            y: centerY - diameter / 2,
            width: diameter,
            height: diameter
        )
    }
}

public enum DockAccessibilityCoordinateConverter {
    public static func appKitRect(
        from accessibilityRect: DockIndicatorRect,
        mainDisplayHeight: Double
    ) -> DockIndicatorRect {
        DockIndicatorRect(
            x: accessibilityRect.x,
            y: mainDisplayHeight - accessibilityRect.maxY,
            width: accessibilityRect.width,
            height: accessibilityRect.height
        )
    }
}
