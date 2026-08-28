public struct WindowMoveRect: Equatable, Sendable {
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

    fileprivate func intersectionArea(with other: WindowMoveRect) -> Double {
        let intersectionWidth = max(0, min(maxX, other.maxX) - max(x, other.x))
        let intersectionHeight = max(0, min(maxY, other.maxY) - max(y, other.y))
        return intersectionWidth * intersectionHeight
    }

    fileprivate func contains(x pointX: Double, y pointY: Double) -> Bool {
        pointX >= x && pointX <= maxX && pointY >= y && pointY <= maxY
    }

    fileprivate func approximatelyEquals(
        _ other: WindowMoveRect,
        tolerance: Double
    ) -> Bool {
        abs(x - other.x) <= tolerance
            && abs(y - other.y) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}

public struct WindowMoveDisplay: Equatable, Sendable {
    public let fullFrame: WindowMoveRect
    public let visibleFrame: WindowMoveRect

    public init(fullFrame: WindowMoveRect, visibleFrame: WindowMoveRect) {
        self.fullFrame = fullFrame
        self.visibleFrame = visibleFrame
    }
}

public struct DisplayCycleMovePlan: Equatable, Sendable {
    public let sourceDisplayIndex: Int
    public let targetDisplayIndex: Int
    public let targetWindowFrame: WindowMoveRect
    public let requiresResize: Bool

    public init(
        sourceDisplayIndex: Int,
        targetDisplayIndex: Int,
        targetWindowFrame: WindowMoveRect,
        requiresResize: Bool
    ) {
        self.sourceDisplayIndex = sourceDisplayIndex
        self.targetDisplayIndex = targetDisplayIndex
        self.targetWindowFrame = targetWindowFrame
        self.requiresResize = requiresResize
    }
}

public enum DisplayCyclePlanningResult: Equatable, Sendable {
    case insufficientDisplays
    case fullScreenWindow
    case move(DisplayCycleMovePlan)

    public var movePlan: DisplayCycleMovePlan? {
        guard case .move(let plan) = self else { return nil }
        return plan
    }
}

public enum DisplayCyclePlanner {
    public static func plan(
        window: WindowMoveRect,
        displays: [WindowMoveDisplay],
        fullScreenTolerance: Double = 2
    ) -> DisplayCyclePlanningResult {
        guard displays.count >= 2 else {
            return .insufficientDisplays
        }

        if displays.contains(where: {
            window.approximatelyEquals($0.fullFrame, tolerance: fullScreenTolerance)
        }) {
            return .fullScreenWindow
        }

        let sourceIndex = sourceDisplayIndex(for: window, displays: displays)
        let targetIndex = (sourceIndex + 1) % displays.count
        let source = displays[sourceIndex].visibleFrame
        let target = displays[targetIndex].visibleFrame
        let targetWidth = min(window.width, target.width)
        let targetHeight = min(window.height, target.height)

        let targetX = mappedOrigin(
            windowOrigin: window.x,
            windowLength: window.width,
            sourceOrigin: source.x,
            sourceLength: source.width,
            targetOrigin: target.x,
            targetLength: target.width,
            targetWindowLength: targetWidth
        )
        let targetY = mappedOrigin(
            windowOrigin: window.y,
            windowLength: window.height,
            sourceOrigin: source.y,
            sourceLength: source.height,
            targetOrigin: target.y,
            targetLength: target.height,
            targetWindowLength: targetHeight
        )
        let frame = WindowMoveRect(
            x: targetX,
            y: targetY,
            width: targetWidth,
            height: targetHeight
        )
        let requiresResize = abs(targetWidth - window.width) > 0.001
            || abs(targetHeight - window.height) > 0.001

        return .move(DisplayCycleMovePlan(
            sourceDisplayIndex: sourceIndex,
            targetDisplayIndex: targetIndex,
            targetWindowFrame: frame,
            requiresResize: requiresResize
        ))
    }

    private static func sourceDisplayIndex(
        for window: WindowMoveRect,
        displays: [WindowMoveDisplay]
    ) -> Int {
        var bestIndex = 0
        var bestIntersection = -1.0
        var bestContainsCenter = false

        for (index, display) in displays.enumerated() {
            let frame = display.visibleFrame
            let intersection = window.intersectionArea(with: frame)
            let containsCenter = frame.contains(x: window.midX, y: window.midY)
            if intersection > bestIntersection
                || (intersection == bestIntersection && containsCenter && !bestContainsCenter) {
                bestIndex = index
                bestIntersection = intersection
                bestContainsCenter = containsCenter
            }
        }
        return bestIndex
    }

    private static func mappedOrigin(
        windowOrigin: Double,
        windowLength: Double,
        sourceOrigin: Double,
        sourceLength: Double,
        targetOrigin: Double,
        targetLength: Double,
        targetWindowLength: Double
    ) -> Double {
        let sourceTravel = max(0, sourceLength - windowLength)
        let progress: Double
        if sourceTravel <= 0.001 {
            progress = 0.5
        } else {
            progress = clamp((windowOrigin - sourceOrigin) / sourceTravel, minimum: 0, maximum: 1)
        }

        let targetTravel = max(0, targetLength - targetWindowLength)
        let proposed = targetOrigin + progress * targetTravel
        return clamp(
            proposed,
            minimum: targetOrigin,
            maximum: targetOrigin + targetTravel
        )
    }

    private static func clamp(_ value: Double, minimum: Double, maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}
