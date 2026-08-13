public enum MouseButton: Hashable, Sendable {
    case left
    case right
}

public struct GestureModifiers: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = GestureModifiers(rawValue: 1 << 0)
    public static let option = GestureModifiers(rawValue: 1 << 1)
    public static let control = GestureModifiers(rawValue: 1 << 2)
    public static let shift = GestureModifiers(rawValue: 1 << 3)

    public static let meaningful: GestureModifiers = [.command, .option, .control, .shift]
}

public enum ApplicationAction: Equatable, Sendable {
    case hide
    case terminate
    case forceTerminate
}

public enum GestureDecision: Equatable, Sendable {
    case passThrough
    case perform(ApplicationAction)
}

public struct GestureInput: Sendable {
    public let button: MouseButton
    public let modifiers: GestureModifiers
    public let isDockApplication: Bool
    public let isTargetFrontmost: Bool

    public init(
        button: MouseButton,
        modifiers: GestureModifiers,
        isDockApplication: Bool,
        isTargetFrontmost: Bool
    ) {
        self.button = button
        self.modifiers = modifiers
        self.isDockApplication = isDockApplication
        self.isTargetFrontmost = isTargetFrontmost
    }
}
